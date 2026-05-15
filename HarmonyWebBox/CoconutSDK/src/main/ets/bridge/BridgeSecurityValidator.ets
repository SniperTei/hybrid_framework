import { SecurityResult } from './model/SecurityResult';
import { Logger } from '../utils/Logger';

/**
 * Bridge Security Validator
 *
 * Domain whitelist, rate limiting, and parameter size validation
 */
export class BridgeSecurityValidator {
  private allowedDomains: Set<string> = new Set();
  private callCounts: Map<string, number> = new Map();
  private lastResetTime: number = Date.now();

  maxParamsSize: number = 1024 * 1024; // 1MB
  rateLimitPerMethod: number = 100;
  rateLimitWindowMs: number = 60000;

  /**
   * Add allowed domain
   */
  addAllowedDomain(domain: string): void {
    this.allowedDomains.add(domain);
  }

  /**
   * Set allowed domains list
   */
  setAllowedDomains(domains: string[]): void {
    this.allowedDomains.clear();
    for (let i = 0; i < domains.length; i++) {
      this.allowedDomains.add(domains[i]);
    }
  }

  /**
   * Check if domain whitelist is configured
   */
  hasDomainWhitelist(): boolean {
    return this.allowedDomains.size > 0;
  }

  /**
   * Validate domain against whitelist
   */
  validateDomain(url: string): SecurityResult {
    if (this.allowedDomains.size === 0) {
      return SecurityResult.Valid();
    }

    const host = this.extractHost(url);
    if (!host) {
      return SecurityResult.Invalid(`Cannot extract host from URL: ${url}`);
    }

    for (const domain of this.allowedDomains) {
      if (host === domain || host.endsWith('.' + domain)) {
        return SecurityResult.Valid();
      }
    }

    Logger.w('BridgeSecurity', `Domain blocked: ${host}`);
    return SecurityResult.Invalid(`Domain not allowed: ${host}`);
  }

  /**
   * Validate parameters size
   */
  validateParamsSize(paramsJson: string): SecurityResult {
    if (paramsJson.length > this.maxParamsSize) {
      Logger.w('BridgeSecurity', `Params too large: ${paramsJson.length} bytes`);
      return SecurityResult.Invalid(`Params size exceeds limit (${paramsJson.length} > ${this.maxParamsSize})`);
    }
    return SecurityResult.Valid();
  }

  /**
   * Check rate limit for a method
   */
  checkRateLimit(method: string): SecurityResult {
    this.resetIfNeeded();

    const count = this.callCounts.get(method);
    const currentCount = count !== undefined ? count : 0;
    if (currentCount >= this.rateLimitPerMethod) {
      Logger.w('BridgeSecurity', `Rate limit exceeded for: ${method}`);
      return SecurityResult.Invalid(`Rate limit exceeded for method: ${method}`);
    }

    this.callCounts.set(method, currentCount + 1);
    return SecurityResult.Valid();
  }

  private extractHost(url: string): string {
    try {
      // Simple URL parsing: extract host between :// and first /
      const protoEnd = url.indexOf('://');
      if (protoEnd === -1) return '';
      const start = protoEnd + 3;
      let end = start;
      while (end < url.length && url[end] !== '/' && url[end] !== ':' && url[end] !== '?') {
        end++;
      }
      return url.substring(start, end);
    } catch (e) {
      return '';
    }
  }

  private resetIfNeeded(): void {
    const now = Date.now();
    if (now - this.lastResetTime >= this.rateLimitWindowMs) {
      this.callCounts.clear();
      this.lastResetTime = now;
    }
  }
}
