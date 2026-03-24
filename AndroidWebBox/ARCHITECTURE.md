# AndroidWebBox 混合开发框架架构设计

## 1. 项目结构

```
AndroidWebBox/
├── hybrid-sdk/                    # 框架SDK核心（可独立发布的Library）
│   ├── core/                      # 核心模块
│   │   ├── WebContainer.kt        # 增强的WebView容器
│   │   ├── JSBridge.kt            # JSBridge核心
│   │   ├── PluginManager.kt       # 插件管理器
│   │   ├── bridge.js              # 注入到H5的JS SDK
│   │   └── HybridConfig.kt        # 配置类
│   ├── plugin/                    # 插件系统
│   │   ├── BasePlugin.kt          # 插件基类
│   │   ├── PluginContext.kt       # 插件上下文
│   │   └── plugins/               # 内置插件
│   │       ├── CameraPlugin.kt    # 拍照插件
│   │       ├── GalleryPlugin.kt   # 相册插件
│   │       ├── VideoPlugin.kt     # 录像插件
│   │       └── ...
│   └── build.gradle.kts
│
├── app/                           # 示例App/业务App
│   └── src/main/
│       ├── java/com/sniper/webbox/
│       │   ├── MainActivity.kt    # 主Activity（使用Hybrid SDK）
│       │   └── HybridApp.kt       # Application初始化
│       └── assets/                # H5资源
│           └── index.html
│
└── docs/                          # 文档
    ├── API.md                     # JS API文档
    └── PLUGIN_DEV.md              # 插件开发指南
```

## 2. 核心架构

### 2.1 三层架构

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│    (H5/前端页面 + JS Bridge SDK)     │
└─────────────────────────────────────┘
              ↕ (JSBridge通信)
┌─────────────────────────────────────┐
│      Framework Layer                │
│  (WebContainer + PluginManager)      │
└─────────────────────────────────────┘
              ↕ (插件调用)
┌─────────────────────────────────────┐
│      Native Plugin Layer            │
│  (Camera/Gallery/File/Device...)    │
└─────────────────────────────────────┘
```

### 2.2 通信流程

```
H5调用: WebBox.camera.capture(options)
      ↓
JS SDK: 生成callbackId，发送消息到Native
      ↓
Native: JSBridge接收，路由到对应Plugin
      ↓
Plugin: 执行原生功能，获取结果
      ↓
Native: 通过callbackId返回结果到H5
      ↓
H5: Promise resolve/reject
```

## 3. JS API 设计

### 3.1 Promise风格API

```javascript
// 拍照
const photo = await WebBox.camera.capture({
  quality: 80,
  max_width: 1920,
  save_to_gallery: true
})

// 选择相册
const files = await WebBox.gallery.pick({
  multiple: true,
  max_count: 9,
  media_type: 'all' // image, video, all
})

// 录像
const video = await WebBox.video.record({
  max_duration: 60,
  quality: 'high'
})
```

### 3.2 事件监听

```javascript
// 监听原生事件
WebBox.event.on('resume', () => {
  console.log('App从后台恢复')
})

WebBox.event.on('networkChange', (status) => {
  console.log('网络状态:', status)
})
```

### 3.3 完整API列表

| 模块 | API | 说明 |
|------|-----|------|
| camera | capture(options) | 拍照 |
| gallery | pick(options) | 选择图片/视频 |
| video | record(options) | 录像 |
| file | choose(options) | 选择文件 |
| device | getInfo() | 获取设备信息 |
| network | getType() | 获取网络类型 |
| location | getCurrentPosition() | 获取位置 |
| barcode | scan() | 扫描二维码 |
| share | share(options) | 分享 |
| storage | setItem/getItem | 本地存储 |
| event | on/off/emit | 事件系统 |

## 4. 插件开发规范

### 4.1 插件接口

```kotlin
interface HybridPlugin {
    fun pluginName(): String
    fun exec(action: String, params: JSONObject, callback: PluginCallback)
    fun onAttach(context: PluginContext)
    fun onDetach()
}
```

### 4.2 插件示例

```kotlin
class CameraPlugin : HybridPlugin {
    override fun pluginName() = "camera"

    override fun exec(action: String, params: JSONObject, callback: PluginCallback) {
        when (action) {
            "capture" -> capture(params, callback)
            "isAvailable" -> callback.success(mapOf("available" = true))
            else -> callback.error("Unknown action: $action")
        }
    }

    private fun capture(params: JSONObject, callback: PluginCallback) {
        // 实现拍照逻辑
    }
}
```

## 5. 技术选型

| 组件 | 选型 | 说明 |
|------|------|------|
| 语言 | Kotlin | 现代化，空安全 |
| WebView | AndroidX WebView | 官方推荐 |
| 异步 | Coroutines | 原生协程支持 |
| JSON | kotlinx.serialization | 官方JSON库 |
| 图片加载 | Coil | Kotlin优先图片库 |
| 权限 | ActivityResultContracts | 新版权限API |

## 6. 安全考虑

1. **域名白名单** - 只允许加载指定域名
2. **权限最小化** - 只申请必需权限
3. **文件沙盒** - 限制文件访问范围
4. **HTTPS强制** - 生产环境强制HTTPS
5. **JSBridge签名** - 验证调用来源

## 7. 性能优化

1. **预加载WebView** - 应用启动时预创建
2. **插件懒加载** - 按需注册插件
3. **资源缓存** - H5资源本地缓存
4. **WebView复用** - 非Activity级别管理
5. **内存优化** - 及时释放大对象引用
