import { resourceManager } from '@kit.LocalizationKit';
import { BaseComponent, ComponentContext, Logger, JsonObject, JsonParser } from '@coconut/sdk';

/**
 * Resource Component
 *
 * H5 resource management and loading using @ohos.resourceManager
 */
export class ResourceComponent extends BaseComponent {
  name: string = 'resource';
  version: string = '1.0.0';
  description: string = 'Resource management component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'load':
        return this.load(paramsJson);
      case 'getResUrl':
        return this.getResUrl(paramsJson);
      case 'preload':
        return this.preload(paramsJson);
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private async load(paramsJson: string): Promise<string> {
    const resName = this.getParam(paramsJson, 'name');
    if (!resName) {
      return this.error('200007', 'Resource name is required');
    }

    try {
      const ctx = this.getComponentContext();
      if (!ctx) {
        return this.error('100005', 'Context not available');
      }

      const mgr = ctx.context.resourceManager;
      const content = await mgr.getRawFileContent(resName);
      const builder = new JsonObject();
      builder.put('name', resName);
      builder.putNumber('size', content.byteLength);
      builder.putBool('loaded', true);
      return this.success(builder);
    } catch (e) {
      Logger.e(this.name, `Load resource failed: ${e}`);
      return this.error('100005', `Failed to load resource: ${e}`);
    }
  }

  private getResUrl(paramsJson: string): string {
    const resName = this.getParam(paramsJson, 'name');
    if (!resName) {
      return this.error('200007', 'Resource name is required');
    }

    const builder = new JsonObject();
    builder.put('name', resName);
    builder.put('url', `$rawfile/${resName}`);
    return this.success(builder);
  }

  private async preload(paramsJson: string): Promise<string> {
    // Extract names array from paramsJson - parse as JSON array string
    const namesPattern = '"names":[';
    const namesIdx = paramsJson.indexOf(namesPattern);
    const names: string[] = [];
    if (namesIdx !== -1) {
      let i = namesIdx + namesPattern.length;
      while (i < paramsJson.length) {
        // Skip whitespace
        while (i < paramsJson.length && (paramsJson[i] === ' ' || paramsJson[i] === '\t')) {
          i++;
        }
        if (i < paramsJson.length && paramsJson[i] === '"') {
          i++;
          const start = i;
          while (i < paramsJson.length && paramsJson[i] !== '"') {
            i++;
          }
          if (i < paramsJson.length) {
            names.push(paramsJson.substring(start, i));
            i++;
          }
        }
        // Skip comma
        while (i < paramsJson.length && (paramsJson[i] === ',' || paramsJson[i] === ' ')) {
          i++;
        }
        if (i < paramsJson.length && paramsJson[i] === ']') {
          break;
        }
      }
    }

    const items: JsonObject[] = [];
    for (let idx = 0; idx < names.length; idx++) {
      const builder = new JsonObject();
      builder.put('name', names[idx]);
      builder.putBool('preloaded', true);
      items.push(builder);
    }

    const root = new JsonObject();
    root.putNumber('count', items.length);
    root.putObjectArray('results', items);
    return this.success(root);
  }
}
