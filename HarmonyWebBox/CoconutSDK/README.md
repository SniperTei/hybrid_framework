# CoconutSDK (HarmonyOS)

> HarmonyOS NEXT 端 CoconutSDK —— HAR 模块，封装 Web 组件 + JSON-RPC Bridge + 组件管理 + 安全管线。
> 最低支持 HarmonyOS NEXT API 12+（实际开发用 API 23 / HarmonyOS 6.1）。使用 ArkTS。

跨平台架构、Bridge 协议、错误码、安全机制详见仓库根 [`ARCHITECTURE.md`](../../ARCHITECTURE.md) 和 [`API_CONTRACT.md`](../../API_CONTRACT.md)。本 README 只介绍 HarmonyOS 端的结构、API、用法。

---

## 模块结构

```
CoconutSDK/                                   # HAR 模块根
├── index.ets                                 # 对外导出（public API surface）
├── build-profile.json5
├── oh-package.json5
└── src/main/
    ├── CoconutSDK.ets                        # SDK 入口（静态 initialize / configure / registerComponents）
    ├── module.json5
    └── ets/
        ├── config/
        │   ├── CoconutConfig.ets             # 配置（debugMode / environment / 开关）
        │   └── Environment.ets               # DEV / STAGING / PROD
        │
        ├── component/                        # 组件系统
        │   ├── CoconutPlugin.ets             # 组件接口
        │   ├── BaseComponent.ets             # 抽象基类（含 param helpers）
        │   ├── ComponentContext.ets          # 上下文（UIAbilityContext / Logger）
        │   ├── ComponentHost.ets             # 组件宿主
        │   ├── ComponentManager.ets          # 单例：注册、路由、生命周期
        │   └── ComponentException.ets        # 组件异常类型
        │
        ├── bridge/                           # JSON-RPC Bridge + 安全管线
        │   ├── CoconutBridgeImpl.ets         # 主类：javaScriptProxy 注册
        │   ├── BridgeSecurityValidator.ets   # 域名白名单 + 限流 + params 大小
        │   ├── BridgeTokenManager.ets        # UUID 会话令牌（util.generateRandomUUID）
        │   ├── BridgePerformance.ets         # 调用耗时统计
        │   ├── SecurityAuditLog.ets          # 安全事件审计
        │   └── model/
        │       ├── BridgeRequest.ets         # JSON-RPC 请求模型
        │       ├── BridgeResponse.ets        # 响应模型
        │       ├── ErrorCode.ets             # 错误码命名空间
        │       └── SecurityResult.ets        # 安全校验结果
        │
        ├── web/
        │   ├── CoconutWebPage.ets            # 顶层 @Component：Web + CoconutSDK 装配
        │   └── WebViewHelper.ets             # WebviewController 配置
        │
        └── utils/
            ├── Logger.ets                    # 统一日志（hilog）
            └── JsonHelper.ets                # JSON parse/stringify 工具
```

> **组件不在 HAR 内**。框架不含任何业务组件，所有组件（DeviceComponent / NetworkComponent / ...）都在宿主 App `entry/src/main/ets/components/` 下，App 决定启用哪些。

> ⚠️ **HAR 模块不能独立跑 ohosTest**（HAR 不打包成 HAP）。CoconutSDK 的测试放在 `entry/src/ohosTest/ets/test/coconut/` 下，import 用 `@coconut/sdk`。详见 [`entry` 的 ohosTest 目录](../entry/src/ohosTest/ets/test/coconut/)。

---

## 核心 API

### `CoconutSDK`（静态类）

```typescript
import { CoconutSDK } from '@coconut/sdk';
import { Environment } from '@coconut/sdk';

// 1. 初始化（在 EntryAbility.onCreate 里）
CoconutSDK.initialize(this.context);  // UIAbilityContext

// 2. 配置
CoconutSDK.configure((config) => {
  config.isDebugMode = true;
  config.environment = Environment.DEV;
  config.enableBridgeToken = true;       // 默认 true
  // config.allowedDomains = ['example.com'];
});

// 3. 注册组件（异步）
await CoconutSDK.registerComponents([
  new DeviceComponent(),
  new NetworkComponent(),
  new StorageComponent(),
  // ... 共 14 个
]);

// 4. 清理（onDestroy 时）
CoconutSDK.cleanup();
```

