import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Logger } from '../utils/Logger';
import { ErrorCode } from './model/ErrorCode';

/**
 * Request Signature Validator
 *
 * HMAC-SHA256 signature verification for bridge requests.
 * Uses @kit.CryptoArchitectureKit for HMAC computation.
 */
export class SignResult {
  isValid: boolean = true;
  errorCode: string = '';
  message: string = '';

  static Valid(): SignResult {
    return new SignResult();
  }

  static Invalid(errorCode: string, message: string): SignResult {
    const r = new SignResult();
    r.isValid = false;
    r.errorCode = errorCode;
    r.message = message;
    return r;
  }
}

export class RequestSignatureValidator {
  private static readonly DEFAULT_TOLERANCE_MS: number = 5 * 60 * 1000;
  private static readonly MAX_NONCE_CACHE: number = 1000;

  static enabled: boolean = false;
  static sharedSecret: string = '';
  static timestampToleranceMs: number = RequestSignatureValidator.DEFAULT_TOLERANCE_MS;

  // LRU nonce cache
  private static nonceCache: Map<string, number> = new Map();

  /**
   * Validate request signature
   */
  static async validate(
    method: string,
    id: string,
    timestamp: number,
    nonce: string,
    paramsJson: string,
    sign: string
  ): Promise<SignResult> {
    if (!RequestSignatureValidator.enabled) {
      return SignResult.Valid();
    }

    // Check timestamp tolerance
    const now = Date.now();
    if (timestamp <= 0 || Math.abs(now - timestamp) > RequestSignatureValidator.timestampToleranceMs) {
      Logger.w('RequestSignature', `Timestamp expired: ts=${timestamp}, now=${now}`);
      return SignResult.Invalid(ErrorCode.SIGNATURE_EXPIRED, 'Request timestamp expired');
    }

    // Check nonce reuse
    if (!nonce) {
      Logger.w('RequestSignature', 'Empty nonce');
      return SignResult.Invalid(ErrorCode.NONCE_REUSED, 'Nonce is required when signing is enabled');
    }
    if (RequestSignatureValidator.nonceCache.has(nonce)) {
      Logger.w('RequestSignature', `Nonce reused: ${nonce}`);
      return SignResult.Invalid(ErrorCode.NONCE_REUSED, 'Nonce already used');
    }

    // Compute expected HMAC
    const payload = `${method}|${id}|${timestamp}|${nonce}|${paramsJson}`;
    const expected = await RequestSignatureValidator.computeHmac(payload);

    if (!expected) {
      Logger.e('RequestSignature', 'Failed to compute HMAC');
      return SignResult.Invalid(ErrorCode.SIGNATURE_INVALID, 'Signature verification failed');
    }

    if (!RequestSignatureValidator.constantTimeEquals(expected, sign)) {
      Logger.w('RequestSignature', `Signature mismatch for method=${method}`);
      return SignResult.Invalid(ErrorCode.SIGNATURE_INVALID, 'Invalid signature');
    }

    // Record nonce (with LRU eviction)
    RequestSignatureValidator.nonceCache.set(nonce, now);
    if (RequestSignatureValidator.nonceCache.size > RequestSignatureValidator.MAX_NONCE_CACHE) {
      // Evict oldest entry
      const nonceKeys: string[] = [];
      RequestSignatureValidator.nonceCache.forEach((v: number, k: string) => {
        nonceKeys.push(k);
      });
      if (nonceKeys.length > 0) {
        RequestSignatureValidator.nonceCache.delete(nonceKeys[0]);
      }
    }

    return SignResult.Valid();
  }

  /**
   * Compute HMAC-SHA256
   */
  private static async computeHmac(payload: string): Promise<string> {
    try {
      const secretStr = RequestSignatureValidator.sharedSecret;
      const keyData = new Uint8Array(Array.from(secretStr).map((c: string) => c.charCodeAt(0)));
      const msgData = new Uint8Array(Array.from(payload).map((c: string) => c.charCodeAt(0)));

      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
      const keyBlob: cryptoFramework.DataBlob = { data: keyData };
      const symKey = await symKeyGenerator.convertKey(keyBlob);

      const mac = cryptoFramework.createMac('SHA256');
      await mac.init(symKey);
      const msgBlob: cryptoFramework.DataBlob = { data: msgData };
      await mac.update(msgBlob);
      const result = await mac.doFinal();

      return Array.from(result.data).map((b: number) => b.toString(16).padStart(2, '0')).join('');
    } catch (e) {
      Logger.e('RequestSignature', `HMAC computation failed: ${e}`);
      return '';
    }
  }

  /**
   * Constant-time string comparison
   */
  private static constantTimeEquals(a: string, b: string): boolean {
    if (a.length !== b.length) return false;
    let result = 0;
    for (let i = 0; i < a.length; i++) {
      result |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }
    return result === 0;
  }

  /**
   * Reset nonce cache
   */
  static reset(): void {
    RequestSignatureValidator.nonceCache.clear();
  }
}
