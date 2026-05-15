import { deviceInfo } from '@kit.BasicServicesKit';
import { BaseComponent } from '../component/BaseComponent';
import { JsonObject } from '../utils/JsonHelper';
import { ComponentContext } from '../component/ComponentContext';

/**
 * Device Component
 *
 * Provides device information using HarmonyOS APIs
 */
export class DeviceComponent extends BaseComponent {
  name: string = 'device';
  version: string = '1.0.0';
  description: string = 'Device and system information component';

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
    builder.put('deviceType', deviceInfo.deviceType);
    builder.put('marketName', deviceInfo.marketName);
    builder.put('productSeries', deviceInfo.productSeries);
    return this.success(builder);
  }

  private getSystemInfo(): string {
    const builder = new JsonObject();
    builder.put('osFullName', deviceInfo.osFullName);
    builder.putNumber('sdkApiVersion', deviceInfo.sdkApiVersion);
    builder.put('securityPatchTag', deviceInfo.securityPatchTag);
    builder.put('abiList', deviceInfo.abiList);
    builder.put('serial', deviceInfo.serial);
    return this.success(builder);
  }

  private getAppInfo(): string {
    const builder = new JsonObject();
    builder.put('appName', 'CoconutSDK');
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
    device.put('deviceType', deviceInfo.deviceType);

    const system = new JsonObject();
    system.put('osFullName', deviceInfo.osFullName);
    system.putNumber('sdkApiVersion', deviceInfo.sdkApiVersion);

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
