# coconut-network

独立 HTTP 引擎（v1.1.0，纯 Kotlin JVM 库——**零 Android 依赖**，任何 Kotlin/JVM 项目可复用；可 maven 发布独立于 CoconutSDK 演进）。**native-first**：主要消费者是 native（如热更新 `OfflineResourceManager`）；`NetworkComponent` 只是 H5 需要时的薄透传。与 Harmony `@coconut/network` / iOS `CoconutNetwork` 引擎 API 对齐。OkHttp 式分层：

```
HttpClient（Call 工厂 + HttpConfig）
  └── Call（拦截器链 + 重试 + header 合并 + URL 构建 + UrlGuard）
        ├── adapter/（可插拔传输）
        │     ├── HttpURLConnectionAdapter   默认
        │     ├── OkHttpAdapter              okhttp 为 compileOnly，宿主想用自己加依赖
        │     ├── setDefaultAdapter()        全局默认 adapter，启动时设一次
        │     └── IHttpAdapter               接口，第三方栈实现即可接入
        ├── interceptors/
        │     ├── LogInterceptor             请求/响应日志（敏感 header/params 脱敏）
        │     └── MockInterceptor            规则命中即短路，不落 adapter
        └── guard/UrlGuard                   SSRF 出站守卫（scheme 白名单 + allowedDomains 后缀匹配）
```

依赖：kotlinx-coroutines + kotlinx-serialization-json（`api`）；okhttp `compileOnly`（可选 adapter，不强传导）。

## 纯 Kotlin/JVM 项目使用

```kotlin
// build.gradle.kts
implementation(project(":coconut-network"))
// 或独立项目：implementation("com.sniper.coconut:coconut-network:1.1.0")
```

```kotlin
import com.sniper.coconut.network.*

val config = HttpConfig().apply {
    baseUrl = "https://api.example.com"
    allowedDomains = listOf("example.com")  // 空 = 放行所有；后缀匹配（api.example.com 命中，example.com.evil.com 不命中）
    retryCount = 2
}

val client = HttpClient(config)

// 一发式 API（v1.1.0，native 消费者主入口）——内部走完整管线
// （拦截器 / UrlGuard / 重试 / header 合并 / mock 短路全链路生效）
val resp = client.get("/user/profile", RequestOptions(params = mapOf("id" to "1")))
// 等价 builder 两步式：
// val resp = client.newRequest("/user/profile", RequestOptions(params = mapOf("id" to "1"))).buildCall().execute()

if (resp.isSuccess()) {   // httpStatus 2xx 且 envelope code === "000000"
    println(resp.data)
}
```

### 一发式 API 一览（v1.1.0）

| 方法 | 说明 |
|---|---|
| `request(url, options?)` | method 由 `options.method` 指定，缺省 GET |
| `get(url, options?)` | GET |
| `post(url, body?, options?)` | POST；显式 body 优先于 `options.body` |
| `put(url, body?, options?)` | PUT；同上 |
| `delete(url, options?)` | DELETE |

### bytes 模式（二进制下载，v1.1.0）

```kotlin
val resp = client.get("/pkg/demo/index.html",
    RequestOptions(responseType = HttpResponseType.BYTES))
if (resp.isSuccess() && resp.rawData != null) {
    // rawData: ByteArray，字节级原始响应，不做 envelope 解析
}
```

- 传输层按原始字节读取，`HttpResponse.rawData` 携带原始字节，`data` 恒 null
- **不做 envelope 嗅探**：bytes 内容恰为 `{"code":...}` 形状也不进 envelope 解析
- HTTP ≥400 走原错误路径（`code="404"` 等）
- 双 adapter（HttpURLConnection / OkHttp）均支持

## envelope 语义

- body 是 JSON object 且含 `code` 字段 → 按 envelope 解析（`API_SUCCESS_CODE = "000000"`）
- 非 envelope 的 2xx JSON（如静态 manifest.json）→ `data` 直通 + 补 `code:"000000"`
- HTTP ≥400 或业务失败 → 不抛错，`isSuccess()` false，细节看 `code` / `msg` / `httpStatus`

## mock（单测 / 无网演示）

```kotlin
val mock = MockInterceptor()
mock.addRule(MockRule(url = "https://api.example.com/user/*", data = buildJsonObject { put("id", 1) }))
client.addInterceptor(mock)   // 命中即短路，请求不落 adapter，也不走 UrlGuard
```

- url 精确匹配；以 `'*'` 结尾 = 前缀匹配；`method` null = 任意方法；`delayMs` 模拟慢网络

## 与 Hybrid 框架结合

- **native 消费者**：coconut-core 的热更新 `OfflineResourceManager`（`api(project(":coconut-network"))` 依赖）
  经 `useClient()` 注入或默认实例走本引擎下载 manifest / 离线包文件（bytes 模式），自动获得
  重试 / UrlGuard / 超时管线。
- **H5 桥接**：App 层的 `NetworkComponent`（见 `app/src/main/java/com/sniper/androidwebbox/components/NetworkComponent.kt`）
  把本引擎桥接到 H5 bridge：H5 `coconut.call('network', 'request', {url, method, headers, params, body, timeoutMs})`。
  契约见仓库根 `API_CONTRACT.md` §4.5。

## 测试

65 个 JVM 单测（UrlGuard / HttpError / HttpRequest / Call / MockInterceptor / HttpClient /
HttpURLConnectionAdapter 集成（JDK HttpServer 真网络路径）/ OkHttp 冒烟），位于
`src/test/kotlin/com/sniper/coconut/network/`：

```bash
./gradlew :coconut-network:test
```

## 已知限制

- method 白名单 GET/POST/PUT/DELETE（刻意取舍）
- JSON 模式按 JSON 解析，非 JSON body 报 NETWORK_ERROR（需要原始字节的场景用 bytes 模式）
- **mock 短路不感知 responseType**：bytes 请求命中 mock 时返回 object `data`、`rawData=null`（mock 不出网无原始字节）
- upload / download 进度 / 流式不在 v1.1.0 范围
