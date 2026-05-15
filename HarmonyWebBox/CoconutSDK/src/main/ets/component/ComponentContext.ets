import { common, UIAbility } from '@kit.AbilityKit';
import { ComponentHost } from './ComponentHost';

/**
 * Component Context
 *
 * Provides components with access to system resources and services
 */
export class ComponentContext {
  readonly context: common.UIAbilityContext;
  sdkVersion: string = '2.0.0';
  host: ComponentHost | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * Get current ability from host
   */
  get currentAbility(): UIAbility | null {
    if (this.host !== null) {
      return this.host.getAbility();
    }
    return null;
  }
}
