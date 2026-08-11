import { webview } from '@kit.ArkWeb';
import { BridgeRequest } from './model/BridgeRequest';
import { BridgeResponse } from './model/BridgeResponse';
import { ErrorCode } from './model/ErrorCode';
import { BridgeTokenManager } from './BridgeTokenManager';
import { BridgeSecurityValidator } from './BridgeSecurityValidator';
import { SecurityAuditLog } from './SecurityAuditLog';
import { BridgePerformance } from './BridgePerformance';
import { ComponentManager } from '../component/ComponentManager';
import { ComponentException, ComponentNotFoundException, ComponentNotInitializedException } from '../component/ComponentException';
import { Logger } from '../utils/Logger';

/**
 * Coconut Bridge Implementation
 *
 * Implements async bridge with JSON-RPC 2.0 protocol.
 * Security validation pipeline, performance logging, and error handling.
 */
export class CoconutBridgeImpl {
  private readonly TAG = 'CoconutBridgeImpl';
  readonly securityValidator: BridgeSecurityValidator;
  private componentManager: ComponentManager;

  constructor(componentManager: ComponentManager) {
    this.componentManager = componentManager;
    this.securityValidator = new BridgeSecurityValidator();
  }

  /**
   * Handle bridge call from JavaScript
   */
  async handleCall(jsonData: string, currentUrl: string, webController: webview.WebviewController): Promise<void> {
    let requestMethod = 'unknown';
    let requestId = '';

    try {
      Logger.d(this.TAG, `Received call: ${jsonData}`);

      // 1. Parse request
      let request: BridgeRequest;
      try {
        request = BridgeRequest.fromJson(jsonData);
      } catch (e) {
        const errMsg = e instanceof Error ? e.message : 'Parse error';
        const resp = BridgeResponse.parseError('', errMsg);
        this.sendResponse(webController, resp);
        return;
      }

      requestMethod = request.method;
      requestId = request.id;

      // 2. Validate request format
      const validation = request.validate();
      if (!validation.isValid) {
        Logger.logBridgeCallValidation(request.method, request.id, validation.message);
        const resp = BridgeResponse.invalidRequest(request.id, validation.message);
        this.sendResponse(webController, resp);
        return;
      }

      Logger.logBridgeCallStart(request.method, request.id);

      // 2.5 Bridge Token validation
      if (!BridgeTokenManager.validateToken(request.bridgeToken)) {
        Logger.logBridgeCallError(request.method, request.id, ErrorCode.BRIDGE_TOKEN_INVALID, 'Invalid bridge token');
        SecurityAuditLog.record(SecurityAuditLog.EVENT_TOKEN_INVALID, request.method, request.id, 'Invalid or missing bridge token');
        const resp = BridgeResponse.error(request.id, ErrorCode.BRIDGE_TOKEN_INVALID, 'Invalid bridge token');
        this.sendResponse(webController, resp);
        return;
      }

      // 3. Domain whitelist check
      const domainResult = this.securityValidator.validateDomain(currentUrl);
      if (!domainResult.isValid) {
        Logger.logBridgeCallError(request.method, request.id, ErrorCode.DOMAIN_NOT_ALLOWED, domainResult.message);
        SecurityAuditLog.record(SecurityAuditLog.EVENT_DOMAIN_REJECTED, request.method, request.id, domainResult.message);
        const resp = BridgeResponse.error(request.id, ErrorCode.DOMAIN_NOT_ALLOWED, domainResult.message);
        this.sendResponse(webController, resp);
        return;
      }

      // 4. Rate limit check
      const rateLimitResult = this.securityValidator.checkRateLimit(request.method);
      if (!rateLimitResult.isValid) {
        Logger.logBridgeCallError(request.method, request.id, ErrorCode.RATE_LIMIT_EXCEEDED, rateLimitResult.message);
        SecurityAuditLog.record(SecurityAuditLog.EVENT_RATE_LIMITED, request.method, request.id, rateLimitResult.message);
        const resp = BridgeResponse.error(request.id, ErrorCode.RATE_LIMIT_EXCEEDED, rateLimitResult.message);
        this.sendResponse(webController, resp);
        return;
      }

      // 5. Params size check
      const paramsSizeResult = this.securityValidator.validateParamsSize(jsonData);
      if (!paramsSizeResult.isValid) {
        Logger.logBridgeCallError(request.method, request.id, ErrorCode.PARAM_VALIDATION_FAILED, paramsSizeResult.message);
        SecurityAuditLog.record(SecurityAuditLog.EVENT_PARAMS_OVERSIZED, request.method, request.id, paramsSizeResult.message);
        const resp = BridgeResponse.error(request.id, ErrorCode.PARAM_VALIDATION_FAILED, paramsSizeResult.message);
        this.sendResponse(webController, resp);
        return;
      }

      // 6. Execute request with performance tracking
      const startMs = Date.now();
      let bridgeSuccess = true;
      let result: string;

      try {
        result = await this.handleRequest(request);
      } catch (e) {
        bridgeSuccess = false;
        const durationMs = Date.now() - startMs;
        BridgePerformance.record(request.method, durationMs, false);
        if (e instanceof Error) {
          throw e;
        }
        throw new Error('Component execution failed');
      }

      const durationMs = Date.now() - startMs;
      BridgePerformance.record(request.method, durationMs, bridgeSuccess);

      // 7. Return success
      Logger.logBridgeCallSuccess(request.method, request.id);
      const resp = BridgeResponse.success(request.id, result);
      this.sendResponse(webController, resp);

    } catch (e) {
      if (e instanceof ComponentNotFoundException) {
        Logger.logBridgeCallError(requestMethod, requestId, ErrorCode.UNKNOWN_COMPONENT, e.message || 'Component not found');
        const resp = BridgeResponse.error(requestId, ErrorCode.UNKNOWN_COMPONENT, e.message || 'Component not found');
        this.sendResponse(webController, resp);
      } else if (e instanceof ComponentException) {
        Logger.logBridgeCallError(requestMethod, requestId, e.code, e.message || 'Component error');
        const resp = BridgeResponse.error(requestId, e.code, e.message || 'Component error');
        this.sendResponse(webController, resp);
      } else if (e instanceof ComponentNotInitializedException) {
        Logger.logBridgeCallError(requestMethod, requestId, ErrorCode.COMPONENT_NOT_INITIALIZED, e.message || 'Component not initialized');
        const resp = BridgeResponse.error(requestId, ErrorCode.COMPONENT_NOT_INITIALIZED, e.message || 'Component not initialized');
        this.sendResponse(webController, resp);
      } else {
        const errMsg = e instanceof Error ? e.message : 'Internal error';
        Logger.e(this.TAG, `Error handling call: ${errMsg}`);
        const resp = BridgeResponse.internalError(requestId, errMsg);
        this.sendResponse(webController, resp);
      }
    }
  }

