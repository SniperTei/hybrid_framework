/**
 * CustomTestDialog
 *
 * 第二个自定义原生弹窗（@Builder + openCustomDialog 实现）。
 *
 * 与 TestCustomDialog 的区别：
 *   - 顶部带主题色色条 + 关闭按钮，视觉上是一个“通知/公告”式弹窗
 *   - 只有单个“确定”按钮（TestCustomDialog 是取消/确定双按钮）
 *
 * 同样遵循鸿蒙编译器要求：@Builder、参数 class、wrapBuilder 三者必须在同一文件。
 */

/**
 * 弹窗参数。
 * onConfirm 在点击底部按钮或右上角关闭时都会被调用，由 CameraComponent 决定如何回传结果。
 */
export class CustomTestDialogParams {
  title: string = '';
  message: string = '';
  confirmText: string = '确定';
  onConfirm: () => void = () => {};
}

/**
 * 弹窗 UI：主题色顶部条 + 标题 + 消息 + 单个全宽确定按钮。
 */
@Builder
export function CustomTestDialogBuilder(params: CustomTestDialogParams) {
  Column() {
    // 顶部主题色条，作为“通知/公告”式弹窗的视觉标识
    // （圆角由父容器 .clip(true) 裁剪出来，这里不用单独设）
    Row()
      .width('100%')
      .height(6)
      .backgroundColor('#3370ff')

    Text(params.title)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1f2329')
      .margin({ top: 22, bottom: 12, left: 24, right: 24 })
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

    Button(params.confirmText)
      .type(ButtonType.Normal)
      .backgroundColor('#3370ff')
      .fontColor('#ffffff')
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .height(48)
      .borderRadius(0)
      .onClick(() => {
        params.onConfirm();
      })
  }
  .width('80%')
  .backgroundColor('#ffffff')
  .borderRadius(16)
  .clip(true)
}

/**
 * wrapBuilder 的结果，传给 ComponentContent 构造函数。
 */
export const customTestDialogBuilder: WrappedBuilder<[CustomTestDialogParams]> =
  wrapBuilder(CustomTestDialogBuilder);
