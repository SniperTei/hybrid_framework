import { describe, it, expect } from '@ohos/hypium';
import { HttpError, HttpErrorCode } from '@coconut/network';

export default function httpErrorTest() {
  describe('HttpError', () => {
    it('isNetworkError_truthTable', 0, () => {
      expect(HttpError.isNetworkError(-1001)).assertTrue()   // NETWORK_ERROR
      expect(HttpError.isNetworkError(-1002)).assertTrue()   // TIMEOUT_ERROR
      expect(HttpError.isNetworkError(-1004)).assertTrue()   // URL_BLOCKED（传输层拒绝）
      expect(HttpError.isNetworkError(-2001)).assertFalse()  // TOKEN_EXPIRED
      expect(HttpError.isNetworkError(500)).assertFalse()
    });

    it('isTokenError_truthTable', 0, () => {
      expect(HttpError.isTokenError(-2001)).assertTrue()
      expect(HttpError.isTokenError(-2002)).assertTrue()
      expect(HttpError.isTokenError(-1001)).assertFalse()
      expect(HttpError.isTokenError(-3001)).assertFalse()
    });

    it('isRetryable_truthTable', 0, () => {
      expect(HttpError.isRetryable(-1001)).assertTrue()      // NETWORK_ERROR
      expect(HttpError.isRetryable(-1002)).assertTrue()      // TIMEOUT_ERROR
      expect(HttpError.isRetryable(-1003)).assertFalse()     // SSL_ERROR
      expect(HttpError.isRetryable(-1004)).assertFalse()     // URL_BLOCKED
      expect(HttpError.isRetryable(-2001)).assertFalse()
    });

    it('urlBlockedCode_existsInEnum', 0, () => {
      expect(HttpErrorCode.URL_BLOCKED).assertEqual(-1004)
    });
  });
}