  /**
   * Route request to component
   */
  private async handleRequest(request: BridgeRequest): Promise<string> {
    const component = this.componentManager.getComponent(request.component);
    if (!component) {
      throw new ComponentNotFoundException(`Component not found: ${request.component}`);
    }

    if (!component.isInitialized) {
      throw new ComponentNotInitializedException(`Component not initialized: ${request.component}`);
    }

    return await component.handle(request.function, request.params);
  }

  /**
   * Send response back to JavaScript via runJavaScript
   */
  private sendResponse(webController: webview.WebviewController, response: BridgeResponse): void {
    try {
      const responseJson = response.toJson();
      const escaped = responseJson.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, '\\n');
      const script = `window.__coconutHarmonyCallback && window.__coconutHarmonyCallback('${escaped}')`;
      webController.runJavaScript(script);
    } catch (e) {
      Logger.e(this.TAG, `Failed to send response: ${e}`);
    }
  }

  /**
   * Extract joined "component.function" from raw JSON for error logs.
   * Returns 'unknown' if neither field is parseable.
   */
  private extractMethodFromJson(jsonData: string): string {
    try {
      const compMatch = jsonData.match(/"component"\s*:\s*"([^"]+)"/);
      const fnMatch = jsonData.match(/"function"\s*:\s*"([^"]+)"/);
      const comp = compMatch ? compMatch[1] : '';
      const fn = fnMatch ? fnMatch[1] : '';
      if (comp && fn) {
        return `${comp}.${fn}`;
      }
      return comp || fn || 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /**
   * Extract id from raw JSON for error cases
   */
  private extractIdFromJson(jsonData: string): string {
    try {
      const match = jsonData.match(/"id"\s*:\s*"([^"]+)"/);
      return match ? match[1] : '';
    } catch (e) {
      return '';
    }
  }
}
