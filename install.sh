#!/bin/sh
# Xbox CDN Speedtest - Installer
# https://github.com/fxcvv/xbox-cdn-speedtest

set -e

INSTALL_DIR="/usr/bin"
CDN_IP_FILE="/etc/xbox-cdn-ips.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok()   { echo "${GREEN}✓${NC} $*"; }
log_warn() { echo "${YELLOW}!${NC} $*"; }
log_err()  { echo "${RED}✗${NC} $*"; }

echo "======================================"
echo " Xbox CDN Speedtest Installer"
echo "======================================"
echo ""

# Check dependencies
echo ">> Checking dependencies..."
MISSING=""
for cmd in curl flock awk grep sed netstat; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
    log_warn "Missing:$MISSING"
    log_warn "Install with: opkg update && opkg install$MISSING"
fi

# Detect DNS mode
echo ""
echo ">> Detecting DNS service on port 53..."
DETECTED=$(netstat -ulnp 2>/dev/null | awk '/:53 /{print $NF}' | grep -o '[a-zA-Z]*$' | head -1)
case "$DETECTED" in
    smartdns) DEFAULT_MODE="smartdns"; log_ok "Detected SmartDNS on port 53" ;;
    dnsmasq)  DEFAULT_MODE="dnsmasq";  log_ok "Detected dnsmasq on port 53" ;;
    *)        DEFAULT_MODE="dnsmasq";  log_warn "Could not detect, defaulting to dnsmasq" ;;
esac

# Ask user
echo ""
printf ">> Output target [smartdns/dnsmasq] (default: $DEFAULT_MODE): "
read -r USER_MODE
[ -z "$USER_MODE" ] && USER_MODE="$DEFAULT_MODE"
case "$USER_MODE" in
    smartdns|dnsmasq) ;;
    *) log_err "Invalid mode '$USER_MODE'"; exit 1 ;;
esac
log_ok "Using mode: $USER_MODE"

# Install scripts
echo ""
echo ">> Installing scripts..."
install -m 755 xbox-speedtest.sh "$INSTALL_DIR/xbox-speedtest.sh"
install -m 755 xbox-cdn-run      "$INSTALL_DIR/xbox-cdn-run"
install -m 755 xbox-cdn-cron     "$INSTALL_DIR/xbox-cdn-cron"
log_ok "Scripts installed to $INSTALL_DIR"

# Install CDN IP list
install -m 644 cdn-ips.conf "$CDN_IP_FILE"
log_ok "CDN IP list installed to $CDN_IP_FILE"

# Install UCI config
if [ ! -f /etc/config/xbox-cdn ]; then
    cat > /etc/config/xbox-cdn << EOF
config settings 'settings'
	option mode '$USER_MODE'
	option cron_enabled '0'
	option cron_hour '3'
	option cron_min '0'
EOF
    log_ok "UCI config created: /etc/config/xbox-cdn"
else
    uci set xbox-cdn.settings.mode="$USER_MODE"
    uci commit xbox-cdn
    log_ok "UCI config updated (mode=$USER_MODE)"
fi

# Install LuCI app
if [ -d luci-app/root ]; then
    echo ""
    echo ">> Installing LuCI app..."
    cp luci-app/root/usr/share/luci/menu.d/luci-app-xbox-cdn.json \
       /usr/share/luci/menu.d/ 2>/dev/null && \
    cp luci-app/root/usr/share/rpcd/acl.d/luci-app-xbox-cdn.json \
       /usr/share/rpcd/acl.d/ 2>/dev/null && \
    mkdir -p /www/luci-static/resources/view/xbox-cdn && \
    cp luci-app/root/www/luci-static/resources/view/xbox-cdn/cdn.js \
       /www/luci-static/resources/view/xbox-cdn/ 2>/dev/null && \
    /etc/init.d/rpcd restart >/dev/null 2>&1 && \
    log_ok "LuCI app installed (Services → Xbox CDN 优化)" || \
    log_warn "LuCI app install failed (optional, CLI still works)"
fi

# Cron setup
echo ""
printf ">> Enable scheduled speed test? [y/N]: "
read -r CRON_ENABLE
if [ "$CRON_ENABLE" = "y" ] || [ "$CRON_ENABLE" = "Y" ]; then
    printf ">> Run at hour [0-23] (default: 3): "
    read -r CRON_HOUR
    [ -z "$CRON_HOUR" ] && CRON_HOUR=3
    xbox-cdn-cron enable "$CRON_HOUR" 0
    uci set xbox-cdn.settings.cron_enabled=1
    uci set xbox-cdn.settings.cron_hour="$CRON_HOUR"
    uci commit xbox-cdn
    log_ok "Scheduled daily at ${CRON_HOUR}:00"
fi

echo ""
echo "======================================"
log_ok "Installation complete!"
echo ""
echo "  Run test now:  xbox-speedtest.sh --mode $USER_MODE --apply"
echo "  LuCI:          Services → Xbox CDN 优化"
echo "======================================"
