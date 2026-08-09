import { CoconutPlugin } from './CoconutPlugin';
import { ComponentContext } from './ComponentContext';
import { ComponentHost } from './ComponentHost';
import { ComponentException } from './ComponentException';
import { Logger } from '../utils/Logger';
import { JsonObject } from '../utils/JsonHelper';

/**
 * Component information (returned as JSON string)
 */
export interface ComponentInfo {
  name: string;
  version: string;
  description: string;
  dependencies: string[];
  isInitialized: boolean;
}

/**
 * Component Manager
 *
 * Manages component lifecycle, registration, and routing
 */
export class ComponentManager {
  private static instance: ComponentManager | null = null;
  private components: Map<string, CoconutPlugin> = new Map();
  private sharedContext: ComponentContext | null = null;

  private constructor() {}

  static getInstance(): ComponentManager {
    if (!ComponentManager.instance) {
      ComponentManager.instance = new ComponentManager();
    }
    return ComponentManager.instance;
  }

  /**
   * Set the shared context
   */
  setContext(context: ComponentContext): void {
    this.sharedContext = context;
  }

  /**
   * Get the shared context (null if not yet set).
   */
  getSharedContext(): ComponentContext | null {
    return this.sharedContext;
  }

  /**
   * Set the current host
   */
  setHost(host: ComponentHost | null): void {
    if (this.sharedContext) {
      this.sharedContext.host = host;
    }
  }

  /**
   * Set SDK version
   */
  setSdkVersion(version: string): void {
    if (this.sharedContext) {
      this.sharedContext.sdkVersion = version;
    }
  }

  /**
   * Register a component
   */
  async register(component: CoconutPlugin): Promise<void> {
    if (this.components.has(component.name)) {
      throw new ComponentException('200001', `Component '${component.name}' is already registered`);
    }

    this.checkDependencies(component);
    Logger.d('ComponentManager', `Registering component: ${component.name} v${component.version}`);

    try {
      if (this.sharedContext) {
        await component.init(this.sharedContext);
      }
      this.components.set(component.name, component);
      Logger.i('ComponentManager', `Component registered: ${component.name}`);
    } catch (e) {
      Logger.e('ComponentManager', `Failed to initialize component: ${component.name}: ${e}`);
      throw new ComponentException('200001', `Failed to initialize component '${component.name}': ${e}`);
    }
  }

  /**
   * Register multiple components
   */
  async inject(components: CoconutPlugin[]): Promise<void> {
    for (const component of components) {
      try {
        await this.register(component);
      } catch (e) {
        Logger.e('ComponentManager', `Failed to register component: ${component.name}: ${e}`);
      }
    }
  }

  /**
   * Unregister a component
   */
  async unregister(componentName: string): Promise<void> {
    const component = this.components.get(componentName);
    if (component) {
      try {
        await component.cleanup();
        Logger.i('ComponentManager', `Component unregistered: ${componentName}`);
      } catch (e) {
        Logger.e('ComponentManager', `Error cleaning up component: ${componentName}: ${e}`);
      }
      this.components.delete(componentName);
    }
  }

  /**
   * Get component by name
   */
  getComponent(name: string): CoconutPlugin | undefined {
    return this.components.get(name);
  }

  /**
   * Check if component is registered
   */
  hasComponent(name: string): boolean {
    return this.components.has(name);
  }

  /**
   * Get all registered component names
   */
  getRegisteredComponents(): string[] {
    return Array.from(this.components.keys());
  }

  /**
   * Get component info as JSON string
   */
  getComponentInfo(name: string): string {
    const component = this.components.get(name);
    if (!component) {
      return '';
    }
    const builder = new JsonObject();
    builder.put('name', component.name);
    builder.put('version', component.version);
    builder.put('description', component.description);
    builder.putStringArray('dependencies', component.dependencies);
    builder.putBool('isInitialized', component.isInitialized);
    return builder.build();
  }

  /**
   * Get all components info as JSON string
   */
  getAllComponentsInfo(): string {
    const components = Array.from(this.components.values());
    const items: JsonObject[] = [];
    for (let i = 0; i < components.length; i++) {
      const c = components[i];
      const builder = new JsonObject();
      builder.put('name', c.name);
      builder.put('version', c.version);
      builder.put('description', c.description);
      builder.putStringArray('dependencies', c.dependencies);
      builder.putBool('isInitialized', c.isInitialized);
      items.push(builder);
    }
    const root = new JsonObject();
    root.putNumber('count', items.length);
    root.putObjectArray('components', items);
    return root.build();
  }

  /**
   * Cleanup all components
   */
  async cleanup(): Promise<void> {
    Logger.d('ComponentManager', 'Cleaning up all components');
    for (const component of this.components.values()) {
      try {
        await component.cleanup();
      } catch (e) {
        Logger.e('ComponentManager', `Error cleaning up component: ${component.name}: ${e}`);
      }
    }
    this.components.clear();
    Logger.d('ComponentManager', 'All components cleaned up');
  }

  /**
   * Check component dependencies
   */
  private checkDependencies(component: CoconutPlugin): void {
    for (const dep of component.dependencies) {
      if (!this.components.has(dep)) {
        throw new ComponentException('200001',
          `Component '${component.name}' depends on '${dep}' which is not registered`);
      }
    }
  }
}
