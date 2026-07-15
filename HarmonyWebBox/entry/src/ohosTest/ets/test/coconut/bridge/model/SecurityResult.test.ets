import { describe, it, expect } from '@ohos/hypium';
import { SecurityResult } from '@coconut/sdk';

export default function securityResultTest() {
  describe('SecurityResult', () => {
    it('Valid_isTrueWithEmptyMessage', 0, () => {
      const r = SecurityResult.Valid();
      expect(r.isValid).assertTrue();
      expect(r.message).assertEqual('');
    });

    it('Invalid_isFalseWithReason', 0, () => {
      const r = SecurityResult.Invalid('host blocked');
      expect(r.isValid).assertFalse();
      expect(r.message).assertEqual('host blocked');
    });

    it('twoValid_instancesBothValid', 0, () => {
      const a = SecurityResult.Valid();
      const b = SecurityResult.Valid();
      expect(a.isValid && b.isValid).assertTrue();
      expect(a.message).assertEqual(b.message);
    });

    it('twoInvalid_instancesHaveDifferentMessages', 0, () => {
      const a = SecurityResult.Invalid('reason-a');
      const b = SecurityResult.Invalid('reason-b');
      expect(a.message).assertEqual('reason-a');
      expect(b.message).assertEqual('reason-b');
    });

    it('Invalid_emptyReason_stillInvalid', 0, () => {
      const r = SecurityResult.Invalid('');
      expect(r.isValid).assertFalse();
      expect(r.message).assertEqual('');
    });
  });
}
