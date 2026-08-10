# iOS Event Subscription 端到端测试

> 测试 `EventComponent`（native → H5 push 通道）在 iOS 端的完整工作流。
> 实现细节见 `/Users/zhengnan/.claude/projects/-Users-zhengnan-Sniper-Developer-github-hybrid-framework/memory/event-subscription.md`。

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

### 1. 模拟器 / 真机

```bash
# 列出可用模拟器
xcrun simctl list devices available | grep iPhone

# 本文以 iPhone 16 (18.2) 为例，UDID：2493097D-3EC4-48C3-8E4D-7C164A11E568
# 替换为你机器上任意可用的 iPhone 模拟器 UDID
```

### 2. 构建 iOSWebBox app

```bash
cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework/iOSWebBox
xcodebuild build \
  -scheme iOSWebBox \
  -destination 'id=2493097D-3EC4-48C3-8E4D-7C164A11E568' \
  -derivedDataPath build
```

构建产物：`iOSWebBox/build/Build/Products/Debug-iphonesimulator/iOSWebBox.app`

---

## 方式 A：单元测试（自动，~0.3s）

最可靠、最快的反馈。覆盖 `EventEmitter` 的 10 个 case（不依赖 WebView）。

```bash
cd iOSWebBox/CoconutSDK
xcodebuild test \
  -scheme CoconutSDK \
  -destination 'id=2493097D-3EC4-48C3-8E4D-7C164A11E568'
```

**期望**：74 个测试全部通过，其中 `EventEmitterTests` 10 个：
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
- ❌ 不能用 `swift test` — 默认 host 是 macOS，UIKit 找不到
- ✅ 必须用 UDID，**不能**用 `name=iPhone 16`（18.2 / 18.4 重名歧义）

---

## 方式 B：手动 UI 端到端（最贴近真实场景）

### B.1 启动 app + 监听 console 日志

```bash
UDID=2493097D-3EC4-48C3-8E4D-7C164A11E568

# 启动模拟器（如果没开）
xcrun simctl boot $UDID 2>/dev/null || true
open -a Simulator

# 安装 app
xcrun simctl install $UDID \
  iOSWebBox/build/Build/Products/Debug-iphonesimulator/iOSWebBox.app

# 启动 app + 实时打印 console 日志
# （--console-pty 让 NSLog/printf 输出到当前终端）
xcrun simctl launch --console-pty $UDID com.sniper.tool.iOSWebBox
```

> Bundle ID 是 `com.sniper.tool.iOSWebBox`（**不是** `com.sniper.iOSWebBox`）。
> 如果不确定，用 `xcrun simctl listapps $UDID | grep -A1 iOSWebBox` 查。

### B.2 验证启动日志

启动后控制台应输出（按顺序）：

```
[CoconutSDK] [ComponentManager] Registering: event v1.0.0
[CoconutSDK] [event] Event component initialized
[CoconutSDK] [CoconutWebVC] Bridge setup complete
[CoconutSDK] [EventEmitter] Cleared 0 subscription(s)   ← didStartProvisionalNavigation 钩子触发
[CoconutSDK] [CoconutWebVC] Page loaded
```

**关键检查点**：
- ✅ `Registering: event v1.0.0` — EventComponent 已注册
- ✅ `Bridge setup complete` — EventEmitter 的 jsExecutor 已接到 WebViewJSExecutor
- ✅ `Cleared 0 subscription(s)` — `didStartProvisionalNavigation` 钩子触发（首次加载清 0 是正常的）

如果上面任何一条缺失，说明接线有问题，先排查再继续。

### B.3 操作 WebView 上的按钮

在 Simulator 窗口里点按钮（或用 `xcrun simctl io $UDID screenshot /tmp/x.png` 截图查看）：

页面顶部应显示蓝色徽章 `当前平台：iOS`。下方按钮分 3 组：

#### 步骤 1：点「订阅 test.echo」（紫色按钮）

