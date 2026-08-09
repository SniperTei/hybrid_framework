# HarmonyOS Event Subscription 端到端测试

> 测试 `EventComponent`（native → H5 push 通道）在 HarmonyOS 端的完整工作流。
> 实现细节见 `~/.claude/projects/-Users-zhengnan-Sniper-Developer-github-hybrid-framework/memory/event-subscription.md`。

---

## 测试目标

验证 4 个核心行为：

| # | 行为 | 期望结果 |
|---|---|---|
| 1 | Subscribe | native ack 回到 H5，subscriptionId 正确 |
| 2 | Echo 后 500ms 收到事件 | `window.__coconutEvent` 被调用，payload 含 `{hello:'world'}` |
| 3 | Unsubscribe 后不再投递 | 再次 Echo，H5 无事件回调 |
| 4 | 页面 reload 后无 stale 投递 | reload 触发 `clearAll()`，新页面再 Echo（未订阅）无事件 |

> **第 4 项是 Harmony 端的关键修复点**：早期实现 reload 后 stale emit 投递到新页面上下文（H5 端 callback 已失效但 native registry 还在）。`onPageBegin` 钩 `clearAll()` 是必须的。

---

## 前置准备

### 1. 设备 / 模拟器

```bash
# 真机：开 USB 调试；模拟器：DevEco Studio 启动
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
$HDC list targets
# 期望至少一条记录，例如：
# Connect Server Holder   127.0.0.1:5555
```

### 2. 工具链路径

```bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export PATH="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:\
/Applications/DevEco-Studio.app/Contents/tools/node:\
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH"
```

### 3. 构建 + 安装 app

```bash
cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework/HarmonyWebBox
hvigorw --mode module -p module=entry -p product=default assembleHap
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
$HDC install -r entry/build/default/outputs/default/entry-default-signed.hap
```

**关键信息**：
- Bundle name: `com.example.harmonywebbox`（见 `AppScope/app.json5`）
- 测试模块：`entry`（HAR 模块 `CoconutSDK` 不能独立跑 ohosTest）
- Web 组件位于 `CoconutWebPage.ets`（`@kit.ArkWeb` 的 `Web` + `WebviewController`）
- Web 组件**不暴露** CDP（不像 Android WebView），没法像 Android 那样直接 WebSocket 注入 JS

---

## 方式 A：Hypium 单元测试（自动，~7s，推荐）

最快的反馈。覆盖 `EventEmitter` 的 9 个 case（真机测试，在设备上跑）。

### A.1 一键脚本（推荐）

```bash
cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework/HarmonyWebBox
bash scripts/run-harmony-tests.sh --no-report
```

脚本内部做的事（如果手动跑也可以）：

```bash
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export PATH="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:\
/Applications/DevEco-Studio.app/Contents/tools/node:\
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH"
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
cd HarmonyWebBox

hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap
$HDC install -r entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
$HDC shell aa test -b com.example.harmonywebbox -m entry_test \
  -s unittest /ets/testrunner/OpenHarmonyTestRunner
# 末尾输出 OHOS_REPORT_RESULT: stream=Tests run: 121, Failure: 0, Error: 0, Pass: 121
```

**期望**：121 个测试全部通过，其中 `EventEmitter.test.ets` 9 个：
- subscribe + emit 投递成功
- unsubscribe 后不再投递
- 同 topic 多订阅者都收到
- topic 不匹配不投递
- echo round-trip
- 无 jsExecutor 静默丢弃
- clearAll 清空
- 空参数拒绝
- JS 字符串转义正确

**注意**：
- ❌ 不能用 JVM/Node 跑（crypto/UUID 需 HarmonyOS runtime）
- ❌ DevEco Studio 右键 `.test.ets` 经常没有 Run 选项（IDE 缓存/识别问题）—— 命令行更可靠
- ✅ `@ohos/hypium` 1.0.25（项目级已声明）
- ✅ flags: `--quiet` / `--no-report` / `--keep-raw FILE`；退出码反映测试结果，可直接接 CI

### A.2 测试注册点

如果新测试 case 没被跑到，检查 `entry/src/ohosTest/ets/test/coconut/List.test.ets` 是否调了 `eventEmitterTest()`：

```typescript
import { eventEmitterTest } from './event/EventEmitter.test';
// ...
export default function testsuite() {
  eventEmitterTest();
  // ... 其他
}
```

---

## 方式 B：手动 UI 端到端（点按钮）

### B.1 启动 app + 监听 hilog

```bash
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"

# 启动 app
$HDC shell aa start -a EntryAbility -b com.example.harmonywebbox

# 实时看 CoconutSDK 日志（开另一个终端）
$HDC shell hilog | grep -E "CoconutSDK|EventEmitter|EventComponent"
```

> EntryAbility 启动后会加载 `pages/Index`，Index 的 `aboutToAppear` 里调 `registerComponents([..., new EventComponent()])`，之后跳转到 `CoconutWebPage` 加载 coconut_index.html。

