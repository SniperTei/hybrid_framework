# Coconut SDK 集成指南（HarmonyOS NEXT）

> 面向要在**自己的 HarmonyOS App** 里接入 CoconutSDK 的开发者。框架内部结构见 [`CoconutSDK/README.md`](./CoconutSDK/README.md)，三端 API 契约见仓库根 [`API_CONTRACT.md`](../API_CONTRACT.md)（唯一权威）。
>
> 参考实现：`HarmonyWebBox/entry/`（宿主 demo，持有 6 个组件 + 模板容器 + 热更新入口）。最低 HarmonyOS NEXT API 12+。

---

## 1. 集成 CoconutSDK（HAR）

在你的 entry 模块 `oh-package.json5` 里加本地 HAR 依赖（网络组件还需引擎包 `@coconut/network`）：

```json5
{
  "dependencies": {
    "@coconut/sdk": "file:../CoconutSDK",
    "@coconut/network": "file:../CoconutNetwork"
  }
}
```

> **组件不在 HAR 内**。框架只含 Bridge / ComponentManager / 安全管线 / Web 装配，所有组件（DeviceComponent / ...）都在宿主 App（见 `entry/src/main/ets/components/`），由 App 显式注册决定启用哪些。

## 2. 初始化（EntryAbility）

```typescript
import { CoconutSDK } from '@coconut/sdk';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    CoconutSDK.initialize(this.context);          // 必须 UIAbilityContext
    CoconutSDK.configure((config) => {
      config.isDebugMode = true;
      config.enableBridgeToken = true;            // 3 层安全均可独立开关
      // config.allowedDomains = ['example.com']  // 域名白名单；空 = 放行所有（生产建议收紧）
    });
  }

  onDestroy(): void {
    CoconutSDK.cleanup();
  }
}
```

## 3. 注册组件 + 打开容器

组件注册在页面生命周期里（demo 的 `Index.ets` 在 `aboutToAppear`）：

```typescript
import { CoconutSDK } from '@coconut/sdk';

aboutToAppear(): void {
  CoconutSDK.registerComponents([
    new DeviceComponent(),
    new StorageComponent(),
    new EventComponent(),
    new DialogComponent(),
    new NetworkComponent(),
    new NavigatorComponent()
    // + 业务组件按需
  ]);
}
```

### 现成容器：`CoconutWebPage`（组件）

```typescript
import { CoconutWebPage } from '@coconut/sdk';

build() {
  Column() {
    CoconutWebPage({ url: 'https://example.com' })   // 或 coconut://demo/index.html（离线包）
  }
}
```

### 标准路由页：`pages/WebContainer`（v3.5.0）

组合 `CoconutWebPage` + `CoconutWebDelegate` 行为钩子的路由页，支持 header 覆盖：

```typescript
router.pushUrl({
  url: 'pages/WebContainer',
  params: { 'url': 'https://example.com', 'header': '{"title":"订单详情","closePolicy":"always"}' }
});
```

自带：自绘导航栏（NavConfig 三级合并）、白屏错误弹窗、多容器 resume-claim。**返回语义一条路**：导航栏返回 = `canGoBack ? goBack : router.back`。

### 定制行为：继承 `CoconutWebDelegate`

Harmony 无真继承 `@Component` 的正路，模板/定制走**组合**——自定义 delegate 覆写行为钩子（`onBack` 拦截 / `onLoadFail` / `onTitleChange`），传给 `CoconutWebPage`。

### 完全自定义容器

有自己的 Web 容器也行：`CoconutSDK.initialize` + 把 `CoconutBridgeImpl` 通过 `javaScriptProxy` 注册到自己的 WebviewController，注入 `coconut.js` 即可。注意 Harmony 的 `javaScriptProxy` 是**异步**的（返回 Promise，经 `runJavaScript` 回写）。

## 4. 模板容器（业务定制页）

新建路由页组合 `CoconutWebPage` + 自定义 delegate（参考 `entry/src/main/ets/pages/DemoTemplatePage.ets`），注册到 `entry/src/main/resources/rawfile/coconut_templates.json`：

```json
[ { "templateName": "demo", "templatePage": "pages/DemoTemplatePage" } ]
```

