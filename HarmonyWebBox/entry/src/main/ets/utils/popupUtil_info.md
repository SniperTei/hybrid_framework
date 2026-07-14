# PopupUtil

通用自定义弹窗工具。允许**任意类**（包括不含 UI 的普通 TS 类，如 Bridge 组件、Service、Manager 等）弹出**任意自定义弹窗**。

零第三方依赖，仅使用 HarmonyOS 原生 kit（`@kit.AbilityKit` + `@kit.ArkUI`），可直接移植到任意鸿蒙项目。

---

## 解决什么问题

ArkUI 的 `CustomDialogController` 有一个硬约束：**必须是 `@Component` 的成员变量**才能用。这意味着普通 TS 类（比如 Bridge 组件、网络层、Repository 等）拿不到它，无法弹自定义弹窗。

PopupUtil 走的是 API 12+ 的另一条路：

```
普通 TS 类
  ↓ 调 PopupUtil.show(...)
window.getLastWindow(abilityContext)
  ↓
window.getUIContext()
  ↓
uiContext.getPromptAction().openCustomDialog(
  new ComponentContent<T>(uiContext, wrappedBuilder, params)
)
```

完全绕开 `CustomDialogController`，普通 TS 类也能用。

---

## 文件结构

```
your_project/entry/src/main/ets/
├── utils/
│   └── PopupUtil.ets                 ← 核心（必带）
└── components/popup/                  ← 每个弹窗独占一个文件
    ├── CustomView1.ets                ← 双按钮样式（参考模板）
    └── CustomDialog2.ets              ← 带输入框样式（参考模板）
```

每个 `XxxPopup.ets` 自包含，互不依赖。需要哪种就拷哪种。

---

## 移植步骤（3 步）

### Step 1：拷文件

把以下文件复制到目标项目，目录结构可以自定，但 import 路径要相应调整：

- `utils/PopupUtil.ets`（必带）
- `components/popup/XxxPopup.ets`（按需，至少带一个）

### Step 2：初始化

在自己的 `EntryAbility.onCreate` 里调一次 `PopupUtil.init(this.context)`：

```typescript
import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { PopupUtil } from '../utils/PopupUtil';   // 路径按实际调整

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    PopupUtil.init(this.context);   // ← 加这一行
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => { /* ... */ });
  }
}
```

**为什么要在 `onCreate` 里 init？**
- `UIAbilityContext` 在 app 进程内稳定，缓存它一次即可。
- 之后再调 `PopupUtil.show()` 时，会用这个 context 去拿 window → UIContext。
- UIContext 不缓存（window 重建/旋转/切前后台会失效），每次 show 时现取。

### Step 3：调用

```typescript
import { CustomView1Popup, CustomView1Params } from '../components/popup/CustomView1';

// 任意类、任意方法里
const handle = await CustomView1Popup.show({
  title: '提示',
  message: '确认删除？',
  onConfirm: () => { /* 用户点了确定 */ handle.dismiss(); },
  onCancel:  () => { /* 用户点了取消 */ handle.dismiss(); }
});
```

完成。**无需注册、无需改配置、无需改 PopupUtil。**

---

## API

### `PopupUtil.init(context)`
| 参数 | 类型 | 说明 |
|------|------|------|
| `context` | `common.UIAbilityContext` | app 进程内稳定，EntryAbility.onCreate 一次性传入 |

调一次即可。多次调用以最后一次为准（不报错）。

### `PopupUtil.show(builder, params, options?)`
核心 API。一般不直接调用，通过 `XxxPopup.show()` 门面调用。

| 参数 | 类型 | 说明 |
|------|------|------|
| `builder` | `WrappedBuilder<[T]>` | 由 `wrapBuilder(@Builder function)` 产生 |
| `params` | `T extends Object` | 弹窗参数实例（**必须是 class，不能是 interface/object literal**） |
| `options?` | `PopupOptions` | 弹窗选项，可省 |

**返回**：`Promise<PopupHandle>` — resolve 时弹窗已经显示。

**抛错**：未 init 调用、`openCustomDialog` 系统调用失败时 reject。

### `PopupOptions`

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `alignment` | `DialogAlignment` | `Center` | 屏幕对齐 |
| `isModal` | `boolean` | `true` | 是否模态（背景是否拦截点击） |
| `showInSubWindow` | `boolean` | `false` | 是否在子窗口显示 |
| `autoCancel` | `boolean` | `false` | 点 mask 是否自动关闭 |

> 字段全部透传给 `promptAction.BaseDialogOptions`。

### `PopupHandle`

```typescript
interface PopupHandle {
  dismiss(): Promise<void>;   // 程序化关闭弹窗（幂等，可重复调）
}
```

---

## 内置弹窗模板

### `CustomView1Popup`（双按钮）

```typescript
class CustomView1Params {
  title: string;
  message: string;
  confirmText: string = '确定';
  cancelText: string = '取消';
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
}
```

用法：
```typescript
const handle = await CustomView1Popup.show({
  title: '确认操作',
  message: '这条记录删除后不可恢复',
  onConfirm: () => { deleteRecord(); handle.dismiss(); },
  onCancel:  () => { handle.dismiss(); }
});
```

### `CustomDialog2Popup`（带输入框）

```typescript
class CustomDialog2Params {
  title: string;
  message: string;
  inputPlaceholder: string = '';
  initialValue: string = '';
  confirmText: string = '确定';
  cancelText: string = '取消';
  onConfirm: (value: string) => void = () => {};   // 参数是当前输入值
  onCancel: () => void = () => {};
}
```

