# Android Event Subscription 端到端测试

> 测试 `EventComponent`（native → H5 push 通道）在 Android 端的完整工作流。
> 实现细节见 `~/.claude/projects/-Users-zhengnan-Sniper-Developer-github-hybrid-framework/memory/event-subscription.md`。

---

## 测试目标

验证 4 个核心行为：

| # | 行为 | 期望结果 |
|---|---|---|
| 1 | On | native ack 回到 H5，topic 正确 |
| 2 | Echo 后 500ms 收到事件 | `window.__coconutEvent` 被调用，payload 含 `{hello:'world'}` |
| 3 | Off 后不再投递 | 再次 Echo，H5 无事件回调 |
| 4 | 页面 reload 后无 stale 投递 | reload 触发 `clearAll()`，新页面再 Echo（未订阅）无事件 |

---

## 前置准备

### 1. 设备 / 模拟器

```bash
# 真机：开 USB 调试；模拟器：直接用 Android Studio AVD
adb devices
# 期望至少一条记录
```

### 2. 构建 + 安装 app

```bash
cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework/AndroidWebBox
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

**关键信息**：
- Package: `com.sniper.androidwebbox`
- Launcher Activity: `MainActivity`（启动后会自动跳到 `CoconutWebActivity`）
- WebView debug 已在 `WebBoxApplication` 里通过 `setEnableWebViewDebug(true)` 开启（**必须开**，否则 CDP 端口看不到）

---

## 方式 A：单元测试（自动，~1.5s，推荐）

最快的反馈。覆盖 `EventEmitter` 的 10 个 case（不依赖 WebView / 设备）。

```bash
cd AndroidWebBox
./gradlew :coconut-core:testDebugUnitTest
```

**期望**：71 个测试全部通过，其中 `EventEmitterTest` 10 个：
- on + emit 投递成功
- off 后不再投递
- 同 topic 二次 on 覆盖前一次
- topic 不匹配不投递
- echo round-trip
- 无 jsExecutor 静默丢弃
- clearAll 清空
- 空 topic 拒绝
- off 未订阅的 topic 是 no-op
- JS 字符串转义正确

**注意**：
- ❌ 没有 Robolectric，`coconut-sdk` 模块（WebView 耦合代码）**不覆盖**
- ❌ `BridgeSecurityValidator` 不覆盖（依赖 `android.net.Uri.parse`）
- ✅ `testOptions.unitTests.isReturnDefaultValues = true` 已配，`android.util.Log` stub 返回默认值不抛错

---

## 方式 B：手动 UI 端到端（点按钮）

### B.1 启动 app + 监听 logcat

```bash
# 启动 app
adb shell am start -n com.sniper.androidwebbox/.MainActivity

# 实时看 CoconutSDK 日志（开另一个终端）
adb logcat -s CoconutSDK:* System.out:I Chromium:D WebConsole:I
```

> `MainActivity.onCreate` 会调 `CoconutWebActivity.start(this, url)`，自动跳到 WebView。
> coconut_index.html 加载在 `assets/`，URL 形如 `file:///android_asset/coconut_index.html` 或 dev 环境会换成 dev URL。

### B.2 验证启动日志

logcat 应输出（按顺序）：

```
WebBoxApplication  ✅ Components registered: [device, storage, event]
CoconutWebActivity Bridge setup complete
EventComponent     Event component initialized
EventEmitter       Cleared 0 subscription(s)   ← onPageStarted 钩子触发
CoconutWebActivity Page loaded: <url>
```

**关键检查点**：
- ✅ Components registered 列表里**含 event**
- ✅ Bridge setup complete（jsExecutor 已接到 `webView.evaluateJavascript`）
- ✅ `Cleared 0 subscription(s)` —— `onPageStarted` 钩子触发（首次加载清 0 是正常的）

### B.3 操作 WebView 上的按钮

页面顶部应显示蓝色徽章 `当前平台：Android`。按钮分 3 组（Device / Storage / Event）。

#### 步骤 1：点「订阅 test.echo」（紫色按钮）

期望 eventView 显示：
```json
{ "stage": "on ack", "topic": "test.echo", "resp": { "code": "000000", ... } }
```

