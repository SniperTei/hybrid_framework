import { util } from '@kit.ArkTS';
import { Logger } from '../utils/Logger';

/**
 * Bridge Token Manager
 *
 * Generates a UUID token per session, injected into JS via __coconutConfig.
 * Each bridge call must carry the correct token to prevent JS injection.
 */
export class BridgeTokenManager {
  private static token: string = '';
  private static _enabled: boolean = true;

  static get enabled(): boolean {
    return BridgeTokenManager._enabled;
  }

  static set enabled(val: boolean) {
    BridgeTokenManager._enabled = val;
  }

  /**
   * Generate a new token for the current session
   */
  static generateToken(): string {
    BridgeTokenManager.token = util.generateRandomUUID(true);
    Logger.d('BridgeTokenManager', 'Bridge token generated');
    return BridgeTokenManager.token;
  }

  /**
   * Get current token
   */
  static getToken(): string {
    return BridgeTokenManager.token;
  }

  /**
   * Validate the given token
   */
  static validateToken(requestToken: string): boolean {
    if (!BridgeTokenManager._enabled) return true;
    if (BridgeTokenManager.token === '') return true; // Not initialized yet
    return BridgeTokenManager.token === requestToken;
  }

  /**
   * Reset token
   */
  static reset(): void {
    BridgeTokenManager.token = '';
    Logger.d('BridgeTokenManager', 'Bridge token reset');
  }
}
