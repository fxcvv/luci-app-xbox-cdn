# 更新日志

## [2.0.0] - 2026-10-26

### 新增
- LuCI 界面（luci-app-xbox-cdn）
  - 手动测速，实时刷新日志
  - SmartDNS / dnsmasq 写入目标切换
  - 定时测速设置
  - 状态显示（上次测速时间、当前模式）
- SmartDNS 写入模式（`--mode smartdns`）
  - 规则写入 `/etc/smartdns/custom.conf` 的标记块，不影响其他内容
- `xbox-cdn-run`：基于 start-stop-daemon 的后台启动器
- `xbox-cdn-cron`：定时任务管理
- 域名改为在 `cdn-ips.conf` 中配置，不再写死在脚本里
- 新增域名：`dlassets-ssl.xboxlive.com`、`fe3cr.delivery.mp.microsoft.com`
- 安装时自动检测 53 端口上的 DNS 服务
- UCI 配置（`/etc/config/xbox-cdn`）
- 项目文档与界面统一改为中文

### 修复
- `log()` 不再输出到 stdout，避免时间戳混入测速结果，导致写出无效 IP、SmartDNS 崩溃
- 定时任务改为通过 `xbox-cdn-run` 启动，状态能正常更新
- SmartDNS 模式下 `current-config` 只显示 xbox-cdn 块

### 移除
- `config.example`（改用 UCI 配置）
- `QUICKSTART.md`、`RELEASE_NOTES.md`、`README_CN.md`（合并进 README）
- `test-on-router.sh`（已过时）

## [1.0.0] - 2026-10-25

### 新增
- 首个版本
- Xbox 下载 CDN 自动测速
- 支持 Xbox 国内 CDN（xboxlive.cn）、Akamai、微软 Delivery
- 并发下载测速
- 自动生成 dnsmasq 配置
- 配置无变化时不重启
- 运行锁，防止重复执行
- 交互式安装 / 卸载脚本
