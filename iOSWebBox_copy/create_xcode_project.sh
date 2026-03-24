#!/bin/bash

# 创建完整的 Xcode 项目
# 这个脚本会生成一个可以直接在 Xcode 中打开的项目

PROJECT_NAME="iOSWebBoxDemo"
BUNDLE_ID="com.sniper.webbox.iosdemo"
SRC_DIR="iOSWebBox"
DEST_DIR="iOSWebBoxDemo"

echo "🚀 创建 iOSWebBox Xcode 项目..."

# 创建项目目录结构
mkdir -p "$DEST_DIR"
cd "$DEST_DIR"

# 创建 Xcode 项目
# 使用 Python 和 xcodeproj 库来创建项目
cat > "create_project.py" << 'PYTHON_SCRIPT'
#!/usr/bin/env python3
import os
import subprocess

print("=" * 60)
print("iOSWebBox Xcode 项目创建工具")
print("=" * 60)
print()

# 检查是否安装了 xcodeproj
try:
    import xcodeproj
except ImportError:
    print("⚠️  未找到 xcodeproj Python 库")
    print()
    print("请选择安装方式：")
    print()
    print("方法 1：使用 pip 安装（推荐）")
    print("  pip3 install xcodeproj")
    print("  python3 create_project.py")
    print()
    print("方法 2：使用 Xcode GUI 手动创建")
    print("  1. 打开 Xcode")
    print("  2. File → New → Project → iOS App")
    print("  3. 按照 MANUAL_SETUP.md 配置")
    print()
    exit(1)

from xcodeproj import XcodeProject
from xcodeproj.constants import FileTypes

# 创建项目
project = XcodeProject.create('iOSWebBoxDemo.xcodeproj', 'iOSWebBoxDemo')

# 配置构建设置
for config in project.objects.get('buildConfigurationList', {}).values():
    if hasattr(config, 'buildSettings'):
        config.buildSettings.update({
            'IPHONEOS_DEPLOYMENT_TARGET': '14.0',
            'SWIFT_VERSION': '5.0',
            'TARGETED_DEVICE_FAMILY': '1,2',
            'PRODUCT_BUNDLE_IDENTIFIER': 'com.sniper.webbox.iosdemo',
            'SWIFT_OBJC_BRIDGING_HEADER': '',
            'ENABLE_TESTABILITY': 'YES',
        })

# 添加 Alamofire SPM 依赖
try:
    project.add_package('https://github.com/Alamofire/Alamofire.git', version='5.8.0')
    print("✅ 添加 Alamofire 依赖")
except Exception as e:
    print(f"⚠️  添加 Alamofire 失败: {e}")

# 保存项目
project.save()

print()
print("=" * 60)
print("✅ Xcode 项目创建成功！")
print("=" * 60)
print()
print("项目位置: iOSWebBoxDemo.xcodeproj")
print()
print("下一步：")
print("  1. 在 Xcode 中打开 iOSWebBoxDemo.xcodeproj")
print("  2. 将 ../iOSWebBox/HybridSDK 目录拖入项目")
print("  3. 将 ../iOSWebBox/Resources 目录拖入项目")
print("  4. 替换 AppDelegate.swift 和 SceneDelegate.swift")
print("  5. 添加 HybridViewController.swift")
print("  6. 配置 Info.plist 权限")
print("  7. 运行项目！")
print()
PYTHON_SCRIPT

chmod +x "create_project.py"

echo "✅ 创建了项目生成脚本"
echo ""
echo "现在运行以下命令之一："
echo ""
echo "  方法 1（推荐）:"
echo "    pip3 install xcodeproj"
echo "    cd $DEST_DIR"
echo "    python3 create_project.py"
echo ""
echo "  方法 2（手动）:"
echo "    按照 MANUAL_SETUP.md 的说明手动创建项目"
echo ""
echo "  方法 3（最快）:"
echo "    直接打开 Xcode 并创建新项目"
echo ""

# 创建一个 README
cat > "README.md" << 'EOF'
# iOSWebBoxDemo

这是一个 iOSWebBox 框架的示例项目。

## 快速开始

### 方法 1：自动创建（需要 Python）

```bash
# 安装依赖
pip3 install xcodeproj

# 创建 Xcode 项目
python3 create_project.py

# 在 Xcode 中打开
open iOSWebBoxDemo.xcodeproj
```

### 方法 2：手动创建

1. 打开 Xcode
2. File → New → Project → iOS App
3. 按照 `../MANUAL_SETUP.md` 的说明配置

### 方法 3：使用现有项目

如果已经有 Xcode 项目：

1. 将 `../iOSWebBox/HybridSDK` 拖入项目
2. 将 `../iOSWebBox/Resources` 拖入项目
3. 添加 Alamofire 依赖（Swift Package Manager）
4. 配置 Info.plist
5. 运行

## 项目配置

- **最低版本**: iOS 14.0
- **语言**: Swift 5.0+
- **依赖**: Alamofire 5.8.0+

## 权限

在 Info.plist 中添加：

```xml
<key>NSCameraUsageDescription</key>
<string>需要相机权限拍照</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问相册选择照片</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存照片到相册</string>
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限录制视频</string>
```

## 测试

运行应用后，你会看到一个包含以下功能的 Demo：

- 📱 设备信息
- 📷 相机拍照
- 🖼️ 相册选择
- 🎥 视频录制
- 🌐 网络请求

在真机上可以测试所有功能，模拟器上部分功能受限。

## 问题

参见 `../MANUAL_SETUP.md` 获取详细的故障排除指南。
EOF

echo "✅ 完成！项目目录: $DEST_DIR"
echo ""
echo "开始之前，请确保："
echo "  - 已安装 Xcode 14.0+"
echo "  - 已安装 iOS 14.0+ 模拟器"
echo "  - （可选）已安装 Python 3 和 pip3"
