# Coconut.env API 文档

> ⚠️ **权威环境字段文档见 [`../API_CONTRACT.md`](../API_CONTRACT.md) Section 0.1**。本文档保留辅助说明，遇到冲突以 API_CONTRACT.md 为准。

## 📋 简介

`Coconut.env` 对象提供了丰富的运行环境信息，帮助开发者根据不同平台和环境进行适配。

## 🎯 基础属性

### 平台信息

| 属性 | 类型 | 说明 |
|------|------|------|
| `platform` | string | 平台名称：`android` / `ios` / `web` / `node` |
| `version` | string | SDK 版本号 |
| `sdkVersion` | string | SDK 版本号（别名） |

### 平台判断（布尔值）

| 属性 | 说明 |
|------|------|
| `isAndroid` | 是否是 Android 环境 |
| `isiOS` | 是否是 iOS 环境 |
| `isWeb` | 是否是 Web 浏览器环境 |
| `isNode` | 是否是 Node.js 环境 |
| `isNative` | 是否是原生环境（Android 或 iOS） |

## 🌐 浏览器环境

### 基础信息

| 属性 | 类型 | 说明 |
|------|------|------|
| `userAgent` | string | User Agent 字符串 |
| `language` | string | 浏览器语言 |
| `cookieEnabled` | boolean | 是否启用 Cookie |
| `online` | boolean | 是否在线 |
| `isWebView` | boolean | 是否在 WebView 中 |

### 浏览器类型

| 属性 | 说明 |
|------|------|
| `isChrome` | 是否 Chrome 浏览器 |
| `isSafari` | 是否 Safari 浏览器 |
| `isFirefox` | 是否 Firefox 浏览器 |
| `isEdge` | 是否 Edge 浏览器 |
| `isWeChat` | 是否微信内置浏览器 |
| `isAlipay` | 是否支付宝内置浏览器 |

## 📱 设备信息

### 操作系统

| 属性 | 说明 |
|------|------|
| `isWindows` | 是否 Windows 系统 |
| `isMac` | 是否 macOS 系统 |
| `isLinux` | 是否 Linux 系统 |
| `isMobile` | 是否移动设备 |
| `isTablet` | 是否平板设备 |
| `isDesktop` | 是否桌面设备 |

### iOS 设备类型

| 属性 | 说明 |
|------|------|
| `isIPhone` | 是否 iPhone |
| `isIPad` | 是否 iPad |
| `isIPod` | 是否 iPod touch |

### Android 信息

| 属性 | 类型 | 说明 |
|------|------|------|
| `androidVersion` | string | Android 版本号 |

## 📺 屏幕信息

| 属性 | 类型 | 说明 |
|------|------|------|
| `screenWidth` | number | 屏幕宽度（像素） |
| `screenHeight` | number | 屏幕高度（像素） |
| `viewportWidth` | number | 视口宽度（像素） |
| `viewportHeight` | number | 视口高度（像素） |
| `devicePixelRatio` | number | 设备像素比（DPR） |

## 🔧 功能支持

| 属性 | 类型 | 说明 |
|------|------|------|
| `isTouchDevice` | boolean | 是否支持触摸 |
| `localStorage` | boolean | 是否支持 localStorage |
| `sessionStorage` | boolean | 是否支持 sessionStorage |

## 💡 使用示例

### 基础使用

```javascript
// 初始化 SDK
Coconut.init({ debug: true })

// 访问环境信息
console.log(Coconut.env.platform)        // 'android' / 'ios' / 'web'
console.log(Coconut.env.isAndroid)        // true / false
console.log(Coconut.env.isiOS)            // true / false
console.log(Coconut.env.version)          // '1.0.0'
```

### 平台判断

```javascript
// 判断是否在原生环境
if (Coconut.env.isNative) {
    console.log('运行在原生环境中')
    if (Coconut.env.isAndroid) {
        console.log('Android 平台')
    } else if (Coconut.env.isiOS) {
        console.log('iOS 平台')
    }
} else {
    console.log('运行在浏览器中')
}
```

### 根据平台执行不同逻辑

```javascript
// Android 特定逻辑
if (Coconut.env.isAndroid) {
    Coconut.call('android.specialFeature', {}, callback)
}
// iOS 特定逻辑
else if (Coconut.env.isiOS) {
    Coconut.call('ios.specialFeature', {}, callback)
}
// Web 降级处理
else {
    // 使用 Web API 或显示提示
    console.log('请在原生应用中使用此功能')
}
```

### WebView 判断

```javascript
// 判断是否在 WebView 中
if (Coconut.env.isWebView) {
    console.log('运行在 WebView 中')

    // 可以安全调用原生方法
    Coconut.call('device.getInfo', {}, callback)
} else {
    console.log('运行在普通浏览器中')

    // 提示用户下载应用
    showDownloadAppPrompt()
}
```

### 微信/支付宝判断

```javascript
// 在微信中
if (Coconut.env.isWeChat) {
    console.log('微信内置浏览器')
    // 使用微信 JS-SDK
}

// 在支付宝中
if (Coconut.env.isAlipay) {
    console.log('支付宝内置浏览器')
    // 使用支付宝 JSAPI
}
```

### 响应式布局

```javascript
// 根据设备类型调整布局
if (Coconut.env.isMobile) {
    // 移动端布局
    enableMobileLayout()
} else if (Coconut.env.isTablet) {
    // 平板布局
    enableTabletLayout()
} else {
    // 桌面布局
    enableDesktopLayout()
}
```

