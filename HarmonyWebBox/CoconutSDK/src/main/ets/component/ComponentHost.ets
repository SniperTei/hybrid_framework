import { UIAbility } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';

/**
 * Component Host Interface
 *
 * Implemented by the page/component that hosts the WebView
 */
export interface ComponentHost {
  /**
   * Get the host UIAbility
   */
  getAbility(): UIAbility | null;

  /**
   * Get the WebviewController
   */
  getWebController(): webview.WebviewController | null;

  /**
   * Run action on main thread
   */
  runOnMainThread(action: () => void): void;
}