期望：
- 「事件投递」面板显示绿色文字：
  ```json
  { "stage": "on ack", "topic": "test.echo", "resp": { "code": "000000", ... } }
  ```

#### 步骤 2：点「Echo（500ms 后回推）」（紫色按钮）

期望（约 500ms 后）：
- 「事件投递」面板显示绿色文字：
  ```json
  {
    "stage": "event received",
    "event": {
      "topic": "test.echo",
      "data": { "hello": "world" }
    }
  }
  ```
- 同时控制台应输出：
  ```
  [CoconutSDK] [event] echo emitted: test.echo
  [CoconutSDK] [EventEmitter] Emitted 'test.echo'
  ```

#### 步骤 3：点「取消订阅」（红色按钮）

期望：
- 「事件投递」面板显示灰色文字：
  ```json
  { "stage": "off ack", "topic": "test.echo", "resp": { "code": "000000", ... } }
  ```

#### 步骤 4：再次点「Echo」

期望：
- 「事件投递」面板**保持上一步的 off ack 不变**（因为 native 不再投递事件，H5 端 eventView 无更新）
- 控制台应输出：
  ```
  [CoconutSDK] [EventEmitter] emit no subscriber: test.echo
  ```
  （注意：是 `no subscriber` —— 因为 off 把 registry 里这条 topic 删了）

#### 步骤 5（关键）：reload 页面，验证无 stale 投递

1. 在模拟器里，用 `Cmd+R` 或 Safari 的「Develop → Simulator → coconut_index.html → Reload Page」刷新页面
2. **不要**再点「订阅」按钮
3. 直接点「Echo」

期望：
- 控制台输出：
  ```
  [CoconutSDK] [EventEmitter] Cleared N subscription(s)   ← reload 钩子触发清空
  [CoconutSDK] [CoconutWebVC] Page loaded
  [CoconutSDK] [event] echo emitted: ...
  [CoconutSDK] [EventEmitter] emit no subscriber: test.echo   ← 因为 registry 已清空
  ```
- 「事件投递」面板**无事件被投递**（native 端因为 registry 已清空，根本不会调 `__coconutEvent`）

如果 reload 之后还能看到 `Emitted 'test.echo'`，说明 `clearAll()` 没正确触发 —— 检查 `CoconutWebViewController.swift` 的 `didStartProvisionalNavigation` 钩子。

---

## 方式 C：自动化驱动（高级，可选）

iOS 模拟器**不暴露** Chrome DevTools Protocol，没法像 Android 那样直接用 WebSocket 注入 JS。可选方案：

### C.1 Safari Web Inspector（推荐，需 GUI）

1. 打开 Safari → 设置 → 高级 → 勾选「在菜单栏中显示开发菜单」
2. 菜单栏：「开发 → [你的模拟器名] → coconut_index.html」
3. 在 Safari 的 Web Inspector 里直接执行：
   ```js
   // 跑一次完整 on → echo 流程
   window.__testLog = [];
   var origDispatch = window.__coconutEvent;
   window.__coconutEvent = function(json) {
     window.__testLog.push(JSON.parse(json));
     origDispatch(json);
   };
   onSubscribe();
   setTimeout(onEcho, 600);
   setTimeout(() => console.log('RESULT:', JSON.stringify(window.__testLog)), 1500);
   ```
4. 期望 1.5s 后看到 `RESULT: [{"topic":"test.echo","data":{"hello":"world"}}]`

### C.2 AppleScript 自动点击（受限）

```bash
osascript -e 'tell application "Simulator" to activate'
# 然后用 cliclick 等工具按坐标点击
# brew install cliclick
# cliclick c:300,400   # 模拟点击 (x=300, y=400)
```

**注意**：AppleScript 控制 System Events 需要「辅助功能」权限（系统设置 → 隐私与安全性 → 辅助功能 → 添加 Terminal/iTerm）。权限不足时会报 `-1719 osascript is not allowed assistive access`。

