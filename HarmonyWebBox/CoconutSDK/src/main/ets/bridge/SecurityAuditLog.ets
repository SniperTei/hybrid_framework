import { Logger } from '../utils/Logger';
import { JsonObject } from '../utils/JsonHelper';

/**
 * Security Audit Log
 *
 * Records security rejection events for audit review
 */
export interface AuditEntry {
  eventType: string;
  method: string;
  requestId: string;
  detail: string;
  timestamp: number;
}

export class SecurityAuditLog {
  private static readonly MAX_ENTRIES = 500;
  private static entries: AuditEntry[] = [];

  // Event types
  static readonly EVENT_DOMAIN_REJECTED = 'domain_rejected';
  static readonly EVENT_RATE_LIMITED = 'rate_limited';
  static readonly EVENT_PARAMS_OVERSIZED = 'params_oversized';
  static readonly EVENT_TOKEN_INVALID = 'token_invalid';

  /**
   * Record a security event
   */
  static record(eventType: string, method: string, requestId: string, detail: string): void {
    if (SecurityAuditLog.entries.length >= SecurityAuditLog.MAX_ENTRIES) {
      SecurityAuditLog.entries.shift();
    }
    const entry = new AuditEntryImpl();
    entry.eventType = eventType;
    entry.method = method;
    entry.requestId = requestId;
    entry.detail = detail;
    entry.timestamp = Date.now();
    SecurityAuditLog.entries.push(entry);
    Logger.d('SecurityAuditLog', `Audit: ${eventType} - ${method} - ${detail}`);
  }

  /**
   * Get entries with optional limit
   */
  static getEntries(limit: number = -1): AuditEntry[] {
    if (limit <= 0) {
      return SecurityAuditLog.entries.slice(0);
    }
    return SecurityAuditLog.entries.slice(-limit);
  }

  /**
   * Get entries by type
   */
  static getEntriesByType(eventType: string): AuditEntry[] {
    return SecurityAuditLog.entries.filter((e: AuditEntry) => e.eventType === eventType);
  }

  /**
   * Get summary: count per event type
   */
  static getSummary(): Map<string, number> {
    const summary = new Map<string, number>();
    for (const entry of SecurityAuditLog.entries) {
      summary.set(entry.eventType, (summary.get(entry.eventType) || 0) + 1);
    }
    return summary;
  }

  /**
   * Clear all entries
   */
  static clear(): void {
    SecurityAuditLog.entries = [];
    Logger.d('SecurityAuditLog', 'Audit log cleared');
  }
}

class AuditEntryImpl implements AuditEntry {
  eventType: string = '';
  method: string = '';
  requestId: string = '';
  detail: string = '';
  timestamp: number = 0;
}
