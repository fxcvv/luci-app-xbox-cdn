#!/bin/bash
# 使用 GitHub API 创建仓库（需要 Personal Access Token）

TOKEN="$GITHUB_TOKEN"
if [ -z "$TOKEN" ]; then
    read -sp "输入你的 GitHub Personal Access Token: " TOKEN
    echo ""
fi

USERNAME="$1"
if [ -z "$USERNAME" ]; then
    read -p "输入你的 GitHub 用户名: " USERNAME
fi

REPO_NAME="xbox-cdn-speedtest"

echo "创建仓库: $USERNAME/$REPO_NAME"

response=$(curl -s -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/user/repos \
    -d "{
        \"name\":\"$REPO_NAME\",
        \"description\":\"Automatic Xbox CDN optimization for OpenWrt routers\",
        \"homepage\":\"https://github.com/$USERNAME/$REPO_NAME\",
        \"private\":false,
        \"has_issues\":true,
        \"has_projects\":false,
        \"has_wiki\":true
    }")

if echo "$response" | grep -q "\"full_name\""; then
    echo "✓ 仓库创建成功！"
    echo "  https://github.com/$USERNAME/$REPO_NAME"
else
    echo "✗ 创建失败:"
    echo "$response" | grep "message"
fi
