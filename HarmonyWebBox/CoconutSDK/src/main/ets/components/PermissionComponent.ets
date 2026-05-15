import { abilityAccessCtrl, bundleManager, Permissions, common } from '@kit.AbilityKit';
import { BaseComponent } from '../component/BaseComponent';
import { ComponentContext } from '../component/ComponentContext';
import { Logger } from '../utils/Logger';
import { JsonObject } from '../utils/JsonHelper';

/**
 * Permission Component
 *
 * Unified permission checking and requesting using HarmonyOS APIs
 */
export class PermissionComponent extends BaseComponent {
  name: string = 'permission';
  version: string = '1.0.0';
  description: string = 'Unified permission management component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'check':
        return this.checkPermission(paramsJson);
      case 'request':
        return this.requestPermission(paramsJson);
      case 'getAuthorized':
        return this.getAuthorized();
      case 'openSettings':
        return this.openSettings();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private async checkPermission(paramsJson: string): Promise<string> {
    const permission = this.getParam(paramsJson, 'permission');
    if (!permission) {
      return this.error('900001', 'Permission name required');
    }

    try {
      const ctx = this.getComponentContext();
      if (!ctx) {
        return this.error('900010', 'Context not available');
      }

      const atManager = abilityAccessCtrl.createAtManager();
      const grantStatus = await atManager.checkAccessToken(
        ctx.context.applicationInfo.accessTokenId,
        permission as Permissions
      );

      const builder = new JsonObject();
      builder.put('permission', permission);
      builder.putBool('granted', grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
      return this.success(builder);
    } catch (e) {
      Logger.e(this.name, `Check permission failed: ${e}`);
      return this.error('900010', `Failed to check permission: ${e}`);
    }
  }

  private async requestPermission(paramsJson: string): Promise<string> {
    const permission = this.getParam(paramsJson, 'permission');
    if (!permission) {
      return this.error('900001', 'Permission name required');
    }

    const ctx = this.getComponentContext();
    if (!ctx) {
      return this.error('900010', 'Context not available');
    }

    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const perms: Array<Permissions> = [permission as Permissions];
      const result = await atManager.requestPermissionsFromUser(ctx.context, perms);

      const builder = new JsonObject();
      builder.put('permission', permission);
      builder.putBool('granted', result.authResults[0] === 0);
      return this.success(builder);
    } catch (e) {
      Logger.e(this.name, `Request permission failed: ${e}`);
      return this.error('900010', `Failed to request permission: ${e}`);
    }
  }

  private async getAuthorized(): Promise<string> {
    const builder = new JsonObject();
    builder.putStringArray('permissions', []);
    return this.success(builder);
  }

  private openSettings(): string {
    Logger.d(this.name, 'Open settings requested');
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }
}
