#!/bin/sh
# luci-app-xbox-cdn 安装脚本
# https://github.com/fxcvv/xbox-cdn-speedtest

set -e

INSTALL_DIR="/usr/bin"
CDN_IP_FILE="/etc/xbox-cdn-ips.conf"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo "${GREEN}✓${NC} $*"; }
log_warn() { echo "${YELLOW}!${NC} $*"; }
log_err()  { echo "${RED}✗${NC} $*"; }

echo "======================================"
echo " Xbox CDN 优化 安装程序"
echo "======================================"
echo ""

# 检查依赖
echo ">> 检查依赖..."
MISSING=""
for cmd in curl flock awk grep sed netstat; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
    log_warn "缺少依赖:$MISSING"
    log_warn "可通过以下命令安装: opkg update && opkg install$MISSING"
fi

# 检测 DNS 模式
echo ""
echo ">> 检测 53 端口上的 DNS 服务..."
DETECTED=$(netstat -ulnp 2>/dev/null | awk '/:53 /{print $NF}' | grep -o '[a-zA-Z]*$' | head -1)
case "$DETECTED" in
    smartdns) DEFAULT_MODE="smartdns"; log_ok "检测到 SmartDNS" ;;
    dnsmasq)  DEFAULT_MODE="dnsmasq";  log_ok "检测到 dnsmasq" ;;
    *)        DEFAULT_MODE="dnsmasq";  log_warn "未能识别，默认使用 dnsmasq" ;;
esac

# 询问用户
echo ""
printf ">> 写入目标 [smartdns/dnsmasq]（默认 $DEFAULT_MODE）: "
read -r USER_MODE
[ -z "$USER_MODE" ] && USER_MODE="$DEFAULT_MODE"
case "$USER_MODE" in
    smartdns|dnsmasq) ;;
    *) log_err "无效的模式 '$USER_MODE'"; exit 1 ;;
esac
log_ok "使用模式: $USER_MODE"

# 安装脚本
echo ""
echo ">> 安装脚本..."
cp xbox-speedtest.sh "$INSTALL_DIR/xbox-speedtest.sh" && chmod 755 "$INSTALL_DIR/xbox-speedtest.sh"
cp xbox-cdn-run "$INSTALL_DIR/xbox-cdn-run" && chmod 755 "$INSTALL_DIR/xbox-cdn-run"
cp xbox-cdn-cron "$INSTALL_DIR/xbox-cdn-cron" && chmod 755 "$INSTALL_DIR/xbox-cdn-cron"
log_ok "脚本已安装到 $INSTALL_DIR"

# 安装 CDN 列表
cp cdn-ips.conf "$CDN_IP_FILE" && chmod 644 "$CDN_IP_FILE"
log_ok "CDN 列表已安装到 $CDN_IP_FILE"

# 安装 UCI 配置
if [ ! -f /etc/config/xbox-cdn ]; then
    cat > /etc/config/xbox-cdn << EOF
config settings 'settings'
	option mode '$USER_MODE'
	option cron_enabled '0'
	option cron_hour '3'
	option cron_min '0'
EOF
    log_ok "已创建 UCI 配置: /etc/config/xbox-cdn"
else
    uci set xbox-cdn.settings.mode="$USER_MODE"
    uci commit xbox-cdn
    log_ok "已更新 UCI 配置（mode=$USER_MODE）"
fi

# 安装 LuCI 界面（系统没有 LuCI 时跳过，只用命令行）
HAS_LUCI=0
[ -d /usr/share/luci/menu.d ] && [ -f /www/luci-static/resources/luci.js ] && HAS_LUCI=1

if [ "$HAS_LUCI" = "0" ]; then
    echo ""
    log_warn "未检测到 LuCI，跳过界面安装，可使用命令行"
elif [ -d luci-app/root ]; then
    echo ""
    echo ">> 安装 LuCI 界面..."
    cp luci-app/root/usr/share/luci/menu.d/luci-app-xbox-cdn.json \
       /usr/share/luci/menu.d/ 2>/dev/null && \
    cp luci-app/root/usr/share/rpcd/acl.d/luci-app-xbox-cdn.json \
       /usr/share/rpcd/acl.d/ 2>/dev/null && \
    mkdir -p /www/luci-static/resources/view/xbox-cdn && \
    cp luci-app/root/www/luci-static/resources/view/xbox-cdn/cdn.js \
       /www/luci-static/resources/view/xbox-cdn/ 2>/dev/null && \
    /etc/init.d/rpcd restart >/dev/null 2>&1 && \
    log_ok "LuCI 界面已安装（服务 → Xbox CDN 优化）" || \
    log_warn "LuCI 界面安装失败（不影响命令行使用）"
fi

# 定时任务
echo ""
printf ">> 是否启用定时测速？[y/N]: "
read -r CRON_ENABLE
if [ "$CRON_ENABLE" = "y" ] || [ "$CRON_ENABLE" = "Y" ]; then
    printf ">> 每天几点执行 [0-23]（默认 3）: "
    read -r CRON_HOUR
    [ -z "$CRON_HOUR" ] && CRON_HOUR=3
    xbox-cdn-cron enable "$CRON_HOUR" 0
    uci set xbox-cdn.settings.cron_enabled=1
    uci set xbox-cdn.settings.cron_hour="$CRON_HOUR"
    uci commit xbox-cdn
    log_ok "已设置每天 ${CRON_HOUR}:00 定时测速"
fi

echo ""
echo "======================================"
log_ok "安装完成"
echo ""
echo "  立即测速:  xbox-speedtest.sh --mode $USER_MODE --apply"
[ "$HAS_LUCI" = "1" ] && echo "  LuCI 界面: 服务 → Xbox CDN 优化"
echo "======================================"
