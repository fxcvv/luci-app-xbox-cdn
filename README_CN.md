# luci-app-xbox-cdn

适用于 OpenWrt 的 Xbox CDN 优化工具，带 LuCI 网页界面。

自动测试多个 CDN 节点，将最快的 IP 写入 DNS 解析器——让 Xbox 下载走最优的国内 CDN，而不是绕道代理。

## 功能

- **LuCI 网页界面** — 手动触发测速、配置定时任务、切换模式、查看实时日志
- **SmartDNS & dnsmasq** — 自动检测端口 53 上运行的 DNS 服务
- **定时测速** — 通过界面设置每日定时，无需手动编辑 crontab
- **无损写入** — SmartDNS 模式只在 `custom.conf` 里写入一个标记块，不影响其他配置
- **命令行友好** — 所有脚本均可独立使用，不依赖 LuCI

## 依赖

- 带 LuCI 的 OpenWrt
- SmartDNS 或 dnsmasq 作为 DNS 解析器
- `curl`、`flock`（`util-linux-flock`）

## 安装

```sh
git clone https://github.com/fxcvv/luci-app-xbox-cdn.git
cd luci-app-xbox-cdn
sh install.sh
```

安装脚本会：
1. 自动检测端口 53 上的 DNS 服务（SmartDNS 或 dnsmasq）
2. 将脚本安装到 `/usr/bin/`
3. 安装 LuCI 界面（服务 → Xbox CDN 优化）
4. 可选：设置每日定时测速

## 使用

**LuCI：** 服务 → Xbox CDN 优化

**命令行：**
```sh
# 立即测速并应用
xbox-speedtest.sh --mode smartdns --apply
xbox-speedtest.sh --mode dnsmasq --apply

# 查看状态
xbox-cdn-run status

# 启用每天凌晨 3 点定时测速
xbox-cdn-cron enable 3 0

# 禁用定时测速
xbox-cdn-cron disable
```

## 工作原理

```
测试 CDN IP（XboxCN / AkamaiCN / MS Delivery）
  → 每组选出最快节点
  → 将 address 规则写入 DNS 解析器
  → 重启 DNS 服务

SmartDNS 模式：写入 /etc/smartdns/custom.conf
               通过 # BEGIN xbox-cdn / # END xbox-cdn 标记块管理
dnsmasq 模式：写入 /tmp/dnsmasq.d/xbox-cdn.conf
```

## 文件说明

| 文件 | 说明 |
|---|---|
| `xbox-speedtest.sh` | 核心测速和配置生成脚本 |
| `xbox-cdn-run` | 后台启动器，状态/日志读取 |
| `xbox-cdn-cron` | 定时任务管理 |
| `cdn-ips.conf` | 待测试的 CDN IP 列表 |
| `install.sh` | 交互式安装脚本 |
| `uninstall.sh` | 完整卸载脚本 |
| `luci-app/` | LuCI 网页界面文件 |

## 许可证

GPL-3.0
