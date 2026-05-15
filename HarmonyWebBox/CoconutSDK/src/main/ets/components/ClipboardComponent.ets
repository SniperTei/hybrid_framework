import { pasteboard } from '@kit.BasicServicesKit';
import { BaseComponent } from '../component/BaseComponent';
import { Logger } from '../utils/Logger';
import { JsonObject } from '../utils/JsonHelper';

/**
 * Clipboard Component
 *
 * Provides clipboard read/write using @ohos.pasteboard
 */
export class ClipboardComponent extends BaseComponent {
  name: string = 'clipboard';
  version: string = '1.0.0';
  description: string = 'Clipboard read/write component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getText':
        return this.getText();
      case 'setText':
        return this.setText(paramsJson);
      case 'hasText':
        return this.hasText();
      case 'clear':
        return this.clear();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private async getText(): Promise<string> {
    try {
      const pasteData = await pasteboard.getSystemPasteboard().getData();
      const text = pasteData.getPrimaryText() || '';
      const builder = new JsonObject();
      builder.put('text', text);
      return this.success(builder);
    } catch (e) {
      Logger.e(this.name, `Get clipboard text failed: ${e}`);
      const builder = new JsonObject();
      builder.put('text', '');
      return this.success(builder);
    }
  }

  private async setText(paramsJson: string): Promise<string> {
    const text = this.getParam(paramsJson, 'text');
    if (!text) {
      return this.error('900001', 'Text cannot be empty');
    }

    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(pasteData);
      Logger.d(this.name, `Clipboard set: ${text.substring(0, 50)}`);
      const builder = new JsonObject();
      builder.putBool('success', true);
      return this.success(builder);
    } catch (e) {
      Logger.e(this.name, `Set clipboard text failed: ${e}`);
      return this.error('900010', `Failed to set clipboard: ${e}`);
    }
  }

  private async hasText(): Promise<string> {
    try {
      const hasData = await pasteboard.getSystemPasteboard().hasData();
      const builder = new JsonObject();
      builder.putBool('hasText', hasData);
      return this.success(builder);
    } catch (e) {
      const builder = new JsonObject();
      builder.putBool('hasText', false);
      return this.success(builder);
    }
  }

  private async clear(): Promise<string> {
    try {
      await pasteboard.getSystemPasteboard().clearData();
      const builder = new JsonObject();
      builder.putBool('success', true);
      return this.success(builder);
    } catch (e) {
      return this.error('900010', `Failed to clear clipboard: ${e}`);
    }
  }
}
