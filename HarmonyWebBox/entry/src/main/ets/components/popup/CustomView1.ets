import { PopupUtil, PopupOptions, PopupHandle } from '../../utils/PopupUtil';

/**
 * CustomView1
 *
 * 标准双按钮弹窗模板（标题 + 消息 + 取消/确定）。
 *
 * 文件结构四件套（鸿蒙 ArkUI 约束）：
 *   1. CustomView1Params       - 参数 class（必须是 class，不能是 interface/object literal）
 *   2. CustomView1Builder      - @Builder 全局函数，画弹窗 UI
 *   3. customView1Builder      - wrapBuilder 常量，必须与 @Builder 同文件
 *   4. CustomView1Popup        - 门面类，调用方只跟这个打交道
 *
 * 新增弹窗标准步骤：
 *   1. 复制本文件 → 改名为 XxxPopup.ets，放 components/popup/ 下。
 *   2. 改这四件套的命名 + 参数字段 + @Builder 内的 UI。
 *   3. 调用方 import { XxxPopup } 后 await XxxPopup.show({ ... })。
 *   无需注册、无需改 PopupUtil、无需改任何配置。
 */

/**
 * 弹窗参数。字段 = 调用方传入 + 弹窗内回调。
 */
export class CustomView1Params {
  title: string = '';
  message: string = '';
  confirmText: string = '确定';
  cancelText: string = '取消';
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
}

/**
 * 弹窗 UI：白底圆角卡片，标题 + 消息 + 取消/确定双按钮。
 */
@Builder
function CustomView1Builder(params: CustomView1Params) {
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
}

/** wrapBuilder 常量，传给 ComponentContent 构造函数。 */
const customView1Builder: WrappedBuilder<[CustomView1Params]> =
  wrapBuilder(CustomView1Builder);

/**
 * 门面类。调用方示例：
 *
 *   const handle = await CustomView1Popup.show({
 *     title: '提示',
 *     message: '确认删除？',
 *     onConfirm: () => { handle.dismiss(); },
 *     onCancel:  () => { handle.dismiss(); }
 *   });
 */
export class CustomView1Popup {
  static show(params: CustomView1Params, options?: PopupOptions): Promise<PopupHandle> {
    return PopupUtil.show(customView1Builder, params, options);
  }
}
