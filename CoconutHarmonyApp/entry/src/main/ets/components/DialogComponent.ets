import { ComponentContent, promptAction, UIContext, window } from '@kit.ArkUI';
import { BaseComponent, JsonObject } from '@coconut/sdk';

/**
 * Loading 弹窗的 @Builder 参数（ArkTS 严格模式要求显式 class 类型）
 */
class LoadingParams {
  message: string = '';

  constructor(message: string) {
    this.message = message;
  }
}

/**
 * Loading 弹窗内容（模块级 @Builder，供 wrapBuilder 包装）
 * 样式对齐 LoadingOverlay：半透明黑卡片 + LoadingProgress + 文字
 */
@Builder
function loadingBuilder(params: LoadingParams) {
  Column() {
    LoadingProgress()
      .width(48)
      .height(48)
      .color('#FFFFFF')

    if (params.message.length > 0) {
      Text(params.message)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .margin({ top: 12 })
    }
  }
  .padding(24)
  .backgroundColor('rgba(0,0,0,0.8)')
  .borderRadius(12)
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center)
}

/**
 * Dialog Component
 *
 * Provides native dialogs using @ohos.promptAction.
 * Loading 用 UIContext PromptAction openCustomDialog + ComponentContent 真实现，
 * hideLoading 时 closeCustomDialog。
 */
export class DialogComponent extends BaseComponent {
  name: string = 'dialog';
  version: string = '1.0.0';
  description: string = 'Native dialog and toast component';
  methods: string[] = ['alert', 'confirm', 'toast', 'showLoading', 'hideLoading'];

  private loadingContent: ComponentContent<LoadingParams> | null = null;
  private loadingUIContext: UIContext | null = null;

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'alert':
        return this.alert(paramsJson);
      case 'confirm':
        return this.confirm(paramsJson);
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

    try {
      await promptAction.showDialog({
        title: title,
        message: message,
        buttons: [{ text: buttonText, color: '#007DFF' }]
      });
      const builder = new JsonObject();
      builder.putBool('confirmed', true);
      return this.success(builder);
    } catch (e) {
      const builder = new JsonObject();
      builder.putBool('confirmed', false);
      return this.success(builder);
    }
  }

  private async confirm(paramsJson: string): Promise<string> {
    const title = this.getParam(paramsJson, 'title', '确认');
    const message = this.getParam(paramsJson, 'message', '');
    const confirmText = this.getParam(paramsJson, 'confirmText', '确定');
    const cancelText = this.getParam(paramsJson, 'cancelText', '取消');

    try {
      const result = await promptAction.showDialog({
        title: title,
        message: message,
        buttons: [
          { text: cancelText, color: '#666666' },
          { text: confirmText, color: '#007DFF' }
        ]
      });
      // Index 0 = cancel, Index 1 = OK
      const builder = new JsonObject();
      builder.putBool('confirmed', result.index === 1);
      return this.success(builder);
    } catch (e) {
      const builder = new JsonObject();
      builder.putBool('confirmed', false);
      return this.success(builder);
    }
  }

  private toast(paramsJson: string): string {
    const message = this.getParam(paramsJson, 'message', '');
    const durationSec = this.getIntParam(paramsJson, 'duration', 2);

    if (!message) {
      return this.error('200007', 'Message cannot be empty');
    }

    // position 参数 Harmony toast 不支持，静默忽略（契约注明）
    promptAction.showToast({
      message: message,
      duration: durationSec * 1000
    });

    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private async showLoading(paramsJson: string): Promise<string> {
    const message = this.getParam(paramsJson, 'message', '加载中...');

    const ctx = this.getComponentContext();
    if (!ctx) {
      return this.error('100005', 'No host context available');
    }
    try {
      // UIAbility.windowStage 非 public（编译器报错踩坑），改走 window.getLastWindow
      const win = await window.getLastWindow(ctx.context);
      const uiContext = win.getUIContext();
      // 先关旧的，避免重复叠加
      this.closeLoadingInternal();
      const content =
        new ComponentContent<LoadingParams>(uiContext, wrapBuilder(loadingBuilder), new LoadingParams(message));
      await uiContext.getPromptAction().openCustomDialog(content);
      this.loadingContent = content;
      this.loadingUIContext = uiContext;
      const builder = new JsonObject();
      builder.putBool('success', true);
      return this.success(builder);
    } catch (e) {
      return this.error('100005', `Failed to open loading dialog: ${e}`);
    }
  }

  private async hideLoading(): Promise<string> {
    this.closeLoadingInternal();
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private closeLoadingInternal(): void {
    if (this.loadingContent && this.loadingUIContext) {
      const content = this.loadingContent;
      const uiContext = this.loadingUIContext;
      this.loadingContent = null;
      this.loadingUIContext = null;
      try {
        uiContext.getPromptAction().closeCustomDialog(content)
          .then(() => {
            content.dispose();
          })
          .catch(() => {
            // dialog 已关闭/窗口不可用时静默失败
          });
      } catch (e) {
        // 同步异常同样静默
      }
    }
  }

  protected async onCleanup(): Promise<void> {
    this.closeLoadingInternal();
  }
}
