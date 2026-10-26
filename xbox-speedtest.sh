#!/bin/sh
# Xbox CDN Speedtest for OpenWrt
# Automatically test and select fastest CDN nodes
# License: GPL-3.0

set -e

# ============= Configuration =============
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

# ============= Argument Parsing =============
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
                echo "Usage: $0 [--mode smartdns|dnsmasq] [--apply]"
                echo "  --mode   Output target: smartdns or dnsmasq (default: dnsmasq)"
                echo "  --apply  Run speed test and apply results"
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

# ============= Logging =============
log() {
    local msg="[$(date +%H:%M:%S)] $*"
    echo "$msg" >> "$LOG_FILE"
    logger -t xbox-speedtest "$*"
}

# ============= Status Output =============
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

# ============= Dependency Check =============
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

# ============= Lock Management =============
acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -xn 200; then
        log "已有实例运行，退出"
        exit 0
    fi
}

# ============= Load CDN IPs =============
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

# ============= Speed Test =============
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

# ============= Generate dnsmasq Configuration =============
generate_dnsmasq_conf() {
    local xbox_cn_best="$1"
    local xbox_cn_dl_best="$2"
    local ms_delivery_best="$3"
    local output="$TMP_DIR/dnsmasq.conf"

    cat > "$output" << EOF
# Xbox CDN Optimization
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Mode: dnsmasq
# DO NOT EDIT MANUALLY - This file is auto-generated

EOF

    for ip in $xbox_cn_best; do
        cat >> "$output" << EOF
address=/assets1.xboxlive.cn/$ip
address=/assets2.xboxlive.cn/$ip
address=/d1.xboxlive.cn/$ip
address=/d2.xboxlive.cn/$ip
EOF
        break
    done

    for ip in $xbox_cn_dl_best; do
        cat >> "$output" << EOF
address=/dlassets.xboxlive.cn/$ip
address=/dlassets2.xboxlive.cn/$ip
EOF
        break
    done

    for ip in $ms_delivery_best; do
        cat >> "$output" << EOF
address=/dl.delivery.mp.microsoft.com/$ip
address=/tlu.dl.delivery.mp.microsoft.com/$ip
EOF
        break
    done

    echo "$output"
}

# ============= Generate SmartDNS Configuration =============
generate_smartdns_conf() {
    local xbox_cn_best="$1"
    local xbox_cn_dl_best="$2"
    local ms_delivery_best="$3"
    local output="$TMP_DIR/smartdns.conf"

    # Generate only the xbox-cdn block
    cat > "$output" << EOF
# BEGIN xbox-cdn
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# DO NOT EDIT THIS BLOCK - auto-generated by xbox-speedtest
EOF

    for ip in $xbox_cn_best; do
        cat >> "$output" << EOF
address /assets1.xboxlive.cn/$ip
address /assets2.xboxlive.cn/$ip
address /d1.xboxlive.cn/$ip
address /d2.xboxlive.cn/$ip
EOF
        break
    done

    for ip in $xbox_cn_dl_best; do
        cat >> "$output" << EOF
address /dlassets.xboxlive.cn/$ip
address /dlassets2.xboxlive.cn/$ip
EOF
        break
    done

    for ip in $ms_delivery_best; do
        cat >> "$output" << EOF
address /dl.delivery.mp.microsoft.com/$ip
address /tlu.dl.delivery.mp.microsoft.com/$ip
EOF
        break
    done

    echo "# END xbox-cdn" >> "$output"

    echo "$output"
}

# ============= Apply Configuration =============
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
        # custom.conf is shared - merge our block, preserve other content
        [ -f "$target_conf" ] && cp "$target_conf" "$backup"

        # Remove old xbox-cdn block, keep everything else
        local tmp_merge="$TMP_DIR/custom_merged.conf"
        if [ -f "$target_conf" ]; then
            sed '/^# BEGIN xbox-cdn$/,/^# END xbox-cdn$/d' "$target_conf" > "$tmp_merge"
        else
            : > "$tmp_merge"
        fi

        # Append our new block
        cat "$new_conf" >> "$tmp_merge"

        # Check if content actually changed
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
        # dnsmasq mode - standalone file
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

# ============= Cleanup =============
cleanup() {
    rm -rf "$TMP_DIR"
}

# ============= Main =============
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

    case "$MODE" in
        smartdns)
            NEW_CONF=$(generate_smartdns_conf "$XBOX_CN_BEST" "$XBOX_CN_DL_BEST" "$MS_DELIVERY_BEST")
            ;;
        dnsmasq)
            NEW_CONF=$(generate_dnsmasq_conf "$XBOX_CN_BEST" "$XBOX_CN_DL_BEST" "$MS_DELIVERY_BEST")
            ;;
    esac

    # Flatten multiline IP lists to single line for JSON status
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
