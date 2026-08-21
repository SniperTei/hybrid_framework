# @coconut/network

独立 HTTP 引擎 HAR（v1.1.0），**native-first**（主要消费者是 native——如热更新 CoconutUpdateManager；NetworkComponent 只是 H5 需要时的薄透传）。零依赖、可脱离 CoconutSDK 单独使用。OkHttp 式分层：

```
HttpClient（Call 工厂 + HttpConfig）
  └── Call（拦截器链 + 重试 + header 合并 + URL 构建 + UrlGuard）
        ├── adapter/（可插拔传输）
        │     ├── HarmonyHttpAdapter   默认，@kit.NetworkKit
        │     ├── IHttpAdapter         接口，第三方栈（如 RCP）实现即可接入
        │     └── FakeAdapter          测试用（在 entry ohosTest 里）
        ├── interceptors/
        │     ├── LogInterceptor       请求/响应日志（敏感 header 脱敏）
        │     └── MockInterceptor      规则命中即短路，不落 adapter
        └── guard/UrlGuard             SSRF 出站守卫（scheme 白名单 + allowedDomains 后缀匹配）
```

## 纯 native 项目使用

```json5
// oh-package.json5
"dependencies": { "@coconut/network": "file:../CoconutNetwork" }
```

```ts
import { HttpClient, HttpConfig, HarmonyHttpAdapter } from '@coconut/network';

const config = new HttpConfig();
config.baseUrl = 'https://api.example.com';
config.allowedDomains = ['example.com'];   // 空 = 放行所有；后缀匹配（api.example.com 命中，example.com.evil.com 不命中）
config.retryCount = 2;

const client = new HttpClient(config, new HarmonyHttpAdapter());

// 一发式 API（v1.1.0，native 消费者主入口）——内部走完整管线
// （拦截器 / UrlGuard / 重试 / header 合并 / mock 短路全链路生效）
const resp = await client.get('/user/profile', { params: { id: 1 } });
// 等价 builder 两步式：
// const resp = await client.newRequest('/user/profile', { params: { id: 1 } }).buildCall().execute();

if (resp.isSuccess()) {   // httpStatus 2xx 且 envelope code === '000000'
  console.info(JSON.stringify(resp.data));
}
```

### 一发式 API 一览（v1.1.0）

| 方法 | 说明 |
|---|---|
| `request<T>(url, options?)` | method 由 `options.method` 指定，缺省 GET |
| `get<T>(url, options?)` | GET |
| `post<T>(url, body?, options?)` | POST；显式 body 优先于 `options.body` |
| `put<T>(url, body?, options?)` | PUT；同上 |
| `delete<T>(url, options?)` | DELETE |

### bytes 模式（二进制下载，v1.1.0）

```ts
import { HttpResponseType } from '@coconut/network';

const resp = await client.get('/pkg/demo/index.html', { responseType: HttpResponseType.BYTES });
if (resp.isSuccess() && resp.rawData !== null) {
  // rawData: ArrayBuffer，字节级原始响应，不做 envelope 解析
}
```

- 传输层走 `expectDataType: ARRAY_BUFFER`，`HttpResponse.rawData` 携带原始字节，`data` 恒 null
- **不做 envelope 嗅探**：bytes 内容恰为 `{"code":...}` 形状也不进 envelope 解析
- HTTP ≥400 走原错误路径（`code='404'` 等）

## envelope 语义

- body 是 JSON object 且含 `code` 字段 → 按 envelope 解析（`API_SUCCESS_CODE = '000000'`）
- 非 envelope 的 2xx JSON（如静态 manifest.json）→ `data` 直通 + 补 `code:'000000'`
- HTTP ≥400 或业务失败 → 不抛错，`isSuccess()` false，细节看 `code` / `msg` / `httpStatus`

## mock（单测 / 无网演示）

```ts
import { MockInterceptor } from '@coconut/network';

const mock = new MockInterceptor();
mock.addRule({ url: 'https://api.example.com/user/*', code: '000000', data: { id: 1 } });
client.addInterceptor(mock);   // 命中即短路，请求不落 adapter，也不走 UrlGuard
```

## 与 Hybrid 框架结合

- **native 消费者**：CoconutSDK 的热更新 `CoconutUpdateManager`（`file:../CoconutNetwork` 依赖，v3.3.0+）
  经 `useClient()` 注入或 lazy 默认实例走本引擎下载 manifest / 离线包文件（bytes 模式），自动获得
  重试 / UrlGuard / 超时管线。
- **H5 桥接**：App 层的 `NetworkComponent`（见 `entry/src/main/ets/components/NetworkComponent.ets`）
  把本引擎桥接到 H5 bridge：H5 `coconut.call('network', 'request', {url, method, headers, params, body, timeoutMs})`。
  契约见仓库根 `API_CONTRACT.md` §4.5。

## 测试

57 个 Hypium 测试（UrlGuard / HttpError / HttpRequest / Call / MockInterceptor / HttpClient），位于
`entry/src/ohosTest/ets/test/coconut/network/`，随 `HarmonyWebBox/scripts/run-harmony-tests.sh` 一起跑。

## 已知限制

- method 白名单 GET/POST/PUT/DELETE（刻意取舍）
- JSON 模式按 JSON 解析（`expectDataType OBJECT`），非 JSON body 报 NETWORK_ERROR（需要原始字节的场景用 bytes 模式）
- **mock 短路不感知 responseType**：bytes 请求命中 mock 时返回 object `data`、`rawData=null`（mock 不出网无原始字节）
- upload / download 进度 / 流式不在 v1.1.0 范围
