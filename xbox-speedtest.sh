#!/bin/sh
# Xbox CDN Speedtest for OpenWrt
# Automatically test and select fastest CDN nodes
# License: GPL-3.0

set -e

# ============= Configuration =============
DNSMASQ_CONF="${DNSMASQ_CONF:-/tmp/dnsmasq.d/xbox-cdn.conf}"
LOG_FILE="${LOG_FILE:-/tmp/xbox-speedtest.log}"
CDN_IP_FILE="${CDN_IP_FILE:-/etc/xbox-cdn-ips.conf}"
LOCK_FILE="${LOCK_FILE:-/var/lock/xbox-speedtest.lock}"

TEST_SIZE="${TEST_SIZE:-10M}"
CONCURRENT="${CONCURRENT:-3}"
TIMEOUT="${TIMEOUT:-15}"
TOP_N="${TOP_N:-2}"

TMP_DIR="/tmp/xbox-speedtest-$$"

# ============= Logging =============
log() {
    local msg="[$(date +%H:%M:%S)] $*"
    echo "$msg" | tee -a "$LOG_FILE"
    logger -t xbox-speedtest "$*"
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

    if ! curl --version 2>&1 | grep -q "HTTP2"; then
        log "警告: curl 不支持 HTTP/2，测速可能不准确"
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

    # Parse IP file into arrays
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

    # Run concurrent downloads
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

    # Sort by speed and get top N
    sort -k2 -rn "$results_file" | head -n "$TOP_N"
}

# ============= Generate Configuration =============
generate_dnsmasq_conf() {
    local xbox_cn_best="$1"
    local xbox_cn_dl_best="$2"
    local ms_delivery_best="$3"
    local output="$TMP_DIR/dnsmasq.conf"

    cat > "$output" << EOF
# Xbox CDN Optimization
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# DO NOT EDIT MANUALLY - This file is auto-generated

EOF

    # Xbox CN - assets domains
    for ip in $xbox_cn_best; do
        cat >> "$output" << EOF
address=/assets1.xboxlive.cn/$ip
address=/assets2.xboxlive.cn/$ip
address=/d1.xboxlive.cn/$ip
address=/d2.xboxlive.cn/$ip
EOF
        break  # Use only the fastest
    done

    # Xbox CN DL - dlassets domains
    for ip in $xbox_cn_dl_best; do
        cat >> "$output" << EOF
address=/dlassets.xboxlive.cn/$ip
address=/dlassets2.xboxlive.cn/$ip
EOF
        break
    done

    # Microsoft Delivery
    for ip in $ms_delivery_best; do
        cat >> "$output" << EOF
address=/dl.delivery.mp.microsoft.com/$ip
address=/tlu.dl.delivery.mp.microsoft.com/$ip
EOF
        break
    done

    echo "$output"
}

# ============= Apply Configuration =============
apply_config() {
    local new_conf="$1"
    local backup="${DNSMASQ_CONF}.bak"

    # Check if config changed
    if [ -f "$DNSMASQ_CONF" ]; then
        if cmp -s "$new_conf" "$DNSMASQ_CONF"; then
            log "配置无变化，跳过重载"
            return 0
        fi

        log "配置已变化:"
        grep -vxF -f "$DNSMASQ_CONF" "$new_conf" 2>/dev/null | \
            while IFS= read -r line; do
                [ -n "$line" ] && log "    新: $line"
            done

        # Backup old config
        cp "$DNSMASQ_CONF" "$backup"
        log "已备份旧配置: $backup"
    fi

    # Apply new config
    mkdir -p "$(dirname "$DNSMASQ_CONF")"
    cp "$new_conf" "$DNSMASQ_CONF"
    log "已写入新配置: $DNSMASQ_CONF"

    # Reload dnsmasq
    if /etc/init.d/dnsmasq restart; then
        log "dnsmasq 重载成功"
        return 0
    else
        log "错误: dnsmasq 重载失败"
        # Restore backup
        if [ -f "$backup" ]; then
            cp "$backup" "$DNSMASQ_CONF"
            /etc/init.d/dnsmasq restart
            log "已恢复备份配置"
        fi
        return 1
    fi
}

# ============= Cleanup =============
cleanup() {
    rm -rf "$TMP_DIR"
}

# ============= Main =============
main() {
    trap cleanup EXIT

    log "========================================="
    log "Xbox CDN Speedtest 开始"
    log "========================================="

    check_dependencies
    acquire_lock
    load_cdn_ips

    mkdir -p "$TMP_DIR"

    # Test each CDN group
    XBOX_CN_BEST=$(test_group "XboxCN" "$XBOX_CN_IPS" "/filestable/" | awk '{print $1}')
    XBOX_CN_DL_BEST=$(test_group "XboxCN-DL" "$XBOX_CN_DL_IPS" "/filestable/" | awk '{print $1}')
    MS_DELIVERY_BEST=$(test_group "MS-Delivery" "$MS_DELIVERY_IPS" "/" | awk '{print $1}')

    # Optional: Test Akamai as backup
    # AKAMAI_BEST=$(test_group "Akamai" "$AKAMAI_IPS" "/filestable/" | awk '{print $1}')

    log ""
    log "最优 IP 选择完成"

    # Generate and apply configuration
    NEW_CONF=$(generate_dnsmasq_conf "$XBOX_CN_BEST" "$XBOX_CN_DL_BEST" "$MS_DELIVERY_BEST")

    if apply_config "$NEW_CONF"; then
        log "========================================="
        log "优化完成"
        log "========================================="
    else
        log "========================================="
        log "优化失败"
        log "========================================="
        exit 1
    fi
}

# Load custom config if exists
[ -f /etc/xbox-speedtest.conf ] && . /etc/xbox-speedtest.conf

main "$@"
