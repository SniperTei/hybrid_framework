import { cameraPicker } from '@kit.CameraKit';
import { camera } from '@kit.CameraKit';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { window } from '@kit.ArkUI';
import { ComponentContent, promptAction } from '@kit.ArkUI';
import { BaseComponent, ComponentContext, Logger, JsonObject } from '@coconut/sdk';
import { testDialogBuilder, TestDialogParams } from './ui/TestCustomDialog';
import { customTestDialogBuilder, CustomTestDialogParams } from './ui/CustomTestDialog';

/**
 * Camera Component
 *
 * Provides photo capture and QR/barcode scanning via HarmonyOS system UIs.
 *
 * Functions:
 *   - takePhoto:   { frontCamera?: boolean } -> { success, uri, base64 }
 *       base64 is a data URL (image/jpeg) ready for <img src>.
 *       Returns { success: false, message } when the user cancels.
 *   - scanQRCode:  { enableAlbum?, enableMultiMode?, qrOnly? } -> { success, codeType, originalValue }
 *       qrOnly=true restricts to QR_CODE; otherwise ALL code types are recognised.
 *   - isSupported: -> { takePhoto: true, scanQRCode: true }
 *   - showDialog:  { title?, message? } -> { confirmed: boolean }
 *       Shows a native custom dialog (TestCustomDialog) built with @Builder + openCustomDialog.
 *   - showCustomDialog: { title?, message? } -> { confirmed: boolean }
 *       Shows the second native custom dialog (CustomTestDialog, single-button notice style).
 *
 * Notes:
 *   - cameraPicker and ScanKit provide their own system UI and handle the
 *     camera permission prompt themselves, so no ohos.permission.CAMERA is
 *     required in module.json5.
 */
export class CameraComponent extends BaseComponent {
  name: string = 'camera';
  version: string = '1.0.0';
  description: string = 'Camera component for photo capture and QR code scanning';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'takePhoto':
        return this.takePhoto(paramsJson);
      case 'scanQRCode':
        return this.scanQRCode(paramsJson);
      case 'isSupported':
        return this.isSupported();
      case 'showDialog':
        return this.showDialog(paramsJson);
      case 'showCustomDialog':
        return this.showCustomDialog(paramsJson);
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  /**
   * Take a photo using the system camera picker.
   */
  private async takePhoto(paramsJson: string): Promise<string> {
    const ctx = this.getComponentContext();
    if (!ctx) {
      return this.error('100005', 'Context not available');
    }

    const frontCamera = this.getBoolParam(paramsJson, 'frontCamera', false);
    const cameraPosition = frontCamera
      ? camera.CameraPosition.CAMERA_POSITION_FRONT
      : camera.CameraPosition.CAMERA_POSITION_BACK;

    const pickerProfile: cameraPicker.PickerProfile = {
      cameraPosition: cameraPosition,
      saveUri: ''
    };

    const mediaTypes: Array<cameraPicker.PickerMediaType> = [
      cameraPicker.PickerMediaType.PHOTO
    ];

    try {
      Logger.d(this.name, `Launching camera picker, front=${frontCamera}`);
      const pickerResult: cameraPicker.PickerResult =
        await cameraPicker.pick(ctx.context, mediaTypes, pickerProfile);

      // resultCode 0 = success, non-zero = cancelled / failed
      if (pickerResult.resultCode !== 0) {
        Logger.d(this.name, `Camera picker cancelled, code=${pickerResult.resultCode}`);
        const cancelBuilder = new JsonObject();
        cancelBuilder.putBool('success', false);
        cancelBuilder.put('message', 'User cancelled');
        return this.success(cancelBuilder);
      }

      const uri = pickerResult.resultUri;
      Logger.d(this.name, `Photo captured, uri=${uri}`);

      const base64 = await this.readFileAsBase64DataUrl(uri);

      const builder = new JsonObject();
      builder.putBool('success', true);
      builder.put('uri', uri);
      builder.put('base64', base64);
      return this.success(builder);
    } catch (e) {
      Logger.e(this.name, `takePhoto failed: ${e}`);
      return this.error('100005', `Failed to take photo: ${e}`);
    }
  }

