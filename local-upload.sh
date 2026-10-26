#!/bin/bash
# 在本地电脑运行，用于首次上传到 GitHub

set -e

echo "=== Xbox CDN Speedtest GitHub 上传助手 ==="
echo ""

# 检查 git
if ! command -v git &> /dev/null; then
    echo "错误: 未安装 git"
    echo "请先安装: https://git-scm.com/downloads"
    exit 1
fi

# 获取 GitHub 用户名
read -p "输入你的 GitHub 用户名: " username
if [ -z "$username" ]; then
    echo "错误: 用户名不能为空"
    exit 1
fi

# 更新文件中的占位符
echo ""
echo "更新文件中的 GitHub 用户名..."
for file in README.md README_CN.md QUICKSTART.md install.sh RELEASE_NOTES.md; do
    if [ -f "$file" ]; then
        sed -i.bak "s/YOUR_USERNAME/$username/g" "$file" && rm "$file.bak"
        echo "  ✓ $file"
    fi
done

# 初始化 git
echo ""
echo "初始化 Git 仓库..."
if [ ! -d .git ]; then
    git init
    echo "  ✓ Git 仓库初始化"
else
    echo "  Git 仓库已存在"
fi

# 配置 git（如果未配置）
if [ -z "$(git config user.name)" ]; then
    read -p "输入你的 Git 用户名: " git_name
    git config user.name "$git_name"
fi
if [ -z "$(git config user.email)" ]; then
    read -p "输入你的 Git 邮箱: " git_email
    git config user.email "$git_email"
fi

# 添加所有文件
echo ""
echo "添加文件到 Git..."
git add .
git status --short

# 提交
echo ""
read -p "确认提交？(y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "已取消"
    exit 0
fi

git commit -m "Initial release v1.0.0

- Automated CDN speed testing for Xbox downloads
- Support Xbox China CDN, Akamai, Microsoft delivery CDN
- Interactive installation script
- Automatic dnsmasq configuration
- Cron job integration
- Comprehensive documentation in English and Chinese"

echo "  ✓ 代码已提交"

# 添加远程仓库
echo ""
repo_url="https://github.com/$username/xbox-cdn-speedtest.git"
echo "添加远程仓库: $repo_url"

if git remote | grep -q "origin"; then
    git remote set-url origin "$repo_url"
else
    git remote add origin "$repo_url"
fi

echo "  ✓ 远程仓库已配置"

# 推送
echo ""
echo "准备推送到 GitHub..."
echo "注意: 需要在 GitHub 上先创建 xbox-cdn-speedtest 仓库"
echo "      https://github.com/new"
echo ""
read -p "仓库已创建？按回车继续推送..." 

git branch -M main
if git push -u origin main; then
    echo ""
    echo "=== 上传成功！==="
    echo ""
    echo "仓库地址: https://github.com/$username/xbox-cdn-speedtest"
    echo ""
    echo "下一步:"
    echo "1. 访问仓库页面"
    echo "2. 创建 Release (Releases → New release)"
    echo "   - Tag: v1.0.0"
    echo "   - Title: Xbox CDN Speedtest v1.0.0"
    echo "   - 上传 ../xbox-cdn-speedtest-v1.0.tar.gz"
    echo "3. 添加 Topics: openwrt, xbox, cdn, speedtest"
else
    echo ""
    echo "推送失败，可能原因："
    echo "- 仓库未创建"
    echo "- 认证失败（需要 Personal Access Token）"
    echo "- 网络问题"
    echo ""
    echo "手动推送："
    echo "  git push -u origin main"
fi
