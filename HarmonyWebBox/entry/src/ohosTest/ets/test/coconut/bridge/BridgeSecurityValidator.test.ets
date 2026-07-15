import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { BridgeSecurityValidator } from '@coconut/sdk';

export default function bridgeSecurityValidatorTest() {
  describe('BridgeSecurityValidator', () => {
    let validator: BridgeSecurityValidator;

    beforeAll(() => {
      validator = new BridgeSecurityValidator();
    });

    it('defaultLimits_areSet', 0, () => {
      expect(validator.maxParamsSize).assertEqual(1024 * 1024);
      expect(validator.rateLimitPerMethod).assertEqual(100);
      expect(validator.rateLimitWindowMs).assertEqual(60000);
    });

    it('hasDomainWhitelist_initiallyFalse', 0, () => {
      const v = new BridgeSecurityValidator();
      expect(v.hasDomainWhitelist()).assertFalse();
    });

    it('addAllowedDomain_addsToWhitelist', 0, () => {
      const v = new BridgeSecurityValidator();
      v.addAllowedDomain('example.com');
      expect(v.hasDomainWhitelist()).assertTrue();
    });

    it('setAllowedDomains_overridesPreviousList', 0, () => {
      const v = new BridgeSecurityValidator();
      v.addAllowedDomain('a.com');
      v.setAllowedDomains(['b.com', 'c.com']);
      const r = v.validateDomain('https://a.com/page');
      expect(r.isValid).assertFalse();
    });

    it('validateDomain_inWhitelist_passes', 0, () => {
      const v = new BridgeSecurityValidator();
      v.addAllowedDomain('example.com');
      expect(v.validateDomain('https://example.com/path').isValid).assertTrue();
      expect(v.validateDomain('https://sub.example.com/path').isValid).assertTrue();
    });

    it('validateDomain_outsideWhitelist_fails', 0, () => {
      const v = new BridgeSecurityValidator();
      v.addAllowedDomain('example.com');
      const r = v.validateDomain('https://evil.com/path');
      expect(r.isValid).assertFalse();
    });

    it('validateDomain_emptyWhitelist_passesAll', 0, () => {
      const v = new BridgeSecurityValidator();
      expect(v.validateDomain('https://anywhere.com/').isValid).assertTrue();
    });

    it('validateParamsSize_underLimit_passes', 0, () => {
      const v = new BridgeSecurityValidator();
      expect(v.validateParamsSize('{}').isValid).assertTrue();
    });

    it('validateParamsSize_overLimit_fails', 0, () => {
      const v = new BridgeSecurityValidator();
      v.maxParamsSize = 10;
      const r = v.validateParamsSize('abcdefghijklmnopqrstuvwxyz');
      expect(r.isValid).assertFalse();
    });

    it('checkRateLimit_underLimit_passes', 0, () => {
      const v = new BridgeSecurityValidator();
      v.rateLimitPerMethod = 3;
      expect(v.checkRateLimit('m1').isValid).assertTrue();
      expect(v.checkRateLimit('m1').isValid).assertTrue();
      expect(v.checkRateLimit('m1').isValid).assertTrue();
    });

    it('checkRateLimit_overLimit_fails', 0, () => {
      const v = new BridgeSecurityValidator();
      v.rateLimitPerMethod = 2;
      expect(v.checkRateLimit('m2').isValid).assertTrue();
      expect(v.checkRateLimit('m2').isValid).assertTrue();
      const r = v.checkRateLimit('m2');
      expect(r.isValid).assertFalse();
    });

    it('checkRateLimit_resetsAfterWindow', 0, async () => {
      const v = new BridgeSecurityValidator();
      v.rateLimitPerMethod = 1;
      v.rateLimitWindowMs = 1; // 1ms window
      expect(v.checkRateLimit('m3').isValid).assertTrue();
      expect(v.checkRateLimit('m3').isValid).assertFalse();
      // Wait long enough for the window to expire.
      await new Promise<void>((resolve: Function) => setTimeout(resolve, 10));
      expect(v.checkRateLimit('m3').isValid).assertTrue();
    });
  });
}