### 屏幕适配

```javascript
// 获取屏幕信息
const width = Coconut.env.viewportWidth
const height = Coconut.env.viewportHeight
const dpr = Coconut.env.devicePixelRatio

console.log(`视口: ${width}x${height}`)
console.log(`像素比: ${dpr}`)

// 根据屏幕尺寸调整
if (width < 768) {
    // 小屏
} else {
    // 大屏
}
```

### 触摸支持

```javascript
// 判断是否支持触摸
if (Coconut.env.isTouchDevice) {
    // 启用触摸事件
    enableTouchEvents()
} else {
    // 启用鼠标事件
    enableMouseEvents()
}
```

### 存储支持

```javascript
// 检查存储支持
if (Coconut.env.localStorage) {
    // 使用 localStorage
    localStorage.setItem('key', 'value')
} else {
    // 使用其他存储方式
    Coconut.storage.setItem('key', 'value', callback)
}
```

### 完整环境信息打印

```javascript
// 打印所有环境信息
console.log('=== Coconut Environment Info ===')
console.log('Platform:', Coconut.env.platform)
console.log('SDK Version:', Coconut.env.version)
console.log('Is Native:', Coconut.env.isNative)
console.log('Is WebView:', Coconut.env.isWebView)
console.log('Is Mobile:', Coconut.env.isMobile)
console.log('Screen:', Coconut.env.screenWidth, 'x', Coconut.env.screenHeight)
console.log('Viewport:', Coconut.env.viewportWidth, 'x', Coconut.env.viewportHeight)
console.log('User Agent:', Coconut.env.userAgent)
```

### Vue 3 组合式 API

```javascript
import { ref, onMounted } from 'vue'

export default {
  setup() {
    const isNative = ref(false)
    const platform = ref('')

    onMounted(() => {
      if (window.Coconut) {
        window.Coconut.init({ debug: true })

        isNative.value = window.Coconut.env.isNative
        platform.value = window.Coconut.env.platform
      }
    })

    return { isNative, platform }
  }
}
```

### React Hooks

```javascript
import { useState, useEffect } from 'react'

function useCoconutEnv() {
  const [env, setEnv] = useState(null)

  useEffect(() => {
    if (window.Coconut) {
      window.Coconut.init({ debug: true })
      setEnv(window.Coconut.env)
    }
  }, [])

  return env
}

// 使用
function MyComponent() {
  const env = useCoconutEnv()

  if (!env) return <div>Loading...</div>

  return (
    <div>
      <p>Platform: {env.platform}</p>
      <p>Is Native: {env.isNative ? 'Yes' : 'No'}</p>
    </div>
  )
}
```

## 🎯 最佳实践

### 1. 始终检查环境

```javascript
// 好的做法
if (Coconut.env.isNative) {
    Coconut.call('native.method', {}, callback)
} else {
    // Web 降级处理
    webFallback()
}

// 不好的做法
// 直接调用，可能在浏览器中报错
Coconut.call('native.method', {}, callback)
```

### 2. 使用环境信息优化体验

```javascript
// 根据设备类型优化
if (Coconut.env.isMobile) {
    // 移动端：简化界面
    showSimpleUI()
} else {
    // 桌面端：完整功能
    showFullUI()
}
```

### 3. 渐进增强

```javascript
// 基础功能（所有环境）
loadBasicFeatures()

// 原生增强（仅原生环境）
if (Coconut.env.isNative) {
    loadNativeFeatures()
}

// 触摸优化（仅触摸设备）
if (Coconut.env.isTouchDevice) {
    enableTouchGestures()
}
```

### 4. 错误处理

```javascript
try {
    if (Coconut.env.isAndroid) {
        await Coconut.callAsync('android.feature')
    }
} catch (error) {
    console.error('功能调用失败:', error)
    // 降级到 Web 实现
    webFallback()
}
```

## 📊 环境信息示例

### Android WebView 环境

```javascript
{
    platform: "android",
    version: "1.0.0",
    sdkVersion: "1.0.0",
    isAndroid: true,
    isiOS: false,
    isWeb: false,
    isNode: false,
    isNative: true,
    isWebView: true,
    isMobile: true,
    isTablet: false,
    isDesktop: false,
    androidVersion: "11.0",
    isTouchDevice: true,
    screenWidth: 1080,
    screenHeight: 2340,
    viewportWidth: 1080,
    viewportHeight: 1793,
    devicePixelRatio: 3
}
```

### iOS WebView 环境

```javascript
{
    platform: "ios",
    version: "1.0.0",
    sdkVersion: "1.0.0",
    isAndroid: false,
    isiOS: true,
    isWeb: false,
    isNode: false,
    isNative: true,
    isWebView: true,
    isMobile: true,
    isIPhone: true,
    isTouchDevice: true,
    screenWidth: 390,
    screenHeight: 844,
    viewportWidth: 390,
    viewportHeight: 844,
    devicePixelRatio: 3
}
```

### Web 浏览器环境

```javascript
{
    platform: "web",
    version: "1.0.0",
    sdkVersion: "1.0.0",
    isAndroid: false,
    isiOS: false,
    isWeb: true,
    isNode: false,
    isNative: false,
    isWebView: false,
    isChrome: true,
    isDesktop: true,
    screenWidth: 1920,
    screenHeight: 1080,
    viewportWidth: 1920,
    viewportHeight: 947,
    devicePixelRatio: 1
}
```

---

**🥥 充分利用 Coconut.env，为不同平台提供最佳体验！**
