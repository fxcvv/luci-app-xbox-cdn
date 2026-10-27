#!/bin/sh
# Xbox CDN 优化 - OpenWrt 测速脚本
# 测试各组 CDN 节点，把最快的 IP 写入 DNS 服务
# 许可证: GPL-3.0

set -e

# ============= 配置 =============
MODE="dnsmasq"
DNSMASQ_CONF="${DNSMASQ_CONF:-/tmp/dnsmasq.d/xbox-cdn.conf}"
SMARTDNS_CONF="${SMARTDNS_CONF:-/etc/smartdns/custom.conf}"
LOG_FILE="${LOG_FILE:-/tmp/xbox-speedtest.log}"
STATUS_FILE="${STATUS_FILE:-/tmp/xbox-cdn-status.json}"
CDN_IP_FILE="${CDN_IP_FILE:-/etc/xbox-cdn-ips.conf}"
LOCK_FILE="${LOCK_FILE:-/var/lock/xbox-speedtest.lock}"

TEST_SIZE="${TEST_SIZE:-10M}"
CONCURRENT="${CONCURRENT:-3}"
TIMEOUT="${TIMEOUT:-15}"
TOP_N="${TOP_N:-2}"

TMP_DIR="/tmp/xbox-speedtest-$$"

# ============= 参数解析 =============
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --mode)
                MODE="$2"
                shift 2
                ;;
            --mode=*)
                MODE="${1#--mode=}"
                shift
                ;;
            --apply)
                shift
                ;;
            -h|--help)
                echo "用法: $0 [--mode smartdns|dnsmasq] [--apply]"
                echo "  --mode   写入目标: smartdns 或 dnsmasq（默认 dnsmasq）"
                echo "  --apply  测速并应用结果"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    case "$MODE" in
        smartdns|dnsmasq) ;;
        *)
            echo "错误: 未知模式 '$MODE'，请使用 smartdns 或 dnsmasq"
            exit 1
            ;;
    esac
}

# ============= 日志 =============
log() {
    local msg="[$(date +%H:%M:%S)] $*"
    echo "$msg" >> "$LOG_FILE"
    logger -t xbox-speedtest "$*"
}

# ============= 状态输出 =============
write_status() {
    local state="$1"
    local result_ip="$2"
    local group_name="$3"
    local speed_val="$4"

    if [ "$state" = "done" ]; then
        cat > "$STATUS_FILE" << STEOF
{
  "state": "done",
  "last_run": "$(date '+%Y-%m-%d %H:%M:%S')",
  "mode": "$MODE",
  "best_ips": "$result_ip",
  "group": "$group_name",
  "speed": "$speed_val"
}
STEOF
    elif [ "$state" = "running" ]; then
        cat > "$STATUS_FILE" << STEOF
{
  "state": "running",
  "last_run": "",
  "mode": "$MODE"
}
STEOF
    fi
}

# ============= 依赖检查 =============
check_dependencies() {
    local missing=""
    for cmd in curl flock awk grep sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        log "错误: 缺少依赖:$missing"
        exit 1
    fi
}

# ============= 运行锁 =============
acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -xn 200; then
        log "已有实例运行，退出"
        exit 0
    fi
}

# ============= 读取 CDN IP 与域名 =============
load_cdn_ips() {
    if [ ! -f "$CDN_IP_FILE" ]; then
        log "错误: CDN IP 文件不存在: $CDN_IP_FILE"
        exit 1
    fi

    XBOX_CN_IPS=$(awk '$1=="XBOX_CN" {print $2}' "$CDN_IP_FILE" | tr '\n' ' ')
    XBOX_CN_DL_IPS=$(awk '$1=="XBOX_CN_DL" {print $2}' "$CDN_IP_FILE" | tr '\n' ' ')
    AKAMAI_IPS=$(awk '$1=="AKAMAI_CN" {print $2}' "$CDN_IP_FILE" | tr '\n' ' ')
    MS_DELIVERY_IPS=$(awk '$1=="MS_DELIVERY" {print $2}' "$CDN_IP_FILE" | tr '\n' ' ')

    log "加载 CDN IP:"
    log "  Xbox CN: $(echo "$XBOX_CN_IPS" | wc -w) 个"
    log "  Xbox CN DL: $(echo "$XBOX_CN_DL_IPS" | wc -w) 个"
    log "  Akamai: $(echo "$AKAMAI_IPS" | wc -w) 个"
    log "  MS Delivery: $(echo "$MS_DELIVERY_IPS" | wc -w) 个"
}

