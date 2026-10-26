# 快速开始

## 一键安装（推荐）

```bash
# 下载安装脚本
cd /tmp
wget https://github.com/fxcvv/xbox-cdn-speedtest/archive/main.tar.gz
tar -xzf main.tar.gz
cd xbox-cdn-speedtest-main

# 运行安装
./install.sh
```

安装程序会：
1. 检查系统依赖
2. 安装脚本到 `/etc`
3. 配置 dnsmasq
4. 添加定时任务（可选）
5. 立即运行一次测速（可选）

## 手动安装

如果你想逐步安装或自定义路径：

### 1. 下载文件

```bash
wget -O /etc/xbox-speedtest.sh \
  https://raw.githubusercontent.com/fxcvv/xbox-cdn-speedtest/main/xbox-speedtest.sh

wget -O /etc/xbox-cdn-ips.conf \
  https://raw.githubusercontent.com/fxcvv/xbox-cdn-speedtest/main/cdn-ips.conf

chmod +x /etc/xbox-speedtest.sh
```

### 2. 配置 dnsmasq

```bash
# 添加配置目录
echo "conf-dir=/tmp/dnsmasq.d" >> /etc/dnsmasq.conf
mkdir -p /tmp/dnsmasq.d
```

### 3. 首次运行

```bash
/etc/xbox-speedtest.sh
```

查看日志：
```bash
tail -f /tmp/xbox-speedtest.log
```

### 4. 添加定时任务（可选）

```bash
# 每天凌晨 3:30 运行
echo "30 3 * * * /etc/xbox-speedtest.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

## 验证效果

### 检查 DNS 配置

```bash
cat /tmp/dnsmasq.d/xbox-cdn.conf
```

应该看到类似：
```
address=/assets1.xboxlive.cn/101.227.95.78
address=/assets2.xboxlive.cn/101.227.95.78
...
```

### 测试 DNS 解析

```bash
nslookup assets1.xboxlive.cn
```

应该返回脚本选择的 IP。

### Xbox 下载测速

在 Xbox 上：
1. 设置 → 系统 → 网络设置 → 测试网络速度
2. 或开始下载游戏/更新，观察速度

## 常见问题

### Q: 脚本运行后没有效果？

检查 dnsmasq 是否重载：
```bash
/etc/init.d/dnsmasq status
ps | grep dnsmasq
```

### Q: curl 不支持 HTTP/2？

安装 curl 完整版：
```bash
opkg update
opkg install curl
```

### Q: 测速全部超时？

1. 检查路由器能否访问互联网
2. 增大超时时间（编辑脚本 `TIMEOUT=30`）
3. 减少并发数（编辑脚本 `CONCURRENT=1`）

### Q: 想添加自己发现的快速 IP？

编辑 `/etc/xbox-cdn-ips.conf`：
```bash
vi /etc/xbox-cdn-ips.conf
# 添加 IP 后重新运行脚本
/etc/xbox-speedtest.sh
```

## 卸载

运行卸载脚本：
```bash
cd /tmp/xbox-cdn-speedtest-main
./uninstall.sh
```

或手动删除：
```bash
rm /etc/xbox-speedtest.sh
rm /etc/xbox-cdn-ips.conf
rm /tmp/dnsmasq.d/xbox-cdn.conf
# 移除 crontab 中的任务
crontab -e
```

## 进阶配置

创建 `/etc/xbox-speedtest.conf` 自定义参数：
```bash
cat > /etc/xbox-speedtest.conf << 'CONF'
# 自定义配置
TEST_SIZE="20M"      # 增大测试文件
CONCURRENT=5         # 增加并发数
TIMEOUT=20           # 延长超时
TOP_N=3              # 保留前 3 个最快 IP
CONF
```

下次运行时会自动加载。
