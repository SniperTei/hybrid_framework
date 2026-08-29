import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { BaseComponent, JsonObject } from '@coconut/sdk';

/**
 * 消费者自定义组件示例：设备信息（对齐 API_CONTRACT.md §4.1 的 device 字段集）。
 * methods 数组必须与 handle() 的 switch 分支一致 —— coconut.supports() 据此
 * 向 H5 透出能力。
 */
export class DeviceComponent extends BaseComponent {
  name: string = 'device';
  version: string = '1.0.0';
  description: string = 'Minimal device info component (consumer app sample)';
  methods: string[] = ['getInfo', 'getSystemInfo', 'getAppInfo'];

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getInfo':
        return this.getDeviceInfo();
      case 'getSystemInfo':
        return this.getSystemInfo();
      case 'getAppInfo':
        return this.getAppInfo();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private getDeviceInfo(): string {
    const builder = new JsonObject();
    builder.put('manufacturer', deviceInfo.manufacture);
    builder.put('brand', deviceInfo.brand);
    builder.put('model', deviceInfo.productModel);
    builder.put('osName', 'HarmonyOS');
    builder.put('osVersion', deviceInfo.osFullName);
    builder.put('platform', 'harmony');
    try {
      const d = display.getDefaultDisplaySync();
      builder.putNumber('screenWidth', d.width);
      builder.putNumber('screenHeight', d.height);
      builder.putNumber('screenScale', d.densityPixels);
    } catch (e) {
      // skip screen fields if unavailable
    }
    return this.success(builder);
  }

  private getSystemInfo(): string {
    const builder = new JsonObject();
    builder.put('osName', 'HarmonyOS');
    builder.put('osVersion', deviceInfo.osFullName);
    builder.putNumber('sdkVersion', deviceInfo.sdkApiVersion);
    builder.put('model', deviceInfo.productModel);
    builder.put('localizedModel', deviceInfo.productModel);
    return this.success(builder);
  }

  private getAppInfo(): string {
    const builder = new JsonObject();
    builder.put('appName', 'CoconutHarmonyApp');
    builder.put('packageName', 'com.sniper.coconutharmonyapp');
    builder.put('version', '1.0.0');
    builder.put('buildNumber', '1');
    builder.putBool('debug', true);
    return this.success(builder);
  }
}