用法：
```typescript
const handle = await CustomDialog2Popup.show({
  title: '重命名',
  message: '请输入新名称',
  inputPlaceholder: '输入名称',
  onConfirm: (value) => { save(value); handle.dismiss(); },
  onCancel:  () => { handle.dismiss(); }
});
```

> ⚠️ 这两个模板的 UI 只是参考实现。如果你有自己的视觉规范，直接改 `@Builder` 函数里的样式即可，**API 不变**。

---

## 新增一个自定义弹窗（标准步骤）

1. **复制模板**：拷贝 `CustomView1.ets` → 改名为 `MyAlert.ets`，放在 `components/popup/` 下。

2. **改 4 处命名 + 字段**：
   ```typescript
   // 1) 参数类名 + 字段
   export class MyAlertParams {
     title: string = '';
     onConfirm: () => void = () => {};
   }

   // 2) @Builder 函数名 + 内部 UI
   @Builder
   function MyAlertBuilder(params: MyAlertParams) {
     Column() { /* 你的 UI */ }
   }

   // 3) wrapBuilder 常量
   const myAlertBuilder: WrappedBuilder<[MyAlertParams]> = wrapBuilder(MyAlertBuilder);

   // 4) 门面类
   export class MyAlertPopup {
     static show(params: MyAlertParams, options?: PopupOptions): Promise<PopupHandle> {
       return PopupUtil.show(myAlertBuilder, params, options);
     }
   }
   ```

3. **调用方使用**：
   ```typescript
   import { MyAlertPopup } from '../components/popup/MyAlert';

   const handle = await MyAlertPopup.show({
     title: 'Hello',
     onConfirm: () => handle.dismiss()
   });
   ```

无需改 PopupUtil、无需注册、无需改任何配置。

---

## ArkUI 硬约束（踩坑记录）

新增弹窗时必须遵守，否则编译失败：

1. **`@Builder` 必须是模块级全局函数**，不能是类方法。
2. **`wrapBuilder(builderFn)` 必须和 `@Builder` 在同一文件里**调用（编译器要求）。
3. **`ComponentContent<T>` 的 `T` 必须是 class**，不能是 interface 或 object literal，否则 ArkTS 严格模式报错（`arkts-no-untyped-obj-literals`）。
4. **泛型必须 `<T extends Object>`**，因为 `ComponentContent<T>` 的类型参数有此约束。
5. **`throw` 的必须是 `Error` 实例**（`arkts-limited-throw`），不能 `throw e`。
6. **对象字面量必须有显式类型**（`arkts-no-untyped-obj-literals`）—— 用 class 实例代替。

→ 结论：**每个自定义弹窗独占一个 .ets 文件**，四件套（参数类 + @Builder + wrapBuilder + 门面类）必须同文件。

---

## 已知限制

| 限制 | 说明 | 缓解 |
|------|------|------|
| 单 UIAbility 假设 | `abilityContext` 是 static 单例，多 ability 场景下会串 | 当前 hybrid framework 只有一个 UIAbility，单实例够用。多 ability 时改成 `Map<abilityId, context>` |
| 每次 show 都 `getLastWindow` | 不缓存 UIContext（window 重建会失效），每次现取 | 微秒级开销，非热点路径，安全优先 |
| `autoCancel` 自动关闭感知 | 用户开了 autoCancel 点 mask 关闭后，调用方持有的 `handle` 仍可调 `dismiss()`（幂等无副作用），但调用方不知道弹窗已关 | 如需感知，用 `promptAction.openCustomDialog` 的 `onDidDismiss` 回调（当前 PopupUtil 未暴露，需要时加） |
| 单 ability 路径下的 getLastWindow | 多窗口（分屏 / 多实例）时取的是"最后活跃"的 window，可能不是调用方期望的那个 | 单 window 应用没问题；多窗口场景需要传 windowId |

---

## 设计要点

- **不缓存 UIContext**：UIContext 会随 window 重建（旋转 / 切前后台 / resize）失效，缓存埋雷。每次 show 时 `window.getLastWindow(ctx)` 重取。
- **缓存 UIAbilityContext**：进程内稳定，EntryAbility.onCreate 一次性 set。
- **dismiss 幂等**：`dismissed` 标志防重入；`finally` 里 `content.dispose()` 释放资源；`try/catch` 包住 `closeCustomDialog` 防止系统已自动关闭时再关报错。
- **失败路径 dispose**：`openCustomDialog` 抛错时主动 `content.dispose()`，避免 content 泄漏。
- **两层结构**：PopupUtil 只管"弹出来 + 关掉"，不持有任何具体弹窗 UI；每个 `XxxPopup` 是一个静态门面，调用方零样板。

---

## 完整调用示例

```typescript
import { CustomView1Popup, CustomView1Params } from '../components/popup/CustomView1';
import { PopupOptions } from '../utils/PopupUtil';
import { DialogAlignment } from '@kit.ArkUI';

async function confirmDelete(): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    const params = new CustomView1Params();
    params.title = '确认删除';
    params.message = '此操作不可恢复';

    const handle = CustomView1Popup.show(params, {
      alignment: DialogAlignment.Center,
      isModal: true
    });
    handle.then((h) => {
      params.onConfirm = () => { h.dismiss(); resolve(true); };
      params.onCancel  = () => { h.dismiss(); resolve(false); };
    });
  });
}

// 调用
if (await confirmDelete()) {
  await deleteRecord();
}
```
