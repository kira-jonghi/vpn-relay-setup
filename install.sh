#!/bin/bash
# VPN Relay Setup Skill 一键安装脚本
# 其他agent运行这一行即可：
# bash <(curl -fsSL https://raw.githubusercontent.com/kira-jonghi/vpn-relay-setup/main/install.sh)

set -e

SKILL_NAME="vpn-relay-setup"
SKILL_DIR="$HOME/.hermes/skills/devops/$SKILL_NAME"
REPO_URL="https://raw.githubusercontent.com/kira-jonghi/vpn-relay-setup/main"

echo "📦 正在安装 $SKILL_NAME 技能..."

# 创建目录
mkdir -p "$SKILL_DIR"

# 下载技能文档
echo "⬇️  下载技能文档..."
curl -fsSL "$REPO_URL/SKILL.md" -o "$SKILL_DIR/SKILL.md"

echo ""
echo "✅ 安装完成！"
echo ""
echo "📖 使用方法："
echo "   skill_view(name='$SKILL_NAME')"
echo ""
echo "📁 文件位置："
echo "   $SKILL_DIR/SKILL.md"
