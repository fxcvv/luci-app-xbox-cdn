# Xbox CDN 测速优化脚本 (OpenWrt)

自动测试并优化 OpenWrt 路由器上的 Xbox 下载速度，通过选择最快的 CDN 节点。

## 问题背景

Xbox 下载慢的常见原因：
- DNS 分配的 CDN 节点不是最优
- 地理位置路由问题
- 默认节点网络拥堵

本脚本通过测速选出最快的 CDN IP，让路由器 DNS 直接返回最优节点。

## 功能特性

- ✅ 测试 Xbox 中国 CDN (xboxlive.cn)
- ✅ 测试 Akamai CDN 节点 (xboxlive.com)
- ✅ 测试微软下载 CDN
- ✅ 自动生成 dnsmasq 配置
- ✅ 变更检测 - 仅在必要时重载
- ✅ 并发下载测速准确
- ✅ 文件锁防止重复运行

## 系统要求

- OpenWrt 路由器
- `curl` (需支持 HTTP/2)
- `dnsmasq` DNS 服务
- `flock` (busybox 版本即可)
- 基础工具: `awk`, `grep`, `sed`

## 安装步骤

```bash
# 下载脚本
wget -O /etc/xbox-speedtest.sh https://raw.githubusercontent.com/fxcvv/xbox-cdn-speedtest/main/xbox-speedtest.sh
chmod +x /etc/xbox-speedtest.sh

# 下载 CDN IP 列表
wget -O /etc/xbox-cdn-ips.conf https://raw.githubusercontent.com/fxcvv/xbox-cdn-speedtest/main/cdn-ips.conf

# 测试运行
/etc/xbox-speedtest.sh

# 添加定时任务（每天凌晨 3:30）
echo "30 3 * * * /etc/xbox-speedtest.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

## 配置说明

编辑脚本顶部变量或创建 `/etc/xbox-speedtest.conf`:

```bash
DNSMASQ_CONF="/tmp/dnsmasq.d/xbox-cdn.conf"  # 配置输出路径
LOG_FILE="/tmp/xbox-speedtest.log"           # 日志位置
TEST_SIZE="10M"                               # 每次测试下载大小
CONCURRENT=3                                  # 并发下载数
TIMEOUT=15                                    # 单次测试超时
TOP_N=2                                       # 每组保留最快 IP 数量
```

## 工作原理

1. **加载 CDN IP** - 从 `cdn-ips.conf` 读取待测 IP
2. **并发测速** - 每个 IP 下载测试文件
3. **选择最快** - 每组 CDN 取前 2 名
4. **生成配置** - 创建 dnsmasq address 规则
5. **应用变更** - 仅在配置改变时重载 dnsmasq

## 优化的域名列表

- `assets1.xboxlive.cn`, `assets2.xboxlive.cn`
- `d1.xboxlive.cn`, `d2.xboxlive.cn`
- `dlassets.xboxlive.cn`, `dlassets2.xboxlive.cn`
- `assets1.xboxlive.com`, `assets2.xboxlive.com` (Akamai)
- `dl.delivery.mp.microsoft.com`

## 进阶用法

### 配合本地缓存服务器

如果你运行了本地 nginx 缓存 Xbox 下载：

```bash
# 编辑脚本使用本地缓存服务器
CACHE_SERVER="192.168.1.100"
# 修改测试 URL 指向缓存服务器
```

### 自定义测试 URL

脚本使用 Xbox CDN 真实路径测速。可自定义：
- `/filestable/` - Xbox 游戏文件路径
- 测试文件大小和超时时间

### 添加更多 CDN IP

编辑 `cdn-ips.conf` 添加你发现的快速节点：

```bash
# 通过 DNS 查询获取
nslookup assets1.xboxlive.cn 223.5.5.5

# 或监控 Xbox 主机的 DNS 请求
```

## 故障排查

**下载速度无改善：**
- 检查配置是否生成: `cat /tmp/dnsmasq.d/xbox-cdn.conf`
- 验证 dnsmasq 已重载: `/etc/init.d/dnsmasq status`
- 测试 DNS 解析: `nslookup assets1.xboxlive.cn`

**脚本运行失败：**
- 检查依赖: `which curl flock`
- 查看日志: `tail -f /tmp/xbox-speedtest.log`
- 手动运行查看详细输出

**测速超时：**
- 增大 `TIMEOUT` 值
- 减少 `CONCURRENT` 并发数
- 检查测试 URL 是否可访问

**配置不生效：**
- 确认 dnsmasq 包含配置目录: `grep conf-dir /etc/dnsmasq.conf`
- 检查路径是否正确: `ls -la /tmp/dnsmasq.d/`

## 效果示例

优化前：
```
Xbox 下载速度: 5-10 MB/s
```

优化后：
```
Xbox 下载速度: 25-35 MB/s
```

实际效果取决于你的网络环境和 CDN 节点质量。

## 贡献指南

欢迎贡献！请：
1. 在你的 OpenWrt 设备上测试
2. 记录兼容性问题
3. 提交改进的 PR

特别欢迎：
- 更多地区的 CDN IP 列表
- 其他 DNS 服务器适配（AdGuard Home 等）
- 性能优化建议

## 许可证

GPL-3.0 - 详见 LICENSE 文件

## 致谢

本项目源于在 OpenWrt 路由器上优化 Xbox 下载速度的实践经验。
