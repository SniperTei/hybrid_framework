import { common, bundleManager } from '@kit.AbilityKit';
import { CoconutConfig } from './ets/config/CoconutConfig';
import { ComponentManager } from './ets/component/ComponentManager';
import { ComponentContext } from './ets/component/ComponentContext';
import { CoconutBridgeImpl } from './ets/bridge/CoconutBridgeImpl';
import { BridgeTokenManager } from './ets/bridge/BridgeTokenManager';
import { CoconutPlugin } from './ets/component/CoconutPlugin';
import { Logger } from './ets/utils/Logger';
import { JsonObject } from './ets/utils/JsonHelper';

/**
 * Coconut SDK Main Entry Point
 *
 * Usage:
 * ```typescript
 * CoconutSDK.initialize(context)
 * CoconutSDK.configure(config => {
 *   config.isDebugMode = true
 * })
 * CoconutSDK.registerComponents([...])
 * ```
 */
export class CoconutSDK {
  private static _isInitialized: boolean = false;
  private static _config: CoconutConfig = new CoconutConfig();
  private static _bridge: CoconutBridgeImpl | null = null;

  static get isInitialized(): boolean {
    return CoconutSDK._isInitialized;
  }

  static get config(): CoconutConfig {
    return CoconutSDK._config;
  }

  static get bridge(): CoconutBridgeImpl | null {
    return CoconutSDK._bridge;
  }

  /**
   * Initialize SDK
   */
  static initialize(context: common.UIAbilityContext): void {
    if (CoconutSDK._isInitialized) {
      Logger.w('CoconutSDK', 'Already initialized');
      return;
    }

    const componentContext = new ComponentContext(context);
    ComponentManager.getInstance().setContext(componentContext);
    CoconutSDK._bridge = new CoconutBridgeImpl(ComponentManager.getInstance());

    CoconutSDK._isInitialized = true;
    Logger.i('CoconutSDK', `CoconutSDK v${CoconutSDK.getVersion()} initialized`);
  }

  /**
   * Configure SDK
   */
  static configure(block: (config: CoconutConfig) => void): void {
    CoconutSDK.checkInitialized();
    block(CoconutSDK._config);
    CoconutSDK._config.apply();

    ComponentManager.getInstance().setSdkVersion(CoconutSDK._config.sdkVersion);

    // Apply security settings
    if (CoconutSDK._bridge) {
      CoconutSDK._bridge.securityValidator.maxParamsSize = CoconutSDK._config.maxBridgeParamsSize;
      CoconutSDK._bridge.securityValidator.rateLimitPerMethod = CoconutSDK._config.rateLimitPerMethod;
      CoconutSDK._bridge.securityValidator.rateLimitWindowMs = CoconutSDK._config.rateLimitWindowMs;

      if (CoconutSDK._config.allowedDomains.length > 0) {
        CoconutSDK._bridge.securityValidator.setAllowedDomains(CoconutSDK._config.allowedDomains);
      }
    }

    BridgeTokenManager.enabled = CoconutSDK._config.enableBridgeToken;

    Logger.i('CoconutSDK', 'CoconutSDK configured');
  }

  /**
   * Register components
   */
  static async registerComponents(components: CoconutPlugin[]): Promise<void> {
    CoconutSDK.checkInitialized();
    await ComponentManager.getInstance().inject(components);
    Logger.i('CoconutSDK', `Registered ${components.length} components`);
  }

  /**
   * Register a single component
   */
  static async registerComponent(component: CoconutPlugin): Promise<void> {
    CoconutSDK.checkInitialized();
    await ComponentManager.getInstance().register(component);
  }

  /**
   * Get component by name
   */
  static getComponent(name: string): CoconutPlugin | undefined {
    CoconutSDK.checkInitialized();
    return ComponentManager.getInstance().getComponent(name);
  }

  /**
   * Get all registered component names
   */
  static getRegisteredComponents(): string[] {
    CoconutSDK.checkInitialized();
    return ComponentManager.getInstance().getRegisteredComponents();
  }

  /**
   * Get SDK version
   */
  static getVersion(): string {
    return CoconutSDK._config.sdkVersion;
  }

  /**
   * Generate bridge token for JS injection
   */
  static generateBridgeToken(): string {
    return BridgeTokenManager.generateToken();
  }

  /**
   * Get security config as JSON string for JS injection.
   * Includes app name/version (for coconut.env) + bridge protocol version.
   */
  static getSecurityConfig(): string {
    let appName = '';
    let appVersion = '';
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      appVersion = info.versionName;
      appName = info.name;  // bundleName — display label resolution needs resourceManager, deferred
    } catch (e) {
      Logger.w('CoconutSDK', `Failed to read bundle info: ${e}`);
    }

    const builder = new JsonObject();
    builder.put('token', BridgeTokenManager.getToken());
    builder.put('appName', appName);
    builder.put('appVersion', appVersion);
    builder.put('hybridVersion', '3');
    return builder.build();
  }

  /**
   * Cleanup resources
   */
  static async cleanup(): Promise<void> {
    if (!CoconutSDK._isInitialized) return;
    Logger.d('CoconutSDK', 'Cleaning up CoconutSDK...');
    await ComponentManager.getInstance().cleanup();
    BridgeTokenManager.reset();
    CoconutSDK._bridge = null;
    CoconutSDK._isInitialized = false;
    Logger.i('CoconutSDK', 'CoconutSDK cleaned up');
  }

  private static checkInitialized(): void {
    if (!CoconutSDK._isInitialized) {
      throw new Error('CoconutSDK not initialized. Call initialize() first.');
    }
  }
}
