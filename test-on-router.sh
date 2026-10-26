#!/bin/sh
# 在路由器上测试脚本的验证工具

echo "=== Xbox CDN Speedtest 测试工具 ==="
echo ""

# 1. 检查依赖
echo "[1/6] 检查依赖..."
ok=0
fail=0
for cmd in curl flock awk grep sed bc; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✓ $cmd"
        ok=$((ok+1))
    else
        echo "  ✗ $cmd (缺失)"
        fail=$((fail+1))
    fi
done
echo "  依赖检查: $ok 通过, $fail 失败"

# 2. 检查 curl HTTP/2 支持
echo ""
echo "[2/6] 检查 curl HTTP/2 支持..."
if curl --version 2>&1 | grep -q "HTTP2"; then
    echo "  ✓ curl 支持 HTTP/2"
else
    echo "  ✗ curl 不支持 HTTP/2 (建议: opkg install curl)"
fi

# 3. 测试 CDN 连通性
echo ""
echo "[3/6] 测试 CDN 连通性..."
test_ips="101.227.95.78 61.170.68.69 117.89.179.132"
for ip in $test_ips; do
    if timeout 5 curl -sk -o /dev/null -w "%{http_code}" "http://$ip/" 2>/dev/null | grep -q "200\|301\|302"; then
        echo "  ✓ $ip 可达"
    else
        echo "  ✗ $ip 超时/失败"
    fi
done

# 4. 测试 DNS 配置
echo ""
echo "[4/6] 检查 dnsmasq 配置..."
if [ -f /etc/dnsmasq.conf ]; then
    echo "  ✓ dnsmasq.conf 存在"
    if grep -q "conf-dir=/tmp/dnsmasq.d" /etc/dnsmasq.conf; then
        echo "  ✓ conf-dir 已配置"
    else
        echo "  ✗ conf-dir 未配置 (需要: conf-dir=/tmp/dnsmasq.d)"
    fi
else
    echo "  ✗ dnsmasq.conf 不存在"
fi

# 5. 检查已有配置
echo ""
echo "[5/6] 检查现有优化配置..."
if [ -f /tmp/dnsmasq.d/xbox-cdn.conf ]; then
    echo "  ✓ Xbox CDN 配置存在"
    echo "  当前配置:"
    head -n 10 /tmp/dnsmasq.d/xbox-cdn.conf | grep -v "^#" | grep -v "^$"
else
    echo "  - Xbox CDN 配置不存在 (首次运行会生成)"
fi

# 6. 快速测速示例
echo ""
echo "[6/6] 快速测速示例..."
echo "  测试 Xbox CN CDN: 101.227.95.78"
time_result=$(curl -sk --resolve "*:80:101.227.95.78" \
    -w "%{time_total}" -o /dev/null -m 10 \
    "http://101.227.95.78/" 2>/dev/null || echo "0")

if [ "$time_result" != "0" ]; then
    echo "  响应时间: ${time_result}s"
else
    echo "  测试失败"
fi

echo ""
echo "=== 测试完成 ==="
echo ""
echo "下一步:"
echo "  1. 如有缺失依赖，运行: opkg update && opkg install [缺失的包]"
echo "  2. 如未配置 conf-dir，运行: echo 'conf-dir=/tmp/dnsmasq.d' >> /etc/dnsmasq.conf"
echo "  3. 运行完整测速: /etc/xbox-speedtest.sh"
