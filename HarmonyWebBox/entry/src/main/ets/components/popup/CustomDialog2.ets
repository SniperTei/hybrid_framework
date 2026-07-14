import { PopupUtil, PopupOptions, PopupHandle } from '../../utils/PopupUtil';

/**
 * CustomDialog2
 *
 * 带输入框的弹窗样式（标题 + 消息 + TextInput + 取消/确定）。
 * UI 占位版本：结构完整、可编译可弹，具体视觉细节按需调整。
 *
 * 四件套结构参见 CustomView1.ets。
 */

/**
 * 弹窗参数。inputPlaceholder / initialValue 控制输入框；onConfirm 把输入值回传调用方。
 */
export class CustomDialog2Params {
  title: string = '';
  message: string = '';
  inputPlaceholder: string = '';
  initialValue: string = '';
  confirmText: string = '确定';
  cancelText: string = '取消';
  /** 用户点确定时触发，参数是输入框当前值。 */
  onConfirm: (value: string) => void = () => {};
  onCancel: () => void = () => {};
}

/**
 * 弹窗 UI：标题 + 消息 + TextInput + 取消/确定双按钮。
 *
 * 注意：TextInput 的状态通过 @State 语义需要一个 @Component 容器才能双向绑定；
 * 这里 @Builder 内通过 params 上的初始值单向设置，回调时读取最新值由调用方自行
 * 处理（如需双向绑定，可后续在 @Builder 内嵌一个 @Component 子组件）。
 */
@Builder
function CustomDialog2Builder(params: CustomDialog2Params) {
  Column() {
    Text(params.title)
      .fontSize(18)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1f2329')
      .margin({ top: 24, bottom: 8, left: 24, right: 24 })
      .width('100%')
      .textAlign(TextAlign.Center)

    Text(params.message)
      .fontSize(14)
      .fontColor('#6b7280')
      .lineHeight(20)
      .margin({ bottom: 16, left: 24, right: 24 })
      .width('100%')
      .textAlign(TextAlign.Center)

    TextInput({ text: params.initialValue, placeholder: params.inputPlaceholder })
      .height(44)
      .fontSize(14)
      .borderRadius(8)
      .backgroundColor('#f5f6f7')
      .margin({ left: 24, right: 24, bottom: 24 })
      .onChange((value: string) => {
        params.initialValue = value;
      })

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
          params.onConfirm(params.initialValue);
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 16 })
  }
  .width('80%')
  .backgroundColor('#ffffff')
  .borderRadius(16)
}

/** wrapBuilder 常量。 */
const customDialog2Builder: WrappedBuilder<[CustomDialog2Params]> =
  wrapBuilder(CustomDialog2Builder);

/**
 * 门面类。调用方示例：
 *
 *   const handle = await CustomDialog2Popup.show({
 *     title: '重命名',
 *     message: '请输入新名称',
 *     inputPlaceholder: '输入名称',
 *     onConfirm: (value) => { save(value); handle.dismiss(); },
 *     onCancel:  () => { handle.dismiss(); }
 *   });
 */
export class CustomDialog2Popup {
  static show(params: CustomDialog2Params, options?: PopupOptions): Promise<PopupHandle> {
    return PopupUtil.show(customDialog2Builder, params, options);
  }
}
