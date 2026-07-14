import { promptAction } from '@kit.ArkUI';
import { BaseComponent, JsonObject } from '@coconut/sdk';

/**
 * Dialog Component
 *
 * Provides native dialogs using @ohos.promptAction
 */
export class DialogComponent extends BaseComponent {
  name: string = 'dialog';
  version: string = '1.0.0';
  description: string = 'Native dialog and toast component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'alert':
        return this.alert(paramsJson);
      case 'confirm':
        return this.confirm(paramsJson);
      case 'prompt':
        return this.prompt(paramsJson);
      case 'toast':
        return this.toast(paramsJson);
      case 'showLoading':
        return this.showLoading(paramsJson);
      case 'hideLoading':
        return this.hideLoading();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private async alert(paramsJson: string): Promise<string> {
    const title = this.getParam(paramsJson, 'title', '提示');
    const message = this.getParam(paramsJson, 'message', '');
    const buttonText = this.getParam(paramsJson, 'buttonText', '确定');

    return new Promise<string>((resolve) => {
      promptAction.showDialog({
        title: title,
        message: message,
        buttons: [{ text: buttonText, color: '#007DFF' }]
      }).then(() => {
        const builder = new JsonObject();
        builder.putBool('confirmed', true);
        resolve(this.success(builder));
      }).catch(() => {
        const builder = new JsonObject();
        builder.putBool('confirmed', false);
        resolve(this.success(builder));
      });
    });
  }

  private async confirm(paramsJson: string): Promise<string> {
    const title = this.getParam(paramsJson, 'title', '确认');
    const message = this.getParam(paramsJson, 'message', '');
    const confirmText = this.getParam(paramsJson, 'confirmText', '确定');
    const cancelText = this.getParam(paramsJson, 'cancelText', '取消');

    return new Promise<string>((resolve) => {
      promptAction.showDialog({
        title: title,
        message: message,
        buttons: [
          { text: cancelText, color: '#666666' },
          { text: confirmText, color: '#007DFF' }
        ]
      }).then((result) => {
        // Index 0 = cancel, Index 1 = OK
        const builder = new JsonObject();
        builder.putBool('confirmed', result.index === 1);
        resolve(this.success(builder));
      }).catch(() => {
        const builder = new JsonObject();
        builder.putBool('confirmed', false);
        resolve(this.success(builder));
      });
    });
  }

  private async prompt(paramsJson: string): Promise<string> {
    const title = this.getParam(paramsJson, 'title', '输入');
    const message = this.getParam(paramsJson, 'message', '');
    const placeholder = this.getParam(paramsJson, 'placeholder', '');
    const confirmText = this.getParam(paramsJson, 'confirmText', '确定');
    const cancelText = this.getParam(paramsJson, 'cancelText', '取消');

    return new Promise<string>((resolve) => {
      promptAction.showDialog({
        title: title,
        message: message,
        buttons: [
          { text: cancelText, color: '#666666' },
          { text: confirmText, color: '#007DFF' }
        ]
      }).then((result) => {
        const builder = new JsonObject();
        builder.putBool('confirmed', result.index === 1);
        builder.put('input', '');
        resolve(this.success(builder));
      }).catch(() => {
        const builder = new JsonObject();
        builder.putBool('confirmed', false);
        builder.put('input', '');
        resolve(this.success(builder));
      });
    });
  }

  private toast(paramsJson: string): string {
    const message = this.getParam(paramsJson, 'message', '');
    const durationSec = this.getIntParam(paramsJson, 'duration', 2);

    if (!message) {
      return this.error('200007', 'Message cannot be empty');
    }

    promptAction.showToast({
      message: message,
      duration: durationSec * 1000
    });

    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private showLoading(paramsJson: string): string {
    const message = this.getParam(paramsJson, 'message', '加载中...');
    promptAction.showToast({ message: message, duration: 10000 });
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private hideLoading(): string {
    // HarmonyOS doesn't have a direct hideLoading API
    // Toast auto-dismisses
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }
}
