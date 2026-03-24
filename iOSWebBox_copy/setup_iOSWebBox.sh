#!/bin/bash

# iOSWebBox Xcode 项目生成脚本

set -e

PROJECT_NAME="iOSWebBoxDemo"
BUNDLE_ID="com.sniper.webbox.iosdemo"
MIN_VERSION="14.0"

echo "🚀 Creating iOSWebBox Xcode project..."

# 检查是否安装了 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

# 创建 Xcode 项目
echo "📦 Creating Xcode project..."

# 使用 Xcode 命令行工具创建项目
# 注意：这需要 Xcode 的命令行工具
xcodebuild -version

# 创建项目目录
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# 创建 iOS App 项目
# 使用 swift package init --type executable 对于 iOS 应用不适用
# 我们需要手动创建 Xcode 项目文件

echo "⚠️  Please use Xcode manually:"
echo ""
echo "1. Open Xcode"
echo "2. File → New → Project"
echo "3. Choose 'App' under iOS tab"
echo "4. Product Name: $PROJECT_NAME"
echo "5. Bundle Identifier: $BUNDLE_ID"
echo "6. Interface:Storyboard (we'll remove it later)"
echo "7. Language: Swift"
echo "8. Save to: $(pwd)/.."
echo ""
echo "Then follow the manual setup instructions in MANUAL_SETUP.md"

echo ""
echo "✅ Script created directory structure"
