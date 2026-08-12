/**
 * Coconut Plugin Interface
 *
 * All components must implement this interface
 */
export interface CoconutPlugin {
  /**
   * Component name (unique identifier)
   */
  name: string;

  /**
   * Component version
   */
  version: string;

  /**
   * Component description
   */
  description: string;

  /**
   * Methods this component exposes via handle().
   * Used by ComponentManager.getCapabilities() so H5 can probe
   * feature support via coconut.supports(component, fn).
   */
  methods: string[];

  /**
   * Component dependencies
   */
  dependencies: string[];

  /**
   * Whether component is initialized
   */
  isInitialized: boolean;

  /**
   * Initialize component
   */
  init(context: Object): Promise<void>;

  /**
   * Handle function call
   * Takes functionName and paramsJson string, returns JSON string result
   */
  handle(functionName: string, paramsJson: string): Promise<string>;

  /**
   * Cleanup component resources
   */
  cleanup(): Promise<void>;
}
