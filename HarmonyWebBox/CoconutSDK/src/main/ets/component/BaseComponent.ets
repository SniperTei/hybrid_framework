import { CoconutPlugin } from './CoconutPlugin';
import { ComponentContext } from './ComponentContext';
import { ComponentException } from './ComponentException';
import { Logger } from '../utils/Logger';
import { JsonParser, JsonObject } from '../utils/JsonHelper';

/**
 * Base Component Class
 *
 * All components should extend this class.
 * Provides common functionality and utilities.
 */
export abstract class BaseComponent implements CoconutPlugin {
  abstract name: string;
  abstract version: string;
  description: string = '';
  dependencies: string[] = [];
  abstract handle(functionName: string, paramsJson: string): Promise<string>;

  private _initialized: boolean = false;

  get isInitialized(): boolean {
    return this._initialized;
  }

  protected context: Object | null = null;

  async init(context: Object): Promise<void> {
    if (this._initialized) {
      Logger.w(this.name, 'Component already initialized');
      return;
    }

    Logger.d(this.name, 'Initializing component...');
    this.context = context;
    await this.onInit(context);
    this._initialized = true;
    Logger.d(this.name, 'Component initialized');
  }

  async cleanup(): Promise<void> {
    Logger.d(this.name, 'Cleaning up component...');
    await this.onCleanup();
    this._initialized = false;
    this.context = null;
    Logger.d(this.name, 'Component cleaned up');
  }

  protected async onInit(context: Object): Promise<void> {
    // Override in subclasses
  }

  protected async onCleanup(): Promise<void> {
    // Override in subclasses
  }

  /**
   * Get the ComponentContext from the stored Object context
   */
  protected getComponentContext(): ComponentContext | null {
    if (this.context instanceof ComponentContext) {
      return this.context as ComponentContext;
    }
    return null;
  }

  /**
   * Get parameter value as string from paramsJson
   */
  protected getParam(paramsJson: string, key: string, defaultValue: string = ''): string {
    return JsonParser.getString(paramsJson, key, defaultValue);
  }

  /**
   * Get parameter as number from paramsJson
   */
  protected getIntParam(paramsJson: string, key: string, defaultValue: number = 0): number {
    return JsonParser.getNumber(paramsJson, key, defaultValue);
  }

  /**
   * Get parameter as boolean from paramsJson
   */
  protected getBoolParam(paramsJson: string, key: string, defaultValue: boolean = false): boolean {
    return JsonParser.getBool(paramsJson, key, defaultValue);
  }

  /**
   * Check if a key exists in paramsJson
   */
  protected hasParam(paramsJson: string, key: string): boolean {
    const pattern = `"${key}":`;
    return paramsJson.indexOf(pattern) !== -1;
  }

  /**
   * Build success result - returns the JSON string as-is
   */
  protected successJson(json: string): string {
    return json;
  }

  /**
   * Build success result using JsonObject builder
   */
  protected success(builder: JsonObject): string {
    return builder.build();
  }

  /**
   * Throw component error
   */
  protected error(code: string, message: string): string {
    throw new ComponentException(code, message);
  }

  /**
   * Throw function not supported error
   */
  protected functionNotSupportedError(functionName: string): string {
    throw new ComponentException('200002', `Function not supported: ${functionName}`);
  }
}