logcat 同步出现：
```
EventEmitter On: test.echo (total=1)
```

#### 步骤 2：点「Echo（500ms 后回推）」（紫色按钮）

期望（约 500ms 后）eventView 显示：
```json
{
  "stage": "event received",
  "event": {
    "topic": "test.echo",
    "data": { "hello": "world" }
  }
}
```

logcat 同步出现：
```
EventEmitter Emitted 'test.echo'
```

#### 步骤 3：点「取消订阅」（红色按钮）

期望：
```
EventEmitter Off: test.echo (total=0)
```

eventView 显示 off ack。

#### 步骤 4：再次点「Echo」

期望：
- eventView **保持上一步状态不变**（因为 native registry 里这个 topic 已删，不会调 `__coconutEvent`）
- logcat：
  ```
  EventEmitter emit no subscriber: test.echo
  ```

#### 步骤 5（关键）：reload 页面，验证无 stale 投递

1. 在 WebView 里点 reload（模拟器 `Cmd+R` 或在 chrome://inspect 里 reload）
2. **不要**再点「订阅」按钮
3. 直接点「Echo」

期望：
```
EventEmitter Cleared 1 subscription(s)   ← reload 钩子触发清空
CoconutWebActivity Page loaded: <url>
EventEmitter emit no subscriber: test.echo   ← 因为 registry 已清空
```

如果 reload 后还能看到 `Emitted 'test.echo'`，说明 `onPageStarted` 钩子没接好 clearAll —— **这是关键的跨平台 bug**（Harmony 上踩过坑），必须修复后才能上线。

---

## 方式 C：CDP 自动化驱动（推荐，可重复跑）

Android WebView 暴露 Chrome DevTools Protocol，可通过 WebSocket 注入 JS 自动化测试。

### C.1 找到 WebView 的 CDP 端点

```bash
# 启动 app 后，找 devtools socket
adb shell cat /proc/net/unix | grep webview_devtools
# 形如：@webview_devtools_remote_12345

# 把这个 socket 转发到本地 9222 端口
adb forward tcp:9222 localabstract:webview_devtools_remote_12345

# 拿 webSocketDebuggerUrl
curl -s http://localhost:9222/json | python3 -m json.tool | grep webSocketDebuggerUrl
```

或者直接 `adb forward tcp:9222 localabstract:webview_devtools_remote_<PID>`（PID 通过 `adb shell pidof com.sniper.androidwebbox` 拿）。