# ============= 测速 =============
test_speed() {
    local ip="$1" url="$2" label="$3"
    local result total_size total_time speed

    result=$(curl -sk --http2-prior-knowledge \
        --resolve "*:80:$ip" --resolve "*:443:$ip" \
        -w "%{size_download} %{time_total}\n" \
        -o /dev/null \
        -m "$TIMEOUT" \
        $(for i in $(seq 1 "$CONCURRENT"); do echo "-Z $url"; done) \
        "http://$ip$url" 2>/dev/null || echo "0 0")

    total_size=$(echo "$result" | awk '{s+=$1} END {print s}')
    total_time=$(echo "$result" | awk 'BEGIN{max=0} {if($2>max)max=$2} END {print max}')

    if [ "$total_size" -gt 0 ] && [ "$(echo "$total_time > 0" | bc 2>/dev/null || echo 0)" = "1" ]; then
        speed=$(awk "BEGIN {printf \"%.1f\", $total_size / $total_time / 1048576}")
        echo "$ip $speed"
        log "    $ip  $speed MB/s"
    else
        echo "$ip 0"
        log "    $ip  超时/失败"
    fi
}

test_group() {
    local group_name="$1" ip_list="$2" test_url="$3"
    local results_file="$TMP_DIR/${group_name}.txt"

    log "── $group_name ──"

    > "$results_file"
    for ip in $ip_list; do
        test_speed "$ip" "$test_url" "$group_name" >> "$results_file" &
    done
    wait

    sort -k2 -rn "$results_file" | head -n "$TOP_N"
}

# ============= 生成规则（公共逻辑）=============
# 按 cdn-ips.conf 里的 DOMAIN 条目，为每组写入 address 规则
write_address_rules() {
    local output="$1"
    local fmt="$2"  # "dnsmasq" or "smartdns"
    local group best_ip domains domain

    # 取出所有配置了 DOMAIN 的分组
    awk '$1=="DOMAIN" {print $2}' "$CDN_IP_FILE" | sort -u | while read -r group; do
        # 从环境变量 BEST_<分组> 读取该组最优 IP
        eval "best_ip=\$BEST_$(echo "$group" | tr '[:lower:]-' '[:upper:]_')"
        [ -z "$best_ip" ] && continue

        # 只用第一个（最快的）IP
        best_ip=$(echo "$best_ip" | awk '{print $1}')
        [ -z "$best_ip" ] && continue

        # 该组每个域名写一条规则
        awk -v grp="$group" '$1=="DOMAIN" && $2==grp {print $3}' "$CDN_IP_FILE" | \
        while read -r domain; do
            case "$fmt" in
                dnsmasq)  echo "address=/$domain/$best_ip" >> "$output" ;;
                smartdns) echo "address /$domain/$best_ip" >> "$output" ;;
            esac
        done
    done
}

# ============= 生成 dnsmasq 配置 =============
generate_dnsmasq_conf() {
    local output="$TMP_DIR/dnsmasq.conf"

    cat > "$output" << EOF
# Xbox CDN 优化
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 模式: dnsmasq
# 由 xbox-speedtest 自动生成，请勿手动编辑

EOF
    write_address_rules "$output" "dnsmasq"
    echo "$output"
}

# ============= 生成 SmartDNS 配置 =============
generate_smartdns_conf() {
    local output="$TMP_DIR/smartdns.conf"

    cat > "$output" << EOF
# BEGIN xbox-cdn
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 本块由 xbox-speedtest 自动生成，请勿手动编辑
EOF
    write_address_rules "$output" "smartdns"
    echo "# END xbox-cdn" >> "$output"
    echo "$output"
}