  /**
   * Scan a QR code / barcode using the ScanKit default scan UI.
   */
  private async scanQRCode(paramsJson: string): Promise<string> {
    const ctx = this.getComponentContext();
    if (!ctx) {
      return this.error('100005', 'Context not available');
    }

    const enableAlbum = this.getBoolParam(paramsJson, 'enableAlbum', true);
    const enableMultiMode = this.getBoolParam(paramsJson, 'enableMultiMode', false);
    const qrOnly = this.getBoolParam(paramsJson, 'qrOnly', false);

    const scanTypes: Array<scanCore.ScanType> = qrOnly
      ? [scanCore.ScanType.QR_CODE]
      : [scanCore.ScanType.ALL];

    const options: scanBarcode.ScanOptions = {
      scanTypes: scanTypes,
      enableMultiMode: enableMultiMode,
      enableAlbum: enableAlbum
    };

    try {
      Logger.d(this.name, `Starting scan, qrOnly=${qrOnly}`);
      const result: scanBarcode.ScanResult =
        await scanBarcode.startScanForResult(ctx.context, options);

      const builder = new JsonObject();
      builder.putBool('success', true);
      builder.put('codeType', String(result.scanType));
      builder.put('originalValue', result.originalValue);
      return this.success(builder);
    } catch (e) {
      const errMsg = `${e}`;
      Logger.e(this.name, `scanQRCode failed: ${errMsg}`);
      // ScanKit surfaces user cancellation as an error
      if (errMsg.indexOf('cancel') !== -1 || errMsg.indexOf('Cancel') !== -1) {
        const cancelBuilder = new JsonObject();
        cancelBuilder.putBool('success', false);
        cancelBuilder.put('message', 'User cancelled');
        return this.success(cancelBuilder);
      }
      return this.error('100005', `Failed to scan QR code: ${errMsg}`);
    }
  }

  /**
   * Report capability support.
   */
  private isSupported(): string {
    const builder = new JsonObject();
    builder.putBool('takePhoto', true);
    builder.putBool('scanQRCode', true);
    return this.success(builder);
  }

  /**
   * Show a native custom dialog (TestCustomDialog) via @Builder + openCustomDialog.
   *
   * Bridge 组件是普通 TS 类，拿不到 CustomDialogController；所以走 UIContext +
   * ComponentContent + PromptAction.openCustomDialog 路径（API 12+ 支持非页面代码调用）。
   */
  private async showDialog(paramsJson: string): Promise<string> {
    const ctx = this.getComponentContext();
    if (!ctx) {
      return this.error('100005', 'Context not available');
    }

    const title = this.getParam(paramsJson, 'title', '提示');
    const message = this.getParam(paramsJson, 'message', '');
    const confirmText = this.getParam(paramsJson, 'confirmText', '确定');
    const cancelText = this.getParam(paramsJson, 'cancelText', '取消');

    try {
      const win = await window.getLastWindow(ctx.context);
      const uiContext = win.getUIContext();

      // 前向引用：回调里要用 content 关闭弹窗，但 content 又要用 params 构造，
      // 所以先声明为 null，构造完再赋值。
      let content: ComponentContent<TestDialogParams> | null = null;

      return new Promise<string>((resolve) => {
        const params = new TestDialogParams();
        params.title = title;
        params.message = message;
        params.confirmText = confirmText;
        params.cancelText = cancelText;

        let settled = false;
        const closeAndResolve = (confirmed: boolean) => {
          if (settled || !content) {
            return;
          }
          settled = true;
          uiContext.getPromptAction().closeCustomDialog(content);
          content.dispose();

          const builder = new JsonObject();
          builder.putBool('confirmed', confirmed);
          resolve(this.success(builder));
        };

        params.onConfirm = () => { closeAndResolve(true); };
        params.onCancel = () => { closeAndResolve(false); };

        content = new ComponentContent<TestDialogParams>(
          uiContext,
          testDialogBuilder,
          params
        );

        const options: promptAction.BaseDialogOptions = {
          alignment: DialogAlignment.Center,
          isModal: true
        };

        uiContext.getPromptAction().openCustomDialog(content, options).then(() => {
          Logger.d(this.name, 'TestCustomDialog opened');
        }).catch((e: Error) => {
          Logger.e(this.name, `openCustomDialog failed: ${e}`);
          if (!settled) {
            settled = true;
            resolve(this.error('100005', `Failed to open dialog: ${e}`));
          }
        });
      });
    } catch (e) {
      Logger.e(this.name, `showDialog failed: ${e}`);
      return this.error('100005', `Failed to show dialog: ${e}`);
    }
  }