### `CoconutWebPage`

现成的 `@Component`：内部创建 Web、注入 coconut.js、注册 `javaScriptProxy`、加载 URL。

```typescript
import { CoconutWebPage } from '@coconut/sdk';

@Entry
@Component
struct Index {
  build() {
    Column() {
      CoconutWebPage({ url: 'https://example.com' })
    }
  }
}
```

也可以**不用这个组件**——如果你有自己的 Web 容器，直接调 `CoconutSDK.initialize` + 把 `CoconutBridgeImpl` 通过 `javaScriptProxy` 注册到自己的 WebviewController。

---

## 写一个自定义组件

```typescript
import { BaseComponent, BridgeResponse, ComponentException } from '@coconut/sdk';
import { BridgeResponse as R } from '@coconut/sdk';

export class EchoComponent extends BaseComponent {
  name: string = 'echo';
  version: string = '1.0.0';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'ping': {
        // getParam / getIntParam / getBoolParam 是 BaseComponent 的 helper
        const msg = this.getParam(paramsJson, 'message', 'pong');
        return JSON.stringify({ echo: msg });
      }
      default:
        throw new ComponentException(...);  // 必须是 Error 子类
    }
  }
}
```

注册到 `CoconutSDK.registerComponents([..., new EchoComponent()])` 之后，H5 就能调用：
```js
const r = await CoconutBridge.call('echo.ping', { message: 'hi' });
// r.result === { echo: 'hi' }
```

---

## Bridge 模式（Harmony 异步）

Harmony Web 的 `javaScriptProxy` 是**异步**的（返回 Promise），通过 `runJavaScript` 回写：

```
H5: window.CoconutHarmonyBridge.call(jsonRpcRequest)  // 返回 Promise
   ↓
javaScriptProxy 拦截 → CoconutBridgeImpl.call(request)
   ↓
3 层安全校验 → ComponentManager 路由 → 组件 handle
   ↓
webview.runJavaScript(`window.__coconutHarmonyCallback(${json})`)
   ↓
H5: Promise resolve
```

---

## 测试

```bash
cd HarmonyWebBox
./scripts/run-harmony-tests.sh
# 112 个 case / 13 suites，~7s on device
```

测试覆盖：Bridge 模型 / 安全管线（Token / Security / Audit / Performance） / Component 系统 / Config / Logger / JsonHelper。

测试**必须真机/模拟器**跑（crypto/UUID/fileIo 需 HarmonyOS runtime）。一键脚本会自动 build + install + run + 写 markdown 报告到 `HarmonyWebBox/docs/hypium-report-YYYY-MM-DD.md`。

**不覆盖** `CoconutWebPage` 和 `CoconutBridgeImpl`（需要真实 Web 组件 / WebviewController，属于 UI 测试范畴）。

---

## 集成到自己的 Harmony App

HAR 模块通过 `oh-package.json5` 引用。在你的 entry 模块的 `oh-package.json5` 里加：

```json5
{
  "dependencies": {
    "@coconut/sdk": "file:../CoconutSDK"
  }
}
```

然后在 `EntryAbility.onCreate` 里按"核心 API"那一节的 4 步调用。

---

## HarmonyOS 专属注意事项

1. **`UIAbilityContext`**：必须在 EntryAbility.onCreate 里拿到并传给 `CoconutSDK.initialize`。Context 是静态缓存的（进程内稳定）。
2. **ArkTS 严格模式**：
   - 不能用 untyped object literal（`{}`），改用 `new Object()` 或显式 class
   - `throw` 必须是 `Error` 子类
   - 组件 mock 必须用 class 实现
3. **`promptAction.BaseDialogOptions` 没有 `onDidDismiss`**：dismiss 回调要在 `closeCustomDialog` 之后手动触发（详见 `entry/src/main/ets/utils/PopupUtil.ets`）。
4. **`fileIo.writeSync` 拒收 `Uint8Array`**，要传 `bytes.buffer`（ArrayBuffer）。`fileIo.accessSync` 在 HarmonyOS 6.1 不抛错，判存在用 `statSync`。
