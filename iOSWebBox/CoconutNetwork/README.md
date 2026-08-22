# CoconutNetwork

独立 HTTP 引擎 SPM 包（v1.1.0，**纯 Foundation 零依赖**，可脱离 CoconutSDK 单独给 Swift 项目用）。**native-first**：主要消费者是 native（如热更新 `CoconutUpdateManager`）；`NetworkComponent` 只是 H5 需要时的薄透传。与 Harmony `@coconut/network` / Android `coconut-network` 引擎 API 对齐。OkHttp 式分层：

```
HttpClient（Call 工厂 + HttpConfig）
  └── Call（拦截器链 + 重试 + header 合并 + URL 构建 + UrlGuard）
        ├── adapter/（可插拔传输）
        │     ├── URLSessionAdapter    默认（错误按 URLError.code 分类）
        │     └── IHttpAdapter         协议，第三方栈实现即可接入
        ├── interceptors/
        │     ├── LogInterceptor       请求/响应日志（敏感 header/params 脱敏）
        │     └── MockInterceptor      规则命中即短路，不落 adapter
        ├── guard/UrlGuard             SSRF 出站守卫（scheme 白名单 + allowedDomains 后缀匹配）
        └── JSONValue                  自包含 JSON 值树（替代 JsonElement，任意服务端 payload 无损直通）
```

平台声明 `.iOS(.v15)` + `.macOS(.v13)` → **`swift test` 宿主机直跑**（秒级，无需模拟器）。

## 纯 Swift 项目使用

```swift
// Package.swift
.package(path: "../CoconutNetwork")
// target: .product(name: "CoconutNetwork", package: "CoconutNetwork")
```

```swift
import CoconutNetwork

let config = HttpConfig()
config.baseUrl = "https://api.example.com"
config.allowedDomains = ["example.com"]   // 空 = 放行所有；后缀匹配（api.example.com 命中，example.com.evil.com 不命中）
config.retryCount = 2

let client = HttpClient(config)   // adapter 缺省 URLSessionAdapter

// 一发式 API（v1.1.0，native 消费者主入口）——内部走完整管线
// （拦截器 / UrlGuard / 重试 / header 合并 / mock 短路全链路生效）
let resp = await client.get("/user/profile", options: RequestOptions(params: ["id": "1"]))
// 等价 builder 两步式：
// let resp = await client.execute(client.newRequest("/user/profile", RequestOptions(params: ["id": "1"])))

if resp.isSuccess() {   // httpStatus 2xx 且 envelope code === "000000"
    print(resp.data ?? "nil")
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

```swift
let resp = await client.get("/pkg/demo/index.html",
    options: RequestOptions(responseType: .bytes))
if resp.isSuccess(), resp.rawData != nil {
    // rawData: Data，字节级原始响应，不做 envelope 解析
}
```

- `HttpResponse.rawData` 携带原始字节，`data` 恒 null
- **不做 envelope 嗅探**：bytes 内容恰为 `{"code":...}` 形状也不进 envelope 解析
- HTTP ≥400 走原错误路径（`code="404"` 等）
- `HttpConfig` 是**引用语义 class**——运行期改 `allowedDomains` / `baseUrl` 即时生效（NetworkComponent 靠这个做 per-request 白名单同步）

### 超时差异（与两平台不同）

URLRequest 只有单一 `timeoutInterval`（闲置计时器），无独立的 connect/read 概念——`URLSessionAdapter`
取 `readTimeout` 赋值，`connectTimeout` 交给 URLSession 默认配置。需要细粒度控制的场景自行实现 `IHttpAdapter`。

## envelope 语义

- body 是 JSON object 且含 `code` 字段 → 按 envelope 解析（`API_SUCCESS_CODE = "000000"`）
- 非 envelope 的 2xx JSON（如静态 manifest.json）→ `data` 直通 + 补 `code:"000000"`
- HTTP ≥400 或业务失败 → 不抛错（公开 API 永不 throw），`isSuccess()` false，细节看 `code` / `msg` / `httpStatus`

## mock（单测 / 无网演示）

```swift
let mock = MockInterceptor()
mock.addRule(MockRule(url: "https://api.example.com/user/*",
                      data: .object(["id": .number(1)])))
client.addInterceptor(mock)   // 命中即短路，请求不落 adapter，也不走 UrlGuard
```

- url 精确匹配；以 `'*'` 结尾 = 前缀匹配；`method` nil = 任意方法；`delayMs` 模拟慢网络

## 与 Hybrid 框架结合

- **native 消费者**：CoconutSDK 的热更新 `CoconutUpdateManager`（包依赖 CoconutNetwork）
  经 `useClient()` 注入或 lazy 默认实例走本引擎下载 manifest / 离线包文件（bytes 模式），自动获得
  重试 / UrlGuard / 超时管线。
- **H5 桥接**：App 层的 `NetworkComponent`（见 `iOSWebBox/iOSWebBox/Components/NetworkComponent.swift`）
  把本引擎桥接到 H5 bridge：H5 `coconut.call('network', 'request', {url, method, headers, params, body, timeoutMs})`。
  契约见仓库根 `API_CONTRACT.md` §4.5。

## 测试

64 个 XCTest（UrlGuard / HttpError / HttpRequest / Call / MockInterceptor / HttpClient /
URLSessionAdapter 集成（MockURLProtocol stub：状态行解析 / 404 映射 / bytes 直通 / 超时分类）），
位于 `Tests/CoconutNetworkTests/`：

```bash
swift test   # 宿主机直跑，秒级
```

## 已知限制

- method 白名单 GET/POST/PUT/DELETE（刻意取舍）
- JSON 模式按 JSON 解析，非 JSON body 报 NETWORK_ERROR（需要原始字节的场景用 bytes 模式）
- **mock 短路不感知 responseType**：bytes 请求命中 mock 时返回 object `data`、`rawData=nil`（mock 不出网无原始字节）
- upload / download 进度 / 流式不在 v1.1.0 范围
