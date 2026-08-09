import { describe, it, expect } from '@ohos/hypium';
import { ErrorCode } from '@coconut/sdk';

export default function errorCodeTest() {
  describe('ErrorCode', () => {
    it('success_isZeroZeroZeroZeroZeroZero', 0, () => {
      expect(ErrorCode.SUCCESS).assertEqual('000000');
    });

    it('allCodes_areSixDigitStrings', 0, () => {
      const codes: string[] = [
        ErrorCode.SUCCESS,
        ErrorCode.PARSE_ERROR,
        ErrorCode.INVALID_REQUEST,
        ErrorCode.METHOD_NOT_FOUND,
        ErrorCode.INVALID_PARAMS,
        ErrorCode.INTERNAL_ERROR,
        ErrorCode.UNKNOWN_COMPONENT,
        ErrorCode.UNKNOWN_FUNCTION,
        ErrorCode.PERMISSION_DENIED,
        ErrorCode.TIMEOUT,
        ErrorCode.CANCELLED,
        ErrorCode.DOMAIN_NOT_ALLOWED,
        ErrorCode.PARAM_VALIDATION_FAILED,
        ErrorCode.COMPONENT_NOT_INITIALIZED,
        ErrorCode.RATE_LIMIT_EXCEEDED,
        ErrorCode.BRIDGE_TOKEN_INVALID,
      ];
      for (let i = 0; i < codes.length; i++) {
        expect(codes[i].length).assertEqual(6);
        for (let j = 0; j < 6; j++) {
          const c = codes[i].charCodeAt(j);
          expect(c >= 0x30 && c <= 0x39).assertTrue();
        }
      }
    });

    it('allCodes_areUnique', 0, () => {
      const codes: string[] = [
        ErrorCode.SUCCESS,
        ErrorCode.PARSE_ERROR,
        ErrorCode.INVALID_REQUEST,
        ErrorCode.METHOD_NOT_FOUND,
        ErrorCode.INVALID_PARAMS,
        ErrorCode.INTERNAL_ERROR,
        ErrorCode.UNKNOWN_COMPONENT,
        ErrorCode.UNKNOWN_FUNCTION,
        ErrorCode.PERMISSION_DENIED,
        ErrorCode.TIMEOUT,
        ErrorCode.CANCELLED,
        ErrorCode.DOMAIN_NOT_ALLOWED,
        ErrorCode.PARAM_VALIDATION_FAILED,
        ErrorCode.COMPONENT_NOT_INITIALIZED,
        ErrorCode.RATE_LIMIT_EXCEEDED,
        ErrorCode.BRIDGE_TOKEN_INVALID,
      ];
      const seen = new Set<string>();
      for (let i = 0; i < codes.length; i++) {
        expect(seen.has(codes[i])).assertFalse();
        seen.add(codes[i]);
      }
    });

    it('standardErrors_startWithOne', 0, () => {
      expect(ErrorCode.PARSE_ERROR.startsWith('1')).assertTrue();
      expect(ErrorCode.INVALID_REQUEST.startsWith('1')).assertTrue();
      expect(ErrorCode.METHOD_NOT_FOUND.startsWith('1')).assertTrue();
      expect(ErrorCode.INVALID_PARAMS.startsWith('1')).assertTrue();
      expect(ErrorCode.INTERNAL_ERROR.startsWith('1')).assertTrue();
    });

    it('businessErrors_startWithTwo', 0, () => {
      expect(ErrorCode.UNKNOWN_COMPONENT.startsWith('2')).assertTrue();
      expect(ErrorCode.TIMEOUT.startsWith('2')).assertTrue();
      expect(ErrorCode.RATE_LIMIT_EXCEEDED.startsWith('2')).assertTrue();
    });

    it('securityErrors_startWithThree', 0, () => {
      expect(ErrorCode.BRIDGE_TOKEN_INVALID.startsWith('3')).assertTrue();
    });

    it('getDescription_returnsKnownDescriptions', 0, () => {
      expect(ErrorCode.getDescription(ErrorCode.SUCCESS)).assertEqual('Success');
      expect(ErrorCode.getDescription(ErrorCode.PARSE_ERROR)).assertEqual('Parse error');
      expect(ErrorCode.getDescription(ErrorCode.METHOD_NOT_FOUND)).assertEqual('Method not found');
      expect(ErrorCode.getDescription(ErrorCode.BRIDGE_TOKEN_INVALID)).assertEqual('Bridge token invalid');
      expect(ErrorCode.getDescription(ErrorCode.RATE_LIMIT_EXCEEDED)).assertEqual('Rate limit exceeded');
    });

    it('getDescription_unknownCode_returnsUnknownError', 0, () => {
      expect(ErrorCode.getDescription('999999')).assertEqual('Unknown error');
      expect(ErrorCode.getDescription('')).assertEqual('Unknown error');
    });
  });
}