### B.2 验证启动日志

hilog 应输出（按顺序）：

```
CoconutSDK ComponentManager Registering: event v1.0.0
EventComponent Event component initialized
CoconutWebPage Page begin: file:///entry/resources/rawfile/coconut_index.html
EventEmitter Cleared 0 subscription(s)   ← onPageBegin 钩子触发
CoconutWebPage Page end: ...
```

**关键检查点**：
- ✅ Components registered 列表里**含 event**
- ✅ `Page begin` 后立即 `Cleared 0 subscription(s)` —— `onPageBegin` 钩子触发（首次加载清 0 是正常的）
- ✅ Page end 表示 rawfile 加载完成

如果 `Page begin` 后**没有** `Cleared 0 subscription(s)`，说明 Harmony 关键修复漏接了 —— **必须修后再继续**。

### B.3 操作 Web 组件上的按钮

页面顶部应显示蓝色徽章 `当前平台：HarmonyOS NEXT`。按钮分 3 组。

#### 步骤 1：点「订阅 test.echo」（紫色按钮）

期望 eventView 显示：
```json
{ "stage": "subscribe ack", "subscriptionId": "sub_demo_1", "resp": { "code": "000000", ... } }
```

hilog：
```
EventComponent Subscribe: topic=test.echo, subscriptionId=sub_demo_1
EventEmitter Subscribed: sub_demo_1 -> test.echo
```

#### 步骤 2：点「Echo（500ms 后回推）」（紫色按钮）

期望（约 500ms 后）eventView 显示：
```json
{
  "stage": "event received",
  "event": {
    "subscriptionId": "sub_demo_1",
    "topic": "test.echo",
    "data": { "hello": "world" }
  }
}
```

hilog：
```
EventComponent Echo scheduled, topic=test.echo, delay=500ms
EventEmitter Emitting to 1 subscriber(s) for topic: test.echo
EventEmitter Dispatched JS to subscriber sub_demo_1
```

#### 步骤 3：点「取消订阅」（红色按钮）

期望：
```
EventComponent Unsubscribe: subscriptionId=sub_demo_1
EventEmitter Unsubscribed: sub_demo_1
```

eventView 显示 unsubscribe ack。

#### 步骤 4：再次点「Echo」

期望：
- eventView **保持上一步状态不变**
- hilog：
  ```
  EventComponent Echo scheduled, topic=test.echo, delay=500ms
  EventEmitter Emitting to 0 subscriber(s) for topic: test.echo
  ```

#### 步骤 5（关键）：reload 页面，验证无 stale 投递

Harmony 上 reload 方式：
1. **推荐**：DevEco Studio 的 Inspector 找到 Web 组件，触发 reload
2. 或者从 EntryAbility 重新进入页面（`aa start` 重启 EntryAbility）

reload 后**不要**再点「订阅」，直接点「Echo」：

期望 hilog：
```
CoconutWebPage Page begin: file:///...
EventEmitter Cleared 1 subscription(s)   ← onPageBegin 钩子触发清空
CoconutWebPage Page end: ...
EventComponent Echo scheduled, topic=test.echo, delay=500ms
EventEmitter Emitting to 0 subscriber(s) for topic: test.echo
```

eventView **无事件被投递**。

如果 reload 后还能看到 `Emitting to 1 subscriber(s)`，说明 `onPageBegin` 钩子没接好 clearAll —— 这是 Harmony 上踩过的关键坑。

---

## 方式 C：自动化驱动（受限）

Harmony Web 组件**不暴露** Chrome DevTools Protocol，没法像 Android 那样用 WebSocket 注入 JS。可选方案：

### C.1 DevEco Studio Inspector

打开 DevEco Studio → 连接设备 → 启动 app → 用 Inspector 找到 Web 组件。Inspector 可以看到组件树，但不能直接注入 JS。

### C.2 ArkTS UI 测试（推荐自动化方式）

Harmony 提供 `@ohos.UiTest` 框架（在 `entry/src/ohosTest/` 下），可以扩展加 event 测试 case：

```typescript
// entry/src/ohosTest/ets/test/event/E2ETest.test.ets
import { describe, it } from '@ohos/hypium';
import { Driver } from '@ohos.UiTest';

export default function eventE2ETest() {
  describe('EventE2E', () => {
    it('subscribe_echo_unsubscribe', 0, async () => {
      const driver = Driver.create();
      await driver.assertComponentExist(ON.text('订阅 test.echo'));
      await driver.press(ON.text('订阅 test.echo'));
      await driver.press(ON.text('Echo（500ms 后回推）'));
      await driver.delayMs(1000);
      // 断言 eventView 里出现 "event received"
      const eventView = await driver.findComponent(ON.id('eventView'));
      const text = await eventView.getText();
      expect(text).assertContain('event received');
    });
  });
}
```

