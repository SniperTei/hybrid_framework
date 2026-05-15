/**
 * Environment Configuration
 *
 * Defines build environments with domain configurations
 */
export enum Environment {
  DEV = 'dev',
  TEST = 'test',
  STAGING = 'staging',
  PROD = 'prod'
}

export class EnvironmentConfig {
  static getH5Domain(env: Environment): string {
    switch (env) {
      case Environment.DEV:
        return 'http://localhost:3000';
      case Environment.TEST:
        return 'https://test-h5.example.com';
      case Environment.STAGING:
        return 'https://staging-h5.example.com';
      case Environment.PROD:
        return 'https://h5.example.com';
      default:
        return 'http://localhost:3000';
    }
  }

  static getApiDomain(env: Environment): string {
    switch (env) {
      case Environment.DEV:
        return 'http://localhost:8080';
      case Environment.TEST:
        return 'https://test-api.example.com';
      case Environment.STAGING:
        return 'https://staging-api.example.com';
      case Environment.PROD:
        return 'https://api.example.com';
      default:
        return 'http://localhost:8080';
    }
  }

  static getDisplayName(env: Environment): string {
    switch (env) {
      case Environment.DEV:
        return 'Development';
      case Environment.TEST:
        return 'Test';
      case Environment.STAGING:
        return 'Staging';
      case Environment.PROD:
        return 'Production';
      default:
        return 'Unknown';
    }
  }
}