  /**
   * Show the second native custom dialog (CustomTestDialog) via @Builder + openCustomDialog.
   *
   * 与 showDialog 同一路径（UIContext + ComponentContent + PromptAction.openCustomDialog），
   * 只是换成了 CustomTestDialog 的 builder 和参数类（单按钮通知样式）。
   */
  private async showCustomDialog(paramsJson: string): Promise<string> {
    const ctx = this.getComponentContext();
    if (!ctx) {
      return this.error('100005', 'Context not available');
    }

    const title = this.getParam(paramsJson, 'title', '提示');
    const message = this.getParam(paramsJson, 'message', '');
    const confirmText = this.getParam(paramsJson, 'confirmText', '确定');

    try {
      const win = await window.getLastWindow(ctx.context);
      const uiContext = win.getUIContext();

      let content: ComponentContent<CustomTestDialogParams> | null = null;

      return new Promise<string>((resolve) => {
        const params = new CustomTestDialogParams();
        params.title = title;
        params.message = message;
        params.confirmText = confirmText;

        let settled = false;
        const closeAndResolve = () => {
          if (settled || !content) {
            return;
          }
          settled = true;
          uiContext.getPromptAction().closeCustomDialog(content);
          content.dispose();

          const builder = new JsonObject();
          builder.putBool('confirmed', true);
          resolve(this.success(builder));
        };

        params.onConfirm = closeAndResolve;

        content = new ComponentContent<CustomTestDialogParams>(
          uiContext,
          customTestDialogBuilder,
          params
        );

        const options: promptAction.BaseDialogOptions = {
          alignment: DialogAlignment.Center,
          isModal: true
        };

        uiContext.getPromptAction().openCustomDialog(content, options).then(() => {
          Logger.d(this.name, 'CustomTestDialog opened');
        }).catch((e: Error) => {
          Logger.e(this.name, `openCustomDialog failed: ${e}`);
          if (!settled) {
            settled = true;
            resolve(this.error('100005', `Failed to open dialog: ${e}`));
          }
        });
      });
    } catch (e) {
      Logger.e(this.name, `showCustomDialog failed: ${e}`);
      return this.error('100005', `Failed to show custom dialog: ${e}`);
    }
  }

  /**
   * Read a file by URI and return a base64 data URL (image/jpeg).
   */
  private async readFileAsBase64DataUrl(uri: string): Promise<string> {
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(file.fd);
      const size = stat.size;
      const arrayBuffer = new ArrayBuffer(size);
      fileIo.readSync(file.fd, arrayBuffer);
      const uint8 = new Uint8Array(arrayBuffer);
      const base64Helper = new util.Base64Helper();
      const base64Str = base64Helper.encodeToString(uint8);
      return `data:image/jpeg;base64,${base64Str}`;
    } catch (e) {
      Logger.e(this.name, `readFileAsBase64 failed: ${e}`);
      return '';
    } finally {
      if (file) {
        try {
          fileIo.closeSync(file);
        } catch (e) {
          Logger.w(this.name, `closeSync failed: ${e}`);
        }
      }
    }
  }
}