> 这种方式要求测试目标 app 必须是专门的「测试 app」（不是 production app），需要在 `entry` 模块下加 e2e test config。详细参考 HarmonyOS 官方文档 [Ui测试框架](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-driven-testing-0000001846745601)。

### C.3 hdc 直接注入（不可行）

`hdc shell` 没有「直接注入 JS 到 Web 组件」的命令。Web 组件的 JS 执行只能通过 `webController.runJavaScript()` 从 ArkTS 端调，外部无法绕过。

---

## 验收清单

完整端到端验证完成的标准（每条都打勾）：

- [ ] 方式 A：`bash scripts/run-harmony-tests.sh --no-report` 121 个测试全过，含 EventEmitter 9 个
- [ ] 方式 B.2：启动日志显示 Components registered 含 event + onPageBegin 触发 clearAll
- [ ] 方式 B 步骤 1：Subscribe ack 显示在 eventView
- [ ] 方式 B 步骤 2：500ms 后 eventView 显示 `event received` + 正确 payload
- [ ] 方式 B 步骤 3：Unsubscribe ack 显示
- [ ] 方式 B 步骤 4：再次 Echo 无事件投递
- [ ] 方式 B 步骤 5：reload 后 native registry 清空，再 Echo 无 stale 投递

---

## 故障排查

### 编译错：`Cannot find import 'EventEmitter' from '@coconut/sdk'`

→ HAR 模块不自动 export，需要手动加到 barrel 文件。检查 `HarmonyWebBox/CoconutSDK/index.ets`：

```typescript
export { EventEmitter, Subscription, JsExecutor } from './src/main/ets/event/EventEmitter'
```

### 编译错：`arkts-no-nested-funcs`

→ ArkTS 严格模式禁止嵌套函数。测试里 helper 函数必须放 module-level：

```typescript
// ❌ 不行
describe('xxx', () => {
  function helper() { ... }   // 嵌套函数
});

// ✅ 正确
function helper() { ... }
describe('xxx', () => { ... });
```

### 编译错：`arkts-no-untyped-obj-literals`

→ ArkTS 严格模式禁止无类型 object literal：

```typescript
// ❌ 不行
await obj.init({});

// ✅ 正确
await obj.init(new Object());
```

### 启动日志没出现 `Registering: event v1.0.0`

→ `entry/src/main/ets/pages/Index.ets` 的 `registerComponents` 漏了 `new EventComponent()`：

```typescript
CoconutSDK.registerComponents([
    new DeviceComponent(),
    new StorageComponent(),
    new EventComponent(),     // ← 必须加
]);
```

### 启动日志有 `Page begin` 后**没有** `Cleared 0 subscription(s)`

→ `onPageBegin` 钩子漏接了 clearAll。检查 `CoconutWebPage.ets`：

```typescript
.onPageBegin((event) => {
  if (event) {
    this.isLoading = true;
    this.showError = false;
    // ↓ 必须有这一段
    const ctx = ComponentManager.getInstance().getSharedContext();
    ctx?.eventEmitter.clearAll();
    Logger.d('CoconutWebPage', `Page begin: ${event.url}`);
  }
})
```

### 点 Echo 后 native 日志有 `Emitting to 1 subscriber(s)`，但 H5 端 eventView 不更新

→ 可能是：
1. `webController.runJavaScript(script)` 调用失败 —— 看 hilog 有没有 `Failed to runJavaScript` 报错
2. H5 端 `__coconutEvent` 没注册 —— 看 `coconut_index.html` 是否含 `window.__coconutEvent = function (json) { EventSub.dispatch(json); };`
3. **测试位置错**：Harmony 的 ohosTest 必须在 `entry` 模块下（**不在 HAR 模块**），import 用 `@coconut/sdk`

### reload 后还能看到事件投递（stale emit bug）

→ `onPageBegin` 钩子没接好 clearAll。**这是 Harmony 上踩过的关键坑**，必须修复后才能上线。

---

## 参考命令汇总

```bash
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
export DEVECO_SDK_HOME="/Applications/DevEco-Studio.app/Contents/sdk"
export PATH="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:\
/Applications/DevEco-Studio.app/Contents/tools/node:\
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:$PATH"

cd /Users/zhengnan/Sniper/Developer/github/hybrid_framework/HarmonyWebBox

# Build app HAP
hvigorw --mode module -p module=entry -p product=default assembleHap
$HDC install -r entry/build/default/outputs/default/entry-default-signed.hap

# Launch + monitor
$HDC shell aa start -a EntryAbility -b com.example.harmonywebbox
$HDC shell hilog | grep -E "CoconutSDK|EventEmitter|EventComponent"

# Unit tests (一键脚本)
bash scripts/run-harmony-tests.sh --no-report

# 截图
$HDC shell snapshot_display -f /tmp/harmony.png
$HDC file recv /tmp/harmony.png /tmp/harmony.png
```
