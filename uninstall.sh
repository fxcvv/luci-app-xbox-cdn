#!/bin/sh
# Xbox CDN Speedtest - Uninstaller
# https://github.com/fxcvv/xbox-cdn-speedtest

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_ok()   { echo "${GREEN}✓${NC} $*"; }
log_warn() { echo "${YELLOW}!${NC} $*"; }

echo "======================================"
echo " Xbox CDN Speedtest Uninstaller"
echo "======================================"
echo ""

xbox-cdn-cron disable 2>/dev/null && log_ok "Cron disabled" || true

for f in /usr/bin/xbox-speedtest.sh /usr/bin/xbox-cdn-run /usr/bin/xbox-cdn-cron; do
    rm -f "$f" && log_ok "Removed $f"
done

uci delete xbox-cdn 2>/dev/null && uci commit xbox-cdn 2>/dev/null || true
rm -f /etc/config/xbox-cdn && log_ok "UCI config removed"
rm -f /etc/xbox-cdn-ips.conf && log_ok "Removed CDN IP list"

rm -f /usr/share/luci/menu.d/luci-app-xbox-cdn.json
rm -f /usr/share/rpcd/acl.d/luci-app-xbox-cdn.json
rm -rf /www/luci-static/resources/view/xbox-cdn
/etc/init.d/rpcd restart >/dev/null 2>&1
log_ok "LuCI app removed"

if [ -f /etc/smartdns/custom.conf ]; then
    sed -i '/^# BEGIN xbox-cdn$/,/^# END xbox-cdn$/d' /etc/smartdns/custom.conf
    /etc/init.d/smartdns restart >/dev/null 2>&1
    log_ok "SmartDNS custom.conf cleaned"
fi

rm -f /tmp/dnsmasq.d/xbox-cdn.conf /etc/dnsmasq.d/xbox-cdn.conf
rm -f /tmp/xbox-cdn-status.json /tmp/xbox-speedtest.log

echo ""
log_ok "Uninstall complete."
