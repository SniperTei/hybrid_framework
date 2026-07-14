import { BaseComponent, BridgeTokenManager, RequestSignatureValidator, SecurityAuditLog, JsonObject } from '@coconut/sdk';

/**
 * Security Component
 *
 * Exposes security audit log and configuration to H5
 */
export class SecurityComponent extends BaseComponent {
  name: string = 'security';
  version: string = '1.0.0';
  description: string = 'Security audit and configuration component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getAuditLog':
        return this.getAuditLog(paramsJson);
      case 'getAuditSummary':
        return this.getAuditSummary();
      case 'getSecurityConfig':
        return this.getSecurityConfig();
      case 'clearAuditLog':
        return this.clearAuditLog();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private getAuditLog(paramsJson: string): string {
    const type = this.getParam(paramsJson, 'type');
    const limit = this.getIntParam(paramsJson, 'limit', 100);

    const entries = type.length > 0
      ? SecurityAuditLog.getEntriesByType(type)
      : SecurityAuditLog.getEntries(limit);

    const items: JsonObject[] = [];
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const builder = new JsonObject();
      builder.put('eventType', entry.eventType);
      builder.put('method', entry.method);
      builder.put('requestId', entry.requestId);
      builder.put('detail', entry.detail);
      builder.putNumber('timestamp', entry.timestamp);
      items.push(builder);
    }

    const root = new JsonObject();
    root.putNumber('count', items.length);
    root.putObjectArray('entries', items);
    return this.success(root);
  }

  private getAuditSummary(): string {
    const summary = SecurityAuditLog.getSummary();
    const items: JsonObject[] = [];
    let total = 0;
    summary.forEach((count: number, eventType: string) => {
      const builder = new JsonObject();
      builder.put('eventType', eventType);
      builder.putNumber('count', count);
      items.push(builder);
      total += count;
    });

    const root = new JsonObject();
    root.putNumber('totalEvents', total);
    root.putObjectArray('summary', items);
    return this.success(root);
  }

  private getSecurityConfig(): string {
    const builder = new JsonObject();
    builder.putBool('bridgeTokenEnabled', BridgeTokenManager.enabled);
    builder.putBool('requestSigningEnabled', RequestSignatureValidator.enabled);
    builder.putNumber('signingTimestampToleranceMs', RequestSignatureValidator.timestampToleranceMs);
    return this.success(builder);
  }

  private clearAuditLog(): string {
    SecurityAuditLog.clear();
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }
}
