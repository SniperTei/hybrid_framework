import { Environment, EnvironmentConfig } from './Environment';
import { Logger } from '../utils/Logger';

/**
 * Coconut SDK Configuration
 *
 * Provides configuration options for the SDK
 */
export class CoconutConfig {
  // Basic settings
  isDebugMode: boolean = true;
  timeout: number = 30000;
  customUserAgent: string = '';
  enableWebViewDebug: boolean = false;

  // Environment
  environment: Environment = Environment.DEV;
  h5Domain: string = '';
  apiDomain: string = '';

  // Security
  allowedDomains: string[] = [];
  enableParamValidation: boolean = true;
  maxBridgeParamsSize: number = 1024 * 1024; // 1MB
  enableRateLimit: boolean = true;
  rateLimitPerMethod: number = 100;
  rateLimitWindowMs: number = 60000;

  // Security enhancement
  enableBridgeToken: boolean = true;

  // SDK version
  sdkVersion: string = '3.3.0';

  get effectiveH5Domain(): string {
    return this.h5Domain || EnvironmentConfig.getH5Domain(this.environment);
  }

  get effectiveApiDomain(): string {
    return this.apiDomain || EnvironmentConfig.getApiDomain(this.environment);
  }

  apply(): void {
    Logger.setDebugMode(this.isDebugMode);
    Logger.i('CoconutConfig', `Config applied: env=${EnvironmentConfig.getDisplayName(this.environment)}`);
  }
}