# ============= 应用配置 =============
apply_config() {
    local new_conf="$1"
    local target_conf backup

    case "$MODE" in
        smartdns)
            target_conf="$SMARTDNS_CONF"
            backup="${SMARTDNS_CONF}.bak"
            ;;
        dnsmasq)
            target_conf="$DNSMASQ_CONF"
            backup="${DNSMASQ_CONF}.bak"
            ;;
    esac

    if [ "$MODE" = "smartdns" ]; then
        # custom.conf 是共享文件，只替换 xbox-cdn 块，保留其余内容
        [ -f "$target_conf" ] && cp "$target_conf" "$backup"

        # 删除旧的 xbox-cdn 块
        local tmp_merge="$TMP_DIR/custom_merged.conf"
        if [ -f "$target_conf" ]; then
            sed '/^# BEGIN xbox-cdn$/,/^# END xbox-cdn$/d' "$target_conf" > "$tmp_merge"
        else
            : > "$tmp_merge"
        fi

        # 追加新块
        cat "$new_conf" >> "$tmp_merge"

        # 内容没变就不重启
        if [ -f "$target_conf" ] && cmp -s "$tmp_merge" "$target_conf"; then
            log "配置无变化，跳过重载"
            return 0
        fi

        cp "$tmp_merge" "$target_conf"
        log "已更新 custom.conf 中的 xbox-cdn 块: $target_conf"

        if /etc/init.d/smartdns restart; then
            log "SmartDNS 重载成功"
            return 0
        else
            log "错误: SmartDNS 重载失败"
            [ -f "$backup" ] && cp "$backup" "$target_conf" && /etc/init.d/smartdns restart
            return 1
        fi
    else
        # dnsmasq 模式：独立配置文件
        if [ -f "$target_conf" ]; then
            if cmp -s "$new_conf" "$target_conf"; then
                log "配置无变化，跳过重载"
                return 0
            fi
            log "配置已变化"
            cp "$target_conf" "$backup"
            log "已备份旧配置: $backup"
        fi

        mkdir -p "$(dirname "$target_conf")"
        cp "$new_conf" "$target_conf"
        log "已写入新配置: $target_conf"

        if /etc/init.d/dnsmasq restart; then
            log "dnsmasq 重载成功"
            return 0
        else
            log "错误: dnsmasq 重载失败"
            [ -f "$backup" ] && cp "$backup" "$target_conf" && /etc/init.d/dnsmasq restart
            return 1
        fi
    fi
}

# ============= 清理 =============
cleanup() {
    rm -rf "$TMP_DIR"
}

# ============= 主流程 =============
main() {
    trap cleanup EXIT

    parse_args "$@"

    log "========================================="
    log "Xbox CDN Speedtest 开始 (模式: $MODE)"
    log "========================================="

    write_status "running" "" "" ""

    check_dependencies
    acquire_lock
    load_cdn_ips

    mkdir -p "$TMP_DIR"

    XBOX_CN_BEST=$(test_group "XboxCN" "$XBOX_CN_IPS" "/filestable/" | awk '{print $1}')
    XBOX_CN_DL_BEST=$(test_group "XboxCN-DL" "$XBOX_CN_DL_IPS" "/filestable/" | awk '{print $1}')
    MS_DELIVERY_BEST=$(test_group "MS-Delivery" "$MS_DELIVERY_IPS" "/" | awk '{print $1}')

    log ""
    log "最优 IP 选择完成"
    log "  XboxCN: $XBOX_CN_BEST"
    log "  XboxCN-DL: $XBOX_CN_DL_BEST"
    log "  MS-Delivery: $MS_DELIVERY_BEST"

    # 导出各组最优 IP，供 write_address_rules 读取
    export BEST_XBOX_CN="$XBOX_CN_BEST"
    export BEST_XBOX_CN_DL="$XBOX_CN_DL_BEST"
    export BEST_AKAMAI_CN="$AKAMAI_BEST"
    export BEST_MS_DELIVERY="$MS_DELIVERY_BEST"

    case "$MODE" in
        smartdns) NEW_CONF=$(generate_smartdns_conf) ;;
        dnsmasq)  NEW_CONF=$(generate_dnsmasq_conf)  ;;
    esac

    # 把多行 IP 压成一行，写入 JSON 状态
    BEST_IPS_FLAT=$(printf '%s %s %s' "$XBOX_CN_BEST" "$XBOX_CN_DL_BEST" "$MS_DELIVERY_BEST" | tr '\n' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')

    if apply_config "$NEW_CONF"; then
        write_status "done" "$BEST_IPS_FLAT" "all" ""
        log "========================================="
        log "优化完成 (模式: $MODE)"
        log "========================================="
    else
        write_status "done" "" "" ""
        log "========================================="
        log "优化失败 (模式: $MODE)"
        log "========================================="
        exit 1
    fi
}

[ -f /etc/xbox-speedtest.conf ] && . /etc/xbox-speedtest.conf

main "$@"
