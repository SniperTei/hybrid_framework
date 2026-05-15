import { BaseComponent } from '../component/BaseComponent';
import { ComponentContext } from '../component/ComponentContext';
import { ComponentManager } from '../component/ComponentManager';
import { JsonObject, JsonParser } from '../utils/JsonHelper';

/**
 * System Component
 *
 * SDK version and capability introspection
 */
export class SystemComponent extends BaseComponent {
  name: string = 'system';
  version: string = '1.0.0';
  description: string = 'SDK version and capability introspection';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getVersion':
        return this.getVersion();
      case 'getComponentVersion':
        return this.getComponentVersion(paramsJson);
      case 'getAllComponents':
        return this.getAllComponents();
      case 'checkCapability':
        return this.checkCapability(paramsJson);
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private getVersion(): string {
    const ctx = this.getComponentContext();
    const version = ctx ? ctx.sdkVersion : '2.0.0';
    const builder = new JsonObject();
    builder.put('sdkVersion', version);
    builder.putNumber('timestamp', Date.now());
    return this.success(builder);
  }

  private getComponentVersion(paramsJson: string): string {
    const name = this.getParam(paramsJson, 'name');
    if (!name) {
      return this.error('900002', "Parameter 'name' is required");
    }
    const info = ComponentManager.getInstance().getComponentInfo(name);
    if (!info || info.length === 0) {
      return this.error('900001', `Component not found: ${name}`);
    }
    // info is already a JSON string from getComponentInfo
    return this.successJson(info);
  }

  private getAllComponents(): string {
    const info = ComponentManager.getInstance().getAllComponentsInfo();
    // info is already a JSON string
    return this.successJson(info);
  }

  private checkCapability(paramsJson: string): string {
    const method = this.getParam(paramsJson, 'method');
    if (!method) {
      return this.error('900002', "Parameter 'method' is required");
    }
    const componentName = method.split('.')[0];
    const component = ComponentManager.getInstance().getComponent(componentName);
    const isAvailable = component !== undefined;
    const isInitialized = isAvailable ? component.isInitialized : false;

    const builder = new JsonObject();
    builder.put('method', method);
    builder.putBool('available', isAvailable);
    builder.putBool('componentRegistered', isAvailable);
    builder.putBool('componentInitialized', isInitialized);
    return this.success(builder);
  }
}
