import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { RequestSignatureValidator } from '@coconut/sdk';
import { ErrorCode } from '@coconut/sdk';

const SECRET = 'test-secret-12345';

/**
 * Compute HMAC-SHA256 hex digest using the same crypto API as production,
 * so test and production code share one source of truth.
 */
async function computeHmacHex(payload: string): Promise<string> {
  const keyData = new Uint8Array(Array.from(SECRET).map((c: string) => c.charCodeAt(0)));
  const msgData = new Uint8Array(Array.from(payload).map((c: string) => c.charCodeAt(0)));
  const gen = cryptoFramework.createSymKeyGenerator('HMAC');
  const symKey = await gen.convertKey({ data: keyData } as cryptoFramework.DataBlob);
  const mac = cryptoFramework.createMac('SHA256');
  await mac.init(symKey);
  await mac.update({ data: msgData } as cryptoFramework.DataBlob);
  const result = await mac.doFinal();
  return Array.from(result.data).map((b: number) => b.toString(16).padStart(2, '0')).join('');
}

async function computeSign(method: string, id: string, ts: number, nonce: string, params: string): Promise<string> {
  return computeHmacHex(`${method}|${id}|${ts}|${nonce}|${params}`);
}

export default function requestSignatureValidatorTest() {
  describe('RequestSignatureValidator', () => {
    beforeAll(() => {
      RequestSignatureValidator.reset();
      RequestSignatureValidator.enabled = true;
      RequestSignatureValidator.sharedSecret = SECRET;
      RequestSignatureValidator.timestampToleranceMs = 5 * 60 * 1000;
    });

    afterAll(() => {
      RequestSignatureValidator.reset();
      RequestSignatureValidator.enabled = false;
      RequestSignatureValidator.sharedSecret = '';
    });

    it('disabled_acceptsAnySignature', 0, async () => {
      RequestSignatureValidator.enabled = false;
      try {
        const r = await RequestSignatureValidator.validate(
          'device.getInfo', 'r1', Date.now(), 'n1', '{}', 'obviously-wrong',
        );
        expect(r.isValid).assertTrue();
      } finally {
        RequestSignatureValidator.enabled = true;
      }
    });

    it('validSignature_passes', 0, async () => {
      const ts = Date.now();
      const nonce = 'nonce-valid-1';
      const sign = await computeSign('device.getInfo', 'req-1', ts, nonce, '{}');
      const r = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, nonce, '{}', sign,
      );
      expect(r.isValid).assertTrue();
    });

    it('reusedNonce_rejectedAfterFirstUse', 0, async () => {
      const ts = Date.now();
      const nonce = 'nonce-reuse-1';
      const sign = await computeSign('device.getInfo', 'req-1', ts, nonce, '{}');
      const first = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, nonce, '{}', sign,
      );
      expect(first.isValid).assertTrue();
      const second = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, nonce, '{}', sign,
      );
      expect(second.isValid).assertFalse();
      expect(second.errorCode).assertEqual(ErrorCode.NONCE_REUSED);
    });

    it('emptyNonce_rejected', 0, async () => {
      const ts = Date.now();
      const r = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, '', '{}', 'any',
      );
      expect(r.isValid).assertFalse();
      expect(r.errorCode).assertEqual(ErrorCode.NONCE_REUSED);
    });

    it('wrongSignature_rejected', 0, async () => {
      const ts = Date.now();
      const r = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, 'nonce-wrong-1', '{}', 'deadbeef',
      );
      expect(r.isValid).assertFalse();
      expect(r.errorCode).assertEqual(ErrorCode.SIGNATURE_INVALID);
    });

    it('expiredTimestamp_rejected', 0, async () => {
      const ts = Date.now() - 10 * 60 * 1000; // 10 min ago
      const nonce = 'nonce-expired-1';
      const sign = await computeSign('device.getInfo', 'req-1', ts, nonce, '{}');
      const r = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, nonce, '{}', sign,
      );
      expect(r.isValid).assertFalse();
      expect(r.errorCode).assertEqual(ErrorCode.SIGNATURE_EXPIRED);
    });

    it('futureTimestamp_rejected', 0, async () => {
      const ts = Date.now() + 10 * 60 * 1000; // 10 min ahead
      const nonce = 'nonce-future-1';
      const sign = await computeSign('device.getInfo', 'req-1', ts, nonce, '{}');
      const r = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, nonce, '{}', sign,
      );
      expect(r.isValid).assertFalse();
      expect(r.errorCode).assertEqual(ErrorCode.SIGNATURE_EXPIRED);
    });

    it('zeroTimestamp_rejected', 0, async () => {
      const r = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', 0, 'nonce-zero-1', '{}', 'any',
      );
      expect(r.isValid).assertFalse();
      expect(r.errorCode).assertEqual(ErrorCode.SIGNATURE_EXPIRED);
    });

    it('lruCache_evictsOldestAfter1000Entries', 0, async () => {
      RequestSignatureValidator.reset();
      for (let i = 0; i < 1000; i++) {
        const nonce = `n-${i}`;
        const ts = Date.now();
        const sign = await computeSign('device.getInfo', 'req-1', ts, nonce, '{}');
        const r = await RequestSignatureValidator.validate(
          'device.getInfo', 'req-1', ts, nonce, '{}', sign,
        );
        expect(r.isValid).assertTrue();
      }
      // Add one more → evicts oldest "n-0".
      const extra = 'n-1000';
      const ts1 = Date.now();
      const extraSign = await computeSign('device.getInfo', 'req-1', ts1, extra, '{}');
      expect(
        (await RequestSignatureValidator.validate('device.getInfo', 'req-1', ts1, extra, '{}', extraSign)).isValid,
      ).assertTrue();
      // n-0 evicted → reusable.
      const ts2 = Date.now();
      const signN0 = await computeSign('device.getInfo', 'req-1', ts2, 'n-0', '{}');
      const result = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts2, 'n-0', '{}', signN0,
      );
      expect(result.isValid).assertTrue();
    });

    it('reset_clearsNonceCache', 0, async () => {
      const ts = Date.now();
      const nonce = 'nonce-reset-1';
      const sign = await computeSign('device.getInfo', 'req-1', ts, nonce, '{}');
      const first = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts, nonce, '{}', sign,
      );
      expect(first.isValid).assertTrue();
      RequestSignatureValidator.reset();
      const ts2 = Date.now();
      const sign2 = await computeSign('device.getInfo', 'req-1', ts2, nonce, '{}');
      const after = await RequestSignatureValidator.validate(
        'device.getInfo', 'req-1', ts2, nonce, '{}', sign2,
      );
      expect(after.isValid).assertTrue();
    });
  });
}
