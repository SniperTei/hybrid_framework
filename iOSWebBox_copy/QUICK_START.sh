#!/bin/bash

# iOSWebBox 快速启动脚本
# 这个脚本会帮助你快速创建一个可运行的 Xcode 项目

set -e

echo "🚀 iOSWebBox 快速启动向导"
echo "================================"
echo ""

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误：未找到 Xcode"
    echo "请先从 App Store 安装 Xcode"
    exit 1
fi

echo "✅ 找到 Xcode: $(xcodebuild -version | head -1)"
echo ""

# 创建项目目录
PROJECT_NAME="iOSWebBoxDemo"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "⚠️  项目目录已存在: $PROJECT_DIR"
    read -p "是否删除并重新创建？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_DIR"
    else
        echo "❌ 取消操作"
        exit 1
    fi
fi

echo "📦 创建 Xcode 项目..."
mkdir -p "$PROJECT_DIR"

# 使用 Xcode 命令行工具创建项目
# 但 xcodebuild 不支持直接创建项目，所以我们需要使用另一种方法

cat << 'EOF'

⚠️  请按照以下步骤手动创建 Xcode 项目：

方法 1：使用 Xcode GUI（推荐）

1. 打开 Xcode
2. 选择 "File → New → Project"
3. 选择 "iOS → App"
4. 填写项目信息：
   - Product Name: iOSWebBoxDemo
   - Team: 选择你的开发团队
   - Organization Identifier: com.sniper.webbox
   - Bundle Identifier: com.sniper.webbox.iosdemo
   - Interface: Storyboard
   - Language: Swift
   - 取消勾选所有额外选项
5. 保存到: $(pwd)
6. 点击 "Create"

方法 2：自动化创建

如果你想使用命令行创建项目，请安装 Ruby gem:

  gem install xcodeproj

然后运行 setup_with_ruby.rb 脚本

EOF

# 创建一个 Ruby 脚本作为替代方案
cat > "$PROJECT_DIR/setup_with_ruby.rb" << 'RUBYSCRIPT'
#!/usr/bin/env ruby

require 'xcodeproj'

# 创建 Xcode 项目
project = Xcodeproj::Project.new("iOSWebBoxDemo.xcodeproj")

# 配置项目
project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end

# 创建 App Target
app_target = project.new_target(:application, 'iOSWebBoxDemo', :ios, '14.0')

# 添加源文件
app_target.add_file_references([
  project.new_file('AppDelegate.swift'),
  project.new_file('SceneDelegate.swift'),
  project.new_file('HybridViewController.swift')
])

# 添加 Info.plist
info_plist = project.new_file('Info.plist')
app_target.build_settings('Debug').['INFOPLIST_FILE'] = 'Info.plist'
app_target.build_settings('Release').['INFOPLIST_FILE'] = 'Info.plist'

# 添加 SPM 依赖 (Alamofire)
project.root_object.package_references = [
  Xcodeproj::Project::Object::XCRemoteSwiftPackageReference.new(project, {
    'repositoryURL' => 'https://github.com/Alamofire/Alamofire.git',
    'versionRequirement' => { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '5.8.0' }
  })
]

# 保存项目
project.save

puts "✅ Xcode 项目创建成功！"
puts "现在可以用 Xcode 打开 iOSWebBoxDemo.xcodeproj"
RUBYSCRIPT

chmod +x "$PROJECT_DIR/setup_with_ruby.rb"

# 创建占位文件，这样用户可以立即开始
cat > "$PROJECT_DIR/PLACEHOLDER.txt" << 'EOF'
这是一个占位文件。

请按照 QUICK_START.sh 的输出说明创建 Xcode 项目，
或者使用 setup_with_ruby.rb 脚本自动创建（需要安装 xcodeproj gem）。

最简单的方法是：
1. 打开 Xcode
2. File → New → Project → iOS App
3. 按照 MANUAL_SETUP.md 的说明进行配置
EOF

echo "✅ 项目目录已创建: $PROJECT_DIR"
echo ""
echo "📋 下一步："
echo "   1. 查看 MANUAL_SETUP.md 获取详细说明"
echo "   2. 或者安装 xcodeproj gem: gem install xcodeproj"
echo "   3. 然后运行: cd $PROJECT_DIR && ruby setup_with_ruby.rb"
echo ""
echo "🎯 提示：最简单的方式是使用 Xcode GUI 手动创建项目"
