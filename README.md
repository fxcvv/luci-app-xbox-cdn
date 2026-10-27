# luci-app-xbox-cdn

优化 Xbox 下载速度：自动测速选出最快的国内 CDN 节点，让下载直连，不占用代理带宽。

适用于 OpenWrt，带 LuCI 网页界面。

## 功能

- **LuCI 界面**：手动测速、定时测速、切换写入目标、查看实时日志
- **支持 SmartDNS 和 dnsmasq**：安装时自动检测 53 端口上的 DNS 服务
- **定时测速**：在界面里设置，无需手动编辑 crontab
- **无损写入**：SmartDNS 模式只在 `custom.conf` 里维护一个标记块，不影响其他配置
- **可独立使用**：所有脚本都能脱离 LuCI 在命令行运行

## 关于联机

本工具只处理下载用的 CDN 域名，不影响联机流量。

如果你的代理按"国内 IP 直连"分流（例如 PassWall 的大陆白名单），下载会被解析到国内节点并直连，不再占用代理带宽，边下载边联机时更稳定。联机本身是否走代理，由你的分流规则决定。

## 依赖

- 带 LuCI 的 OpenWrt
- SmartDNS 或 dnsmasq
- `curl`、`flock`（`util-linux-flock`）

## 安装

```sh
git clone https://github.com/fxcvv/luci-app-xbox-cdn.git
cd luci-app-xbox-cdn
sh install.sh
```

安装脚本会：
1. 检测 53 端口上的 DNS 服务
2. 把脚本安装到 `/usr/bin/`
3. 安装 LuCI 界面（服务 → Xbox CDN 优化）
4. 询问是否开启每日定时测速

卸载：`sh uninstall.sh`

## 使用

**LuCI：** 服务 → Xbox CDN 优化

**命令行：**
```sh
# 立即测速并应用
xbox-speedtest.sh --mode smartdns --apply
xbox-speedtest.sh --mode dnsmasq --apply

# 查看状态
xbox-cdn-run status

# 每天 3:00 定时测速
xbox-cdn-cron enable 3 0

# 停用定时测速
xbox-cdn-cron disable
```

## 工作原理

```
按分组测速 CDN IP（XboxCN / XboxCN-DL / MS Delivery）
  → 每组选出最快的节点
  → 把 address 规则写入 DNS 服务
  → 重启 DNS 服务

SmartDNS：写入 /etc/smartdns/custom.conf
          中 # BEGIN xbox-cdn 与 # END xbox-cdn 之间的块
dnsmasq： 写入 /tmp/dnsmasq.d/xbox-cdn.conf
```

## 贡献域名和节点

所有 CDN IP 和域名都在 `cdn-ips.conf` 里，补充时只需改这一个文件：

```conf
XBOX_CN 1.2.3.4                     # 给分组加一个待测 IP
DOMAIN XBOX_CN assets3.xboxlive.cn  # 让域名使用该分组的最优 IP
```

提交前请先用 `nslookup <域名> 223.5.5.5` 确认能解析到国内节点。

## 文件说明

| 文件 | 说明 |
|---|---|
| `xbox-speedtest.sh` | 测速与规则生成 |
| `xbox-cdn-run` | 后台启动、状态和日志查询 |
| `xbox-cdn-cron` | 定时任务管理 |
| `cdn-ips.conf` | CDN IP 与域名列表 |
| `install.sh` / `uninstall.sh` | 安装 / 卸载 |
| `luci-app/` | LuCI 界面文件 |

## 许可证

GPL-3.0
