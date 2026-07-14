/**
 * TestCustomDialog
 *
 * 自定义原生弹窗（@Builder + openCustomDialog 实现）。
 *
 * 为什么不用 @CustomDialog + CustomDialogController？
 *   Bridge 组件（CameraComponent）是普通 TypeScript 类，不是 ArkUI 页面组件（@Component）。
 *   CustomDialogController 必须是页面组件的成员变量才能使用，所以在 Bridge 组件里拿不到。
 *   @Builder + openCustomDialog 通过 UIContext 调用，API 12+ 明确支持在非页面代码中使用。
 *
 * 三个东西必须在同一文件里（鸿蒙编译器要求 @Builder 和 wrapBuilder 在一起）：
 *   1. TestDialogParams       - 参数类（必须是 class，不能是 object literal，否则 ArkTS 严格模式报错）
 *   2. TestCustomDialogBuilder - @Builder 全局函数，画弹窗 UI
 *   3. testDialogBuilder      - wrapBuilder 的结果，导出给 CameraComponent 使用
 */

/**
 * 弹窗参数。
 * 回调（onConfirm / onCancel）作为字段传入，按钮点击时调用它们，把结果回传给 CameraComponent。
 */
export class TestDialogParams {
  title: string = '';
  message: string = '';
  confirmText: string = '确定';
  cancelText: string = '取消';
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
}

/**
 * 弹窗 UI：白底圆角卡片，标题 + 消息 + 取消/确定两个按钮。
 */
@Builder
export function TestCustomDialogBuilder(params: TestDialogParams) {
  Column() {
    Text(params.title)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1f2329')
      .margin({ top: 24, bottom: 12, left: 24, right: 24 })
      .width('100%')
      .textAlign(TextAlign.Center)

    Text(params.message)
      .fontSize(14)
      .fontColor('#6b7280')
      .lineHeight(20)
      .margin({ bottom: 24, left: 24, right: 24 })
      .width('100%')
      .textAlign(TextAlign.Center)

    Divider()
      .color('#f0f0f0')
      .width('100%')

    Row() {
      Button(params.cancelText)
        .type(ButtonType.Normal)
        .backgroundColor('#f2f3f5')
        .fontColor('#6b7280')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .height(44)
        .borderRadius(8)
        .margin({ left: 16, right: 8 })
        .onClick(() => {
          params.onCancel();
        })

      Button(params.confirmText)
        .type(ButtonType.Normal)
        .backgroundColor('#3370ff')
        .fontColor('#ffffff')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .height(44)
        .borderRadius(8)
        .margin({ left: 8, right: 16 })
        .onClick(() => {
          params.onConfirm();
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 16 })
  }
  .width('80%')
  .backgroundColor('#ffffff')
  .borderRadius(16)
  .padding({ bottom: 0 })
}

/**
 * wrapBuilder 的结果，传给 ComponentContent 构造函数。
 */
export const testDialogBuilder: WrappedBuilder<[TestDialogParams]> =
  wrapBuilder(TestCustomDialogBuilder);
