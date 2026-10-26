# Xbox CDN Speedtest v1.0.0

自动测试并优化 OpenWrt 路由器上的 Xbox 下载速度。

## 快速安装

```bash
wget https://github.com/fxcvv/xbox-cdn-speedtest/archive/v1.0.0.tar.gz
tar -xzf v1.0.0.tar.gz
cd xbox-cdn-speedtest-1.0.0
./install.sh
```

## 主要功能

- ✅ 自动测速选择最快 CDN 节点
- ✅ 支持 Xbox 中国 CDN、Akamai、微软下载 CDN
- ✅ 自动生成和应用 dnsmasq 配置
- ✅ 定时任务自动优化
- ✅ 变更检测，避免不必要的重载

## 系统要求

- OpenWrt 路由器
- curl (建议支持 HTTP/2)
- dnsmasq
- 基础 shell 工具

## 文档

- [快速开始指南](QUICKSTART.md)
- [中文文档](README_CN.md)
- [English README](README.md)

## 效果

优化后 Xbox 下载速度可提升 2-5 倍（取决于网络环境）。

## 反馈

遇到问题或有建议，请提交 [Issue](https://github.com/fxcvv/xbox-cdn-speedtest/issues)。
