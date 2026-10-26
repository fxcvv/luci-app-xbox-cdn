#!/bin/sh
# Xbox CDN Speedtest Installer for OpenWrt

set -e

INSTALL_DIR="/etc"
SCRIPT_NAME="xbox-speedtest.sh"
CONFIG_NAME="xbox-cdn-ips.conf"
CRON_TIME="30 3"  # 默认凌晨 3:30

echo "=== Xbox CDN Speedtest 安装程序 ==="
echo ""

# 检查依赖
echo "检查系统依赖..."
missing=""
for cmd in curl flock awk grep sed; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing="$missing $cmd"
    fi
done

if [ -n "$missing" ]; then
    echo "错误: 缺少依赖:$missing"
    echo "请先安装: opkg update && opkg install$missing"
    exit 1
fi

# 检查 curl HTTP/2 支持
if ! curl --version 2>&1 | grep -q "HTTP2"; then
    echo "警告: curl 不支持 HTTP/2，建议安装 curl-openssl"
    echo "      opkg update && opkg install curl"
fi

# 安装脚本
echo ""
echo "安装脚本到 $INSTALL_DIR/$SCRIPT_NAME ..."
if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    cp "$INSTALL_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME.bak"
    echo "  已备份旧版本: $INSTALL_DIR/$SCRIPT_NAME.bak"
fi
cp "$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo "  ✓ 脚本安装完成"

# 安装 CDN IP 配置
echo ""
echo "安装 CDN IP 配置到 $INSTALL_DIR/$CONFIG_NAME ..."
if [ -f "$INSTALL_DIR/$CONFIG_NAME" ]; then
    echo "  配置文件已存在，跳过（保留你的自定义配置）"
else
    cp "$CONFIG_NAME" "$INSTALL_DIR/$CONFIG_NAME"
    echo "  ✓ 配置文件安装完成"
fi

# 创建 dnsmasq 配置目录
echo ""
echo "配置 dnsmasq ..."
if ! grep -q "conf-dir=/tmp/dnsmasq.d" /etc/dnsmasq.conf 2>/dev/null; then
    echo "conf-dir=/tmp/dnsmasq.d" >> /etc/dnsmasq.conf
    echo "  ✓ 已添加 dnsmasq 配置目录"
else
    echo "  dnsmasq 配置目录已存在"
fi
mkdir -p /tmp/dnsmasq.d

# 询问是否添加定时任务
echo ""
read -p "是否添加定时任务？(y/n，默认 y): " add_cron
add_cron="${add_cron:-y}"

if [ "$add_cron" = "y" ] || [ "$add_cron" = "Y" ]; then
    echo "  设置定时任务时间（格式: 分钟 小时，例如: 30 3 表示 3:30）"
    read -p "  默认 [$CRON_TIME]: " user_time
    user_time="${user_time:-$CRON_TIME}"
    
    cron_entry="$user_time * * * $INSTALL_DIR/$SCRIPT_NAME"
    
    # 移除旧的任务
    grep -v "$SCRIPT_NAME" /etc/crontabs/root > /tmp/crontab.tmp 2>/dev/null || touch /tmp/crontab.tmp
    echo "$cron_entry" >> /tmp/crontab.tmp
    mv /tmp/crontab.tmp /etc/crontabs/root
    
    /etc/init.d/cron restart
    echo "  ✓ 定时任务已添加: 每天 $(echo $user_time | awk '{print $2":"$1}') 运行"
fi

# 询问是否立即运行
echo ""
read -p "是否立即运行一次测速？(y/n，默认 y): " run_now
run_now="${run_now:-y}"

if [ "$run_now" = "y" ] || [ "$run_now" = "Y" ]; then
    echo ""
    echo "=== 开始测速 ==="
    "$INSTALL_DIR/$SCRIPT_NAME"
fi

echo ""
echo "=== 安装完成 ==="
echo ""
echo "使用方法:"
echo "  手动运行: $INSTALL_DIR/$SCRIPT_NAME"
echo "  查看日志: tail -f /tmp/xbox-speedtest.log"
echo "  编辑配置: vi $INSTALL_DIR/$CONFIG_NAME"
echo "  卸载: rm $INSTALL_DIR/$SCRIPT_NAME $INSTALL_DIR/$CONFIG_NAME"
echo ""
