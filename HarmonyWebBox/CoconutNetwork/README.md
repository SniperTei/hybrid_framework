# @coconut/network

独立 HTTP 引擎 HAR（v1.0.0），**零依赖、可脱离 CoconutSDK 单独使用**。OkHttp 式分层：

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
const resp = await client.newRequest('/user/profile', { method: 'GET', params: { id: 1 } })
  .buildCall()
  .execute();

if (resp.isSuccess()) {   // httpStatus 2xx 且 envelope code === '000000'
  console.info(JSON.stringify(resp.data));
}
```

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

App 层的 `NetworkComponent`（见 `entry/src/main/ets/components/NetworkComponent.ets`）把本引擎桥接到 H5 bridge：
H5 `coconut.call('network', 'request', {url, method, headers, params, body, timeoutMs})`。
契约见仓库根 `API_CONTRACT.md` §4.5。

## 测试

47 个 Hypium 测试（UrlGuard / HttpError / HttpRequest / Call / MockInterceptor），位于
`entry/src/ohosTest/ets/test/coconut/network/`，随 `HarmonyWebBox/scripts/run-harmony-tests.sh` 一起跑。

## 已知限制

- method 白名单 GET/POST/PUT/DELETE（刻意取舍）
- 响应按 JSON 解析（`expectDataType OBJECT`），非 JSON body 报 NETWORK_ERROR
- upload / download / 流式进度不在 v1.0.0 范围
