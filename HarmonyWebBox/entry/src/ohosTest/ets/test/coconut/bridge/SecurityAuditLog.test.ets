import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { SecurityAuditLog } from '@coconut/sdk';

export default function securityAuditLogTest() {
  describe('SecurityAuditLog', () => {
    beforeAll(() => {
      SecurityAuditLog.clear();
    });

    afterAll(() => {
      SecurityAuditLog.clear();
    });

    it('record_addsEntry', 0, () => {
      SecurityAuditLog.clear();
      SecurityAuditLog.record(SecurityAuditLog.EVENT_DOMAIN_REJECTED, 'device.get', 'r1', 'bad.com');
      const entries = SecurityAuditLog.getEntries();
      expect(entries.length).assertEqual(1);
      expect(entries[0].eventType).assertEqual(SecurityAuditLog.EVENT_DOMAIN_REJECTED);
      expect(entries[0].method).assertEqual('device.get');
    });

    it('getEntriesByType_filters', 0, () => {
      SecurityAuditLog.clear();
      SecurityAuditLog.record(SecurityAuditLog.EVENT_DOMAIN_REJECTED, 'm', '1', '');
      SecurityAuditLog.record(SecurityAuditLog.EVENT_RATE_LIMITED, 'm', '2', '');
      SecurityAuditLog.record(SecurityAuditLog.EVENT_DOMAIN_REJECTED, 'm', '3', '');
      const domainOnly = SecurityAuditLog.getEntriesByType(SecurityAuditLog.EVENT_DOMAIN_REJECTED);
      expect(domainOnly.length).assertEqual(2);
    });

    it('getSummary_countsByType', 0, () => {
      SecurityAuditLog.clear();
      SecurityAuditLog.record(SecurityAuditLog.EVENT_TOKEN_INVALID, 'm', '1', '');
      SecurityAuditLog.record(SecurityAuditLog.EVENT_TOKEN_INVALID, 'm', '2', '');
      SecurityAuditLog.record(SecurityAuditLog.EVENT_RATE_LIMITED, 'm', '3', '');
      const summary = SecurityAuditLog.getSummary();
      expect(summary.get(SecurityAuditLog.EVENT_TOKEN_INVALID)).assertEqual(2);
      expect(summary.get(SecurityAuditLog.EVENT_RATE_LIMITED)).assertEqual(1);
    });

    it('clear_emptiesEntries', 0, () => {
      SecurityAuditLog.record(SecurityAuditLog.EVENT_NONCE_REUSED, 'm', '1', '');
      expect(SecurityAuditLog.getEntries().length > 0).assertTrue();
      SecurityAuditLog.clear();
      expect(SecurityAuditLog.getEntries().length).assertEqual(0);
    });

    it('fifo_cap_at500_entries', 0, () => {
      SecurityAuditLog.clear();
      for (let i = 0; i < 510; i++) {
        SecurityAuditLog.record(SecurityAuditLog.EVENT_SIGNATURE_INVALID, `m.${i}`, `id-${i}`, '');
      }
      const entries = SecurityAuditLog.getEntries();
      expect(entries.length).assertEqual(500);
      // First 10 (id-0..id-9) should have been evicted.
      expect(entries[0].requestId).assertEqual('id-10');
      expect(entries[entries.length - 1].requestId).assertEqual('id-509');
    });
  });
}