⚠️ **宿主契约**：模板页必须同时注册进 `main_pages.json`，否则 `pushUrl` 时崩（TemplateRegistry 只做浅校验，这是文档化的宿主责任）。启动期建议跑 `TemplateRegistry.load(context)` eager 校验（demo Index.ets 有示范）。

H5 侧 `coconut.navigator.forward({ url, template: 'demo' })` 即命中。

## 5. 写一个自定义组件

```typescript
import { BaseComponent, BridgeResponse, ComponentException } from '@coconut/sdk';

export class EchoComponent extends BaseComponent {
  name: string = 'echo';
  version: string = '1.0.0';
  methods: string[] = ['ping'];   // 必须与 handle() 的 switch 一致（capability 检测用）

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'ping': {
        const msg = this.getParam(paramsJson, 'message', 'pong');  // BaseComponent helper
        return JSON.stringify({ echo: msg });
      }
      default:
        throw new ComponentException(...);   // ArkTS：throw 必须是 Error 子类
    }
  }
}
```

注册后 H5 调用：

```js
coconut.call('echo', 'ping', { message: 'hi' }, (err, data) => {
    if (err) { console.error(err.code, err.message); return; }
    console.log(data);   // { echo: 'hi' }
});
```

## 6. 离线包 / 热更新 / Network

- **离线包**：`coconut://<moduleId>/<path>`，rawfile + 沙箱覆盖本地服务（`CoconutOfflineResources`，`onInterceptRequest`），不依赖 dev server。vite 产物必须 **iife + classic script**（ES module 在自定义 scheme 的 null origin 必被 CORS 拦）
- **热更新**：`CoconutUpdateManager.checkUpdate / performUpdate / rollback`，下载走 `@coconut/network` 引擎。manifest URL 用 `127.0.0.1` 时需先建反向转发（模拟器不共享 Mac loopback）：
  `hdc rport tcp:8000 tcp:8000`（设备 localhost:8000 → Mac:8000），或改 Mac 局域网 IP 直连
- **Network**：`NetworkComponent` 桥接引擎，H5 `coconut.call('network', 'request' | 'getNetworkType', ...)`；native 侧可直接用引擎一发式 API（`client.get/post/...`，参考 `SniperYoloAPIPage.ets`）

## 7. 测试与验证

```bash
cd HarmonyWebBox
./scripts/run-harmony-tests.sh    # 280 case，真机/模拟器 on-device（crypto/UUID 需 HarmonyOS runtime）
```

⚠️ 脚本 build 管道会吞编译错误然后**装旧 HAP 跑旧测试**——加新测试后先手动
`hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap`
确认 BUILD SUCCESSFUL 再跑脚本。

## 8. HarmonyOS 踩坑速查（真金换来的）

| 坑 | 正解 |
|----|------|
| HAR 想独立跑 ohosTest | 不行（HAR 不打包 HAP），测试放 entry 的 `ohosTest`，import `@coconut/sdk` |
| ArkTS `await obj.init({})` 报 no-untyped-obj-literals | 用 `new Object()` / 显式 class；mock 用 class 不用 object literal |
| `fileIo.writeSync(fd, uint8Arr)` | 拒收 Uint8Array，传 `bytes.buffer`（ArrayBuffer） |
| `fileIo.accessSync(path)` 判存在 | 不抛错（文档骗人），用 `statSync` |
| `fileIo.mkdirSync(path, true)` 目标已存在 | 照样抛 "File exists"，建目录必须 try/catch 守卫 |
| `promptAction.BaseDialogOptions.onDidDismiss` | 实际不存在（只有 onDidAppear），dismiss 回调手动触发 |
| `cryptoFramework.createMd('MD5')` 模拟器失败 | HUKS 层问题，已内置纯 JS MD5 兜底（单代码路径覆盖模拟器+真机） |
| `UIAbility.windowStage` | 非 public，拿 UIContext 走 `window.getLastWindow(context)` |
| 网络状态 pull API 抛 201 | `hasDefaultNet` 等需 GET_NETWORK_INFO ACL；用 NetConnection 事件流（NetworkComponent 已内置） |

组件/方法签名以 [`API_CONTRACT.md`](../API_CONTRACT.md) 为准；H5 侧可用 `coconut.supports(component, fn)` 探测宿主能力。
