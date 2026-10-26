#!/bin/sh
# Xbox CDN Speedtest 卸载程序

echo "=== Xbox CDN Speedtest 卸载程序 ==="
echo ""
echo "警告: 此操作将删除以下内容："
echo "  - /etc/xbox-speedtest.sh"
echo "  - /etc/xbox-cdn-ips.conf"
echo "  - /etc/xbox-speedtest.conf (如果存在)"
echo "  - /tmp/dnsmasq.d/xbox-cdn.conf"
echo "  - crontab 定时任务"
echo ""
read -p "确认卸载？(y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "取消卸载"
    exit 0
fi

echo ""
echo "开始卸载..."

# 移除定时任务
if grep -q "xbox-speedtest.sh" /etc/crontabs/root 2>/dev/null; then
    grep -v "xbox-speedtest.sh" /etc/crontabs/root > /tmp/crontab.tmp
    mv /tmp/crontab.tmp /etc/crontabs/root
    /etc/init.d/cron restart
    echo "  ✓ 已移除定时任务"
fi

# 移除 dnsmasq 配置
if [ -f /tmp/dnsmasq.d/xbox-cdn.conf ]; then
    rm -f /tmp/dnsmasq.d/xbox-cdn.conf
    /etc/init.d/dnsmasq restart
    echo "  ✓ 已移除 dnsmasq 配置并重载"
fi

# 移除脚本文件
rm -f /etc/xbox-speedtest.sh
rm -f /etc/xbox-speedtest.conf
echo "  ✓ 已移除脚本文件"

# 询问是否保留 IP 配置
read -p "是否保留 CDN IP 配置？(y/n，默认 n): " keep_config
keep_config="${keep_config:-n}"

if [ "$keep_config" != "y" ] && [ "$keep_config" != "Y" ]; then
    rm -f /etc/xbox-cdn-ips.conf
    echo "  ✓ 已移除 CDN IP 配置"
else
    echo "  已保留 /etc/xbox-cdn-ips.conf"
fi

# 清理日志
read -p "是否删除日志文件？(y/n，默认 y): " del_log
del_log="${del_log:-y}"

if [ "$del_log" = "y" ] || [ "$del_log" = "Y" ]; then
    rm -f /tmp/xbox-speedtest.log
    echo "  ✓ 已删除日志文件"
fi

echo ""
echo "=== 卸载完成 ==="
