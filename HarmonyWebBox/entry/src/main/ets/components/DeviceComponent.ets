import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { BaseComponent, ComponentContext, JsonObject } from '@coconut/sdk';

/**
 * Device Component
 *
 * Provides device information using HarmonyOS APIs.
 * getInfo / getSystemInfo / getAppInfo return the standard cross-platform
 * field set (manufacturer, brand, model, osName, osVersion, platform,
 * screenWidth, screenHeight, sdkVersion, etc).
 */
export class DeviceComponent extends BaseComponent {
  name: string = 'device';
  version: string = '1.0.0';
  description: string = 'Device and system information component';
  methods: string[] = ['getInfo', 'getSystemInfo', 'getAppInfo', 'getAll'];

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getInfo':
        return this.getDeviceInfo();
      case 'getSystemInfo':
        return this.getSystemInfo();
      case 'getAppInfo':
        return this.getAppInfo();
      case 'getAll':
        return this.getAllInfo();
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
    // Screen dimensions from display manager
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
    builder.put('appName', 'CoconutSDK');
    builder.put('packageName', 'com.sniper.coconut');
    builder.put('version', '2.0.0');
    builder.put('buildNumber', '1');
    builder.putBool('debug', false);
    return this.success(builder);
  }

  private getAllInfo(): string {
    const device = new JsonObject();
    device.put('manufacturer', deviceInfo.manufacture);
    device.put('brand', deviceInfo.brand);
    device.put('model', deviceInfo.productModel);
    device.put('osName', 'HarmonyOS');
    device.put('osVersion', deviceInfo.osFullName);
    device.put('platform', 'harmony');

    const system = new JsonObject();
    system.put('osName', 'HarmonyOS');
    system.put('osVersion', deviceInfo.osFullName);
    system.putNumber('sdkVersion', deviceInfo.sdkApiVersion);
    system.put('model', deviceInfo.productModel);

    const app = new JsonObject();
    app.put('appName', 'CoconutSDK');
    app.put('version', '2.0.0');

    const root = new JsonObject();
    root.putObject('device', device);
    root.putObject('system', system);
    root.putObject('app', app);
    return this.success(root);
  }
}
