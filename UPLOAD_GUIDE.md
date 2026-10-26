# 上传到 GitHub 指南

## 在本地电脑操作

### 1. 下载项目文件

从路由器复制项目到本地：
```bash
scp root@你的路由器IP:/tmp/xbox-cdn-speedtest-v1.0.tar.gz .
tar -xzf xbox-cdn-speedtest-v1.0.tar.gz
cd xbox-cdn-speedtest
```

或者直接在本地创建新目录，把路由器上的文件复制过来。

### 2. 创建 GitHub 仓库

1. 登录 GitHub
2. 点击右上角 `+` → `New repository`
3. 填写信息：
   - Repository name: `xbox-cdn-speedtest`
   - Description: `Automatic Xbox CDN optimization for OpenWrt routers`
   - Public (勾选)
   - 不勾选 "Initialize with README"（我们已有文件）

### 3. 上传代码

在项目目录执行：

```bash
# 初始化仓库
git init
git add .
git commit -m "Initial release v1.0.0

- Automated CDN speed testing for Xbox downloads
- Support Xbox China CDN, Akamai, Microsoft delivery CDN
- Interactive installation script
- Automatic dnsmasq configuration
- Cron job integration
- Comprehensive documentation in English and Chinese"

# 关联远程仓库（替换 YOUR_USERNAME）
git remote add origin https://github.com/YOUR_USERNAME/xbox-cdn-speedtest.git

# 推送代码
git branch -M main
git push -u origin main
```

### 4. 创建 Release

1. 在 GitHub 仓库页面，点击 `Releases` → `Create a new release`
2. 填写信息：
   - Tag: `v1.0.0`
   - Release title: `Xbox CDN Speedtest v1.0.0`
   - Description: 复制 `RELEASE_NOTES.md` 的内容
3. 上传 `xbox-cdn-speedtest-v1.0.tar.gz` 作为附件
4. 点击 `Publish release`

### 5. 更新 README 中的链接

发布后，把所有 `YOUR_USERNAME` 替换为你的 GitHub 用户名：

```bash
# macOS/Linux
sed -i '' 's/YOUR_USERNAME/你的用户名/g' README.md README_CN.md QUICKSTART.md install.sh

# 或者手动编辑文件
```

然后提交更新：
```bash
git add .
git commit -m "Update GitHub username in documentation"
git push
```

### 6. 添加主题标签（Topics）

在 GitHub 仓库页面：
1. 点击右侧 `About` 旁的齿轮图标
2. 添加 Topics:
   - `openwrt`
   - `xbox`
   - `cdn`
   - `speedtest`
   - `network-optimization`
   - `dns`
   - `dnsmasq`

### 7. 启用 GitHub Pages（可选）

如果想要项目主页：
1. Settings → Pages
2. Source: `Deploy from a branch`
3. Branch: `main` / `/ (root)`
4. Save

几分钟后会生成 `https://YOUR_USERNAME.github.io/xbox-cdn-speedtest/`

## 推广建议

上传后可以分享到：
- OpenWrt 论坛
- V2EX
- NGA 玩家社区
- 相关 Telegram/QQ 群
- 恩山无线论坛

## 持续维护

后续更新流程：
1. 修改代码
2. 更新 `CHANGELOG.md`
3. 提交并打标签：
   ```bash
   git commit -am "Fix: 修复某某问题"
   git tag v1.0.1
   git push && git push --tags
   ```
4. 在 GitHub 创建新 Release

## 遇到问题？

- 忘记 GitHub 密码：用 SSH key 或 Personal Access Token
- Push 被拒绝：检查是否有权限，或先 pull
- 文件太大：检查 `.gitignore`，确保没提交日志文件
