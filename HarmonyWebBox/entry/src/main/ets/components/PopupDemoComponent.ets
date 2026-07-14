import { BaseComponent, JsonObject } from '@coconut/sdk';
import { CustomView1Popup, CustomView1Params } from './popup/CustomView1';
import { CustomDialog2Popup, CustomDialog2Params } from './popup/CustomDialog2';

/**
 * PopupDemo Component（演示用，可随时删除）
 *
 * 演示从 Bridge 组件（非页面、非 @Component 的普通 TS 类）通过 PopupUtil 调起自定义弹窗。
 * 这正是 PopupUtil 解决的核心场景：以前只有 CameraComponent 内联样板能做，现在任何组件一行就够。
 *
 * Functions:
 *   - popup.view1:        { title?, message? } -> { confirmed }
 *       双按钮确认弹窗。验证最常见 case。
 *   - popup.dialog2:      { title?, message?, placeholder? } -> { confirmed, value }
 *       带输入框弹窗。验证回调里把输入值回传给 Bridge。
 *   - popup.autoDismiss:  {} -> { success }
 *       点确认后程序化关闭（onConfirm 里调 handle.dismiss()）。
 *   - popup.stack:        {} -> { success }
 *       连续开两个弹窗，验证多弹窗叠加（ dismissed 各自独立）。
 */
export class PopupDemoComponent extends BaseComponent {
  name: string = 'popup';
  version: string = '1.0.0';
  description: string = 'PopupUtil demo component (temporary)';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'view1':
        return this.demoView1(paramsJson);
      case 'dialog2':
        return this.demoDialog2(paramsJson);
      case 'autoDismiss':
        return this.demoAutoDismiss();
      case 'stack':
        return this.demoStack();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  /** 双按钮确认弹窗。 */
  private async demoView1(paramsJson: string): Promise<string> {
    const title = this.getParam(paramsJson, 'title', '确认操作');
    const message = this.getParam(paramsJson, 'message', '这是一个 CustomView1 双按钮弹窗');

    return new Promise<string>((resolve) => {
      const params = new CustomView1Params();
      params.title = title;
      params.message = message;

      const handle = CustomView1Popup.show(params);
      handle.then((h) => {
        params.onConfirm = () => {
          h.dismiss();
          resolve(this.success(this.packConfirmed(true)));
        };
        params.onCancel = () => {
          h.dismiss();
          resolve(this.success(this.packConfirmed(false)));
        };
      });
    });
  }

  /** 带输入框弹窗。 */
  private async demoDialog2(paramsJson: string): Promise<string> {
    const title = this.getParam(paramsJson, 'title', '请输入');
    const message = this.getParam(paramsJson, 'message', '演示 CustomDialog2 输入框弹窗');
    const placeholder = this.getParam(paramsJson, 'placeholder', '请输入内容');

    return new Promise<string>((resolve) => {
      const params = new CustomDialog2Params();
      params.title = title;
      params.message = message;
      params.inputPlaceholder = placeholder;

      const handle = CustomDialog2Popup.show(params);
      handle.then((h) => {
        params.onConfirm = (value: string) => {
          h.dismiss();
          const builder = new JsonObject();
          builder.putBool('confirmed', true);
          builder.put('value', value);
          resolve(this.success(builder));
        };
        params.onCancel = () => {
          h.dismiss();
          const builder = new JsonObject();
          builder.putBool('confirmed', false);
          builder.put('value', '');
          resolve(this.success(builder));
        };
      });
    });
  }

  /** 程序化关闭：onConfirm 里调 handle.dismiss()。 */
  private async demoAutoDismiss(): Promise<string> {
    return new Promise<string>((resolve) => {
      const params = new CustomView1Params();
      params.title = '程序化关闭';
      params.message = '点"延迟关闭"按钮，会先 1.5 秒后再 dismiss（验证 dismiss 由代码触发）';
      params.confirmText = '延迟关闭';
      params.cancelText = '直接关';

      const handle = CustomView1Popup.show(params);
      handle.then((h) => {
        params.onConfirm = () => {
          // 故意延迟 dismiss，让调用方看出"是代码关的，不是系统关的"
          setTimeout(() => {
            h.dismiss().then(() => resolve(this.success(this.packOk())));
          }, 1500);
        };
        params.onCancel = () => {
          h.dismiss();
          resolve(this.success(this.packOk()));
        };
      });
    });
  }

  /** 多弹窗叠加：连续开两个，依次关闭。 */
  private async demoStack(): Promise<string> {
    const p1 = new CustomView1Params();
    p1.title = '弹窗 1';
    p1.message = '先弹这个，1 秒后弹第二个';

    const h1 = await CustomView1Popup.show(p1);

    setTimeout(async () => {
      const p2 = new CustomDialog2Params();
      p2.title = '弹窗 2';
      p2.message = '两个弹窗现在同时显示。点关闭即可。';
      const h2 = await CustomDialog2Popup.show(p2);
      p2.onConfirm = () => { h2.dismiss(); };
      p2.onCancel = () => { h2.dismiss(); };
      p1.onConfirm = () => { h1.dismiss(); };
      p1.onCancel = () => { h1.dismiss(); };
    }, 1000);

    // demoStack 立即返回，弹窗交给回调自管
    return this.success(this.packOk());
  }

  // ---------- helpers ----------

  private packConfirmed(confirmed: boolean): JsonObject {
    const b = new JsonObject();
    b.putBool('confirmed', confirmed);
    return b;
  }

  private packOk(): JsonObject {
    const b = new JsonObject();
    b.putBool('success', true);
    return b;
  }
}
