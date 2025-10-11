#!/bin/bash

# Sinan Chrome Extension Build and Package Script
# 构建并打包Chrome扩展

set -e  # 遇到错误时停止执行

echo "🚀 开始构建 Sinan Chrome 扩展..."

# 检查是否存在pnpm
if ! command -v pnpm &> /dev/null; then
    echo "❌ 错误: 未找到 pnpm，请先安装 pnpm"
    echo "💡 安装命令: npm install -g pnpm"
    exit 1
fi

# 检查是否存在package.json
if [ ! -f "package.json" ]; then
    echo "❌ 错误: 当前目录下未找到 package.json 文件"
    echo "💡 请确保在项目根目录下执行此脚本"
    exit 1
fi

# 自动递增版本号
echo "📝 自动递增版本号..."
MANIFEST_FILE="src/manifest.json"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "❌ 错误: 未找到 $MANIFEST_FILE 文件"
    exit 1
fi

# 获取当前版本号
CURRENT_VERSION=$(grep '"version":' "$MANIFEST_FILE" | sed 's/.*"version": *"\([^"]*\)".*/\1/')

if [ -z "$CURRENT_VERSION" ]; then
    echo "❌ 错误: 无法从 $MANIFEST_FILE 获取版本号"
    exit 1
fi

echo "📍 当前版本: v$CURRENT_VERSION"

# 递增版本号 (支持语义化版本号，如 1.3.3 -> 1.3.4)
# 使用 awk 来分割版本号并递增最后一位
NEW_VERSION=$(echo "$CURRENT_VERSION" | awk -F. '{print $1"."$2"."$3+1}')

# 更新 manifest.json 中的版本号
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS 使用 sed -i ''
    sed -i '' "s/\"version\": *\"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$MANIFEST_FILE"
else
    # Linux 使用 sed -i
    sed -i "s/\"version\": *\"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$MANIFEST_FILE"
fi

echo "🔝 版本已更新至: v$NEW_VERSION"

# 清理旧的构建文件
if [ -d "dist" ]; then
    echo "🧹 清理旧的构建文件..."
    rm -rf dist
fi

# 执行构建
echo "📦 开始构建..."
pnpm run build

# 检查构建是否成功
if [ ! -d "dist" ]; then
    echo "❌ 构建失败: dist 目录未生成"
    exit 1
fi

# 使用已更新的版本号
VERSION="$NEW_VERSION"

# 生成包名（包含日期和版本号）
DATE=$(date +"%Y%m%d")
PACKAGE_NAME="sinan-chrome-extension-v${DATE}_v${VERSION}.zip"

# 创建packages目录（如果不存在）
if [ ! -d "packages" ]; then
    mkdir packages
fi

# 进入dist目录并打包
echo "📁 打包扩展文件..."
cd dist

# 创建zip压缩包
zip -r "../packages/${PACKAGE_NAME}" . -x "*.DS_Store" "*.map"

cd ..

# 检查打包是否成功
if [ -f "packages/${PACKAGE_NAME}" ]; then
    echo "✅ 打包成功!"
    echo "📦 包文件: packages/${PACKAGE_NAME}"
    echo "📊 文件大小: $(du -h "packages/${PACKAGE_NAME}" | cut -f1)"
    echo "🏷️  版本信息: v${VERSION}"
    echo ""
    echo "🎉 Chrome扩展已准备就绪!"
    echo "💡 安装方法:"
    echo "   1. 打开 Chrome 浏览器"
    echo "   2. 访问 chrome://extensions/"
    echo "   3. 开启 '开发者模式'"
    echo "   4. 点击 '加载已解压的扩展程序'"
    echo "   5. 选择 dist 目录"
else
    echo "❌ 打包失败"
    exit 1
fi