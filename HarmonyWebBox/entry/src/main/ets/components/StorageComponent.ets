import { preferences } from '@kit.ArkData';
import { BaseComponent, ComponentContext, Logger, JsonObject } from '@coconut/sdk';

/**
 * Storage Component
 *
 * Provides persistent storage using @ohos.data.preferences
 */
export class StorageComponent extends BaseComponent {
  name: string = 'storage';
  version: string = '1.0.0';
  description: string = 'Persistent storage component';
  methods: string[] = ['setItem', 'getItem', 'removeItem', 'clear', 'getAllKeys', 'getSize'];

  private store: preferences.Preferences | null = null;
  private keySet: Set<string> = new Set();

  protected async onInit(): Promise<void> {
    const ctx = this.getComponentContext();
    if (ctx) {
      try {
        this.store = await preferences.getPreferences(ctx.context, 'CoconutStorage');
        Logger.d(this.name, 'Storage initialized');
      } catch (e) {
        Logger.e(this.name, `Failed to init storage: ${e}`);
      }
    }
  }

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'setItem':
        return this.setItem(paramsJson);
      case 'getItem':
        return this.getItem(paramsJson);
      case 'removeItem':
        return this.removeItem(paramsJson);
      case 'clear':
        return this.clear();
      case 'getAllKeys':
        return this.getAllKeys();
      case 'getSize':
        return this.getSize();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private async setItem(paramsJson: string): Promise<string> {
    const key = this.getParam(paramsJson, 'key');
    const value = this.getParam(paramsJson, 'value');
    if (!key) {
      return this.error('200007', 'Key cannot be empty');
    }
    if (this.store) {
      await this.store.put(key, value);
      await this.store.flush();
      this.keySet.add(key);
    }
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private async getItem(paramsJson: string): Promise<string> {
    const key = this.getParam(paramsJson, 'key');
    if (!key) {
      return this.error('200007', 'Key cannot be empty');
    }
    const rawValue = this.store ? await this.store.get(key, '') : '';
    const value = typeof rawValue === 'string' ? rawValue : '';
    const builder = new JsonObject();
    builder.put('value', value);
    builder.putBool('exists', value !== '');
    return this.success(builder);
  }

  private async removeItem(paramsJson: string): Promise<string> {
    const key = this.getParam(paramsJson, 'key');
    if (!key) {
      return this.error('200007', 'Key cannot be empty');
    }
    if (this.store) {
      await this.store.delete(key);
      await this.store.flush();
      this.keySet.delete(key);
    }
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private async clear(): Promise<string> {
    if (this.store) {
      await this.store.clear();
      await this.store.flush();
      this.keySet.clear();
    }
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  private async getAllKeys(): Promise<string> {
    const keys: string[] = [];
    this.keySet.forEach((key: string) => {
      keys.push(key);
    });
    const builder = new JsonObject();
    builder.putStringArray('keys', keys);
    builder.putNumber('count', keys.length);
    return this.success(builder);
  }

  private async getSize(): Promise<string> {
    const count = this.keySet.size;
    const builder = new JsonObject();
    builder.putNumber('count', count);
    builder.putNumber('size', count * 100); // Approximate size in bytes
    return this.success(builder);
  }

  protected async onCleanup(): Promise<void> {
    this.store = null;
  }
}