> 推荐用 Chromium 的 [chrome://inspect](chrome://inspect) 排查 —— 桌面 Chrome 浏览器打开后应能看到「WebView in com.sniper.androidwebbox」，点 inspect 即可。

### C.2 跑测试脚本

依赖：`npm i -g ws`（或复用项目里已有的 `ws` 依赖）。

参考脚本结构：

```javascript
const WebSocket = require('ws');
const PAGE_WS = process.argv[2];  // 传 webSocketDebuggerUrl
const ws = new WebSocket(PAGE_WS);

ws.on('message', (data) => {
  const msg = JSON.parse(data);
  // 处理 ack 响应 / consoleAPICalled 事件
});

ws.on('open', async () => {
  await send('Runtime.enable');
  // Test 1: on
  await evalJs(`(function(){
    window.__testEventLog = [];
    EventSub.on('test.echo');
    return 'ok';
  })()`);

  // Test 2: echo -> 500ms 后事件到达
  await evalJs(`onEcho()`);
  await sleep(1200);
  const log = await evalJs(`window.__testEventLog`);
  // 断言 log 里含 {stage:'event received', event:{data:{hello:'world'}}}

  // Test 3: off + echo -> 无投递
  // Test 4: reload + echo -> clearAll 触发 + 无 stale
});
```

**测试覆盖**（脚本里实现的断言）：
- Test 1: on 后 ack 返回正确 topic
- Test 2: echo 后 1200ms 内 `__testEventLog` 含 `event received`
- Test 3: off 后 echo 不再投递
- Test 4: 同 topic 二次 on 覆盖（旧 callback 不再被调用）—— 注意：H5 端 demo 只挂一个 topic，所以这个用例需要业务侧配合多 callback 注册
- Test 5: reload 后 `clearAll()` 触发，未订阅时 echo 无投递

### C.3 故障排查

- `curl http://localhost:9222/json` 返回空列表 → WebView debug 没开，确认 `WebBoxApplication.initializeCoconutSDK()` 调了 `setEnableWebViewDebug(true)`
- WebSocket 连不上 → `adb forward` 命令的 PID 不对，重新查 socket 名
- `Runtime.evaluate` 报 `Cannot read property 'EventSub' of undefined` → 页面还没加载完，脚本里加 `await sleep(1000)` 等页面 ready

---

## 验收清单

完整端到端验证完成的标准（每条都打勾）：

- [ ] 方式 A：`./gradlew :coconut-core:testDebugUnitTest` 71 个测试全过，含 EventEmitterTest 10 个
- [ ] 方式 B.2：启动日志显示 Components registered 含 event + Bridge setup complete + clearAll 钩子触发
- [ ] 方式 B 步骤 1：On ack 显示在 eventView
- [ ] 方式 B 步骤 2：500ms 后 eventView 显示 `event received` + 正确 payload
- [ ] 方式 B 步骤 3：Off ack 显示
- [ ] 方式 B 步骤 4：再次 Echo 无事件投递
- [ ] 方式 B 步骤 5：reload 后 native registry 清空，再 Echo 无 stale 投递
- [ ] 方式 C（可选）：CDP 自动化脚本 5 个 case 全部 PASS

---

## 故障排查

### 启动日志没出现 Components registered 含 event

 `WebBoxApplication.initializeCoconutSDK()` 的 `registerComponents` 调用漏了 `EventComponent()`：

```kotlin
CoconutSDK.registerComponents(
    DeviceComponent(),
    StorageComponent(),
    EventComponent()        // ← 必须加
)
```

### 启动日志有 `Cleared 0 subscription(s)` 但点 Echo 后还是 `emit no subscriber: test.echo`

 jsExecutor 接线可能在 `CoconutWebActivity.setupBridge()` 之后被覆盖，或 EventComponent 的 `sharedContext.eventEmitter` 拿到的是另一个实例。

检查 `CoconutWebActivity.kt`：
```kotlin
// setupBridge() 末尾必须有
ComponentManager.getInstance().eventEmitter.jsExecutor = { script ->
    runOnMainThread {
        if (::webView.isInitialized) webView.evaluateJavascript(script, null)
    }
}
```

### 点 Echo 后 native 日志有 `Emitted 'test.echo'`，但 H5 端 eventView 不更新

 可能是：
1. `webView.evaluateJavascript(script, null)` 调用失败 —— 看 logcat 有没有 `Failed to dispatch event` 报错
2. H5 端 `__coconutEvent` 没注册 —— 看 `coconut_index.html` 是否含 `window.__coconutEvent = function (json) { EventSub.dispatch(json); };`
3. H5 端 `EventSub.dispatch` 在 `event.topic !== this._topic` 时直接 return —— 比较请求里的 topic 和事件里的 topic
4. **Android threading bug**：`emit` 来自后台线程时直接调 `evaluateJavascript` 会失败 —— 检查 jsExecutor 是否包了 `runOnMainThread { ... }`

### reload 后还能看到事件投递（stale emit bug）

 `onPageStarted` 钩子没接好 clearAll。**这是关键 bug**，必须修复后才能上线。

检查 `CoconutWebActivity.kt`：
```kotlin
override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
    super.onPageStarted(view, url, favicon)
    ComponentManager.getInstance().eventEmitter.clearAll()
}
```

---

## 参考命令汇总

```bash
# Build + installation
cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework/AndroidWebBox
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk

# Launch + monitor
adb shell am start -n com.sniper.androidwebbox/.MainActivity
adb logcat -s CoconutSDK:*

# Unit tests
./gradlew :coconut-core:testDebugUnitTest

# CDP automation
PID=$(adb shell pidof com.sniper.androidwebbox)
adb forward tcp:9222 localabstract:webview_devtools_remote_$PID
curl -s http://localhost:9222/json | grep webSocketDebuggerUrl
node /tmp/android_event_test.js "ws://localhost:9222/devtools/page/<ID>"

# 截图
adb exec-out screencap -p > /tmp/android.png
```