### C.3 `xcrun simctl` UI 自动化

`simctl` 不提供直接点击 UI 元素的命令。截图命令可用：
```bash
xcrun simctl io $UDID screenshot /tmp/ios_state.png
```

如需真正的 UI 自动化，用 Xcode 的 `XCUITest`（项目里已有 `iOSWebBoxUITests` target，可以扩展加 event 测试 case）。

---

## 验收清单

完整端到端验证完成的标准（每条都打勾）：

- [ ] 方式 A：`xcodebuild test` 74 个测试全过，含 EventEmitterTests 10 个
- [ ] 方式 B.2：启动日志显示 EventComponent 注册 + bridge setup + clearAll 钩子触发
- [ ] 方式 B 步骤 1：On ack 显示在 eventView
- [ ] 方式 B 步骤 2：500ms 后 eventView 显示 `event received` + 正确 payload
- [ ] 方式 B 步骤 3：Off ack 显示
- [ ] 方式 B 步骤 4：再次 Echo 无事件投递（native 日志 `emit no subscriber`）
- [ ] 方式 B 步骤 5：reload 后 native registry 清空，再 Echo 无 stale 投递

---

## 故障排查

### 启动日志没出现 `Registering: event v1.0.0`

 `SceneDelegate.swift` 的 `registerComponents` 漏了 `EventComponent()`：

```swift
// iOSWebBox/SceneDelegate.swift
ComponentManager.shared.registerComponents([
    DeviceComponent(),
    StorageComponent(),
    EventComponent(),    // ← 必须加
])
```

### 启动日志没出现 `Bridge setup complete` 后的 `Cleared 0 subscription(s)`

 `CoconutWebViewController.swift` 的 `setupBridge()` 漏接 jsExecutor，或 `didStartProvisionalNavigation` 漏调 clearAll。

检查：
```swift
// setupBridge() 里
ComponentManager.shared.sharedContext.eventEmitter.jsExecutor = WebViewJSExecutor(webView: webView)

// WKNavigationDelegate 里
func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    ComponentManager.shared.sharedContext.eventEmitter.clearAll()
}
```

### 点 Echo 后 native 日志有 `Emitted 'test.echo'`，但 H5 端 eventView 不更新

 可能是：
1. WebViewJSExecutor 的 `evaluateJavaScript` 调用失败 —— 看 native 日志有没有 `Failed to dispatch event` 报错
2. H5 端 `__coconutEvent` 没注册（看 coconut_index.html 是否含 `window.__coconutEvent = function (json) { EventSub.dispatch(json); };`）
3. H5 端 `EventSub.dispatch` 在 `event.topic !== this._topic` 时直接 return（topic 不一致 —— 看请求和事件两边的 topic）

### reload 后还能看到事件投递（stale emit bug）

 `didStartProvisionalNavigation` 钩子没接好 clearAll。**这是关键的跨平台 bug**（Harmony 上踩过坑），必须修复后才能上线。

---

## 参考命令汇总

```bash
# 一键 build + install + launch + 看日志
UDID=2493097D-3EC4-48C3-8E4D-7C164A11E568
APP_PATH=iOSWebBox/build/Build/Products/Debug-iphonesimulator/iOSWebBox.app
BUNDLE_ID=com.sniper.tool.iOSWebBox

cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework/iOSWebBox
xcodebuild build -scheme iOSWebBox -destination "id=$UDID" -derivedDataPath build
xcrun simctl boot $UDID 2>/dev/null || true
xcrun simctl install $UDID "$APP_PATH"
xcrun simctl launch --console-pty $UDID $BUNDLE_ID
```

```bash
# 跑单元测试
cd iOSWebBox/CoconutSDK
xcodebuild test -scheme CoconutSDK -destination "id=$UDID"
```

```bash
# 截图查看当前 UI 状态
xcrun simctl io $UDID screenshot /tmp/ios.png
open /tmp/ios.png
```
