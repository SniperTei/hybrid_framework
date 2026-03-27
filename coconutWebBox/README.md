# 🥥 CoconutWebBox - Coconut SDK H5 测试项目

Coconut SDK 的 H5/Web 测试项目，用于测试与 Android 原生代码的交互。

## 🚀 快速开始

### 1. 启动开发服务器

```bash
# 进入项目目录
cd coconutWebBox

# 安装依赖（首次运行）
npm install

# 启动开发服务器
npm run dev
```

服务器会启动在 `http://localhost:5173`

### 2. 在 Android 项目中加载

#### 方式 A: 加载开发服务器（推荐用于开发调试）

1. **确保手机和电脑在同一网络**

2. **获取电脑 IP 地址**
   ```bash
   # macOS/Linux
   ifconfig | grep "inet "

   # Windows
   ipconfig
   ```

3. **修改 Android 项目**
   打开 `app/src/main/java/com/sniper/androidwebbox/CoconutWebActivity.kt`：
   ```kotlin
   private fun loadTestPage() {
       // 替换为你的电脑 IP
       webView.loadUrl("http://192.168.1.100:5173")
       Logger.d("CoconutWebActivity", "Loading test page from dev server")
   }
   ```

4. **重新编译运行 Android 项目**

#### 方式 B: 打包后部署（生产环境）

1. **构建生产版本**
   ```bash
   npm run build
   ```

2. **将 dist 目录复制到 Android 项目**
   ```bash
   cp -r dist/* AndroidWebBox/app/src/main/assets/coconut-web/
   ```

3. **修改 Android 项目加载路径**
   ```kotlin
   webView.loadUrl("file:///android_asset/coconut-web/index.html")
   ```

## 📱 功能测试

页面提供以下测试功能：

### 1. 获取设备信息
调用 Android 原生设备组件，获取设备型号、版本等信息。

### 2. 网络请求测试
发起网络请求，测试网络组件功能。

### 3. 存储数据测试
测试数据存储功能，包括写入和读取。

### 4. 异步调用示例
演示使用 async/await 调用原生方法。

### 5. 测试所有功能
一键测试所有功能，查看完整结果。

## 🔧 开发说明

### 项目结构

```
coconutWebBox/
├── public/
│   └── coconut.js          # Coconut SDK (JavaScript 客户端)
├── src/
│   ├── components/
│   │   └── Demo.vue        # 测试页面组件
│   ├── App.vue             # 根组件
│   └── main.js             # 入口文件
├── index.html              # HTML 模板
├── vite.config.js          # Vite 配置
└── package.json            # 项目配置
```

### Coconut SDK 使用

```javascript
// 初始化 SDK
Coconut.init({ debug: true })

// 调用原生方法（回调方式）
Coconut.call('device.getInfo', {}, function(response, isError) {
    if (isError) {
        console.error('调用失败:', response.error)
    } else {
        console.log('调用成功:', response.result)
    }
})

// 调用原生方法（Promise 方式）
const response = await Coconut.callAsync('device.getInfo')

// 快捷方法
Coconut.device.getInfo(callback)
Coconut.network.get(url, callback)
Coconut.storage.setItem(key, value, callback)
```

## 🌐 网络配置

### Vite 开发服务器配置

已在 `vite.config.js` 中配置允许外部访问：

```javascript
server: {
    host: '0.0.0.0', // 允许外部访问
    port: 5173,
    strictPort: true,
}
```

### Android 网络权限

确保 `AndroidManifest.xml` 中有网络权限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### Android 网络安全配置

如果是 HTTP（非 HTTPS），需要配置网络安全：

**方法 1: AndroidManifest.xml**
```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

**方法 2: network_security_config.xml**
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">192.168.1.100</domain>
    </domain-config>
</network-security-config>
```

## 🐛 调试技巧

### 1. Chrome DevTools 调试

在 `CoconutWebActivity` 中启用 WebView 调试：

```kotlin
// 在 Application 或 Activity 中
WebView.setWebContentsDebuggingEnabled(true)
```

然后在 Chrome 浏览器中访问 `chrome://inspect`

### 2. 查看日志

```bash
# Android 日志
adb logcat | grep Coconut

# 查看所有日志
adb logcat
```

### 3. 常见问题

**Q: 无法加载页面？**
- 检查手机和电脑是否在同一网络
- 检查 IP 地址是否正确
- 检查防火墙设置
- 确认 Vite 开发服务器正在运行

**Q: 调用原生方法失败？**
- 确认 Coconut SDK 已正确初始化
- 检查 Android 端组件是否已注册
- 查看日志确认错误原因

**Q: 页面显示环境为 web？**
- 说明没有在 Android WebView 中加载
- 检查是否正确配置了 URL

## 📚 相关文档

- [Coconut SDK Android 集成指南](../AndroidWebBox/INTEGRATION_GUIDE.md)
- [CoconutWebActivity 使用指南](../AndroidWebBox/COCONUT_WEB_ACTIVITY_GUIDE.md)
- [Coconut SDK API 文档](../AndroidWebBox/API.md)

## 🎯 下一步

- [ ] 添加更多组件测试（Camera、Gallery 等）
- [ ] 添加事件监听测试
- [ ] 添加性能测试
- [ ] 添加错误处理测试

---

**🥥 开始测试 Coconut SDK 与 Android 的交互吧！**
