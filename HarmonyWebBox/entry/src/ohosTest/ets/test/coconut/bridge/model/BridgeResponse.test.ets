import { describe, it, expect } from '@ohos/hypium';
import { BridgeResponse } from '@coconut/sdk';
import { ErrorCode } from '@coconut/sdk';

export default function bridgeResponseTest() {
  describe('BridgeResponse', () => {
    it('success_factory_setsFields', 0, () => {
      const r = BridgeResponse.success('id-1', '{"k":1}');
      expect(r.id).assertEqual('id-1');
      expect(r.code).assertEqual(ErrorCode.SUCCESS);
      expect(r.message).assertEqual('success');
      expect(r.result).assertEqual('{"k":1}');
    });

    it('success_isSuccessTrue', 0, () => {
      const r = BridgeResponse.success('id-1', '{}');
      expect(r.isSuccess).assertTrue();
      expect(r.isError).assertFalse();
    });

    it('error_factory_setsErrorFields', 0, () => {
      const r = BridgeResponse.error('id-1', '100004', 'bad params');
      expect(r.id).assertEqual('id-1');
      expect(r.code).assertEqual('100004');
      expect(r.message).assertEqual('bad params');
      expect(r.result).assertEqual('{}');
    });

    it('error_isErrorTrue', 0, () => {
      const r = BridgeResponse.error('id-1', '100004', 'bad');
      expect(r.isError).assertTrue();
      expect(r.isSuccess).assertFalse();
    });

    it('parseError_factory', 0, () => {
      const r = BridgeResponse.parseError('id-1');
      expect(r.code).assertEqual(ErrorCode.PARSE_ERROR);
      expect(r.message).assertEqual('Parse error');
    });

    it('invalidRequest_factory', 0, () => {
      const r = BridgeResponse.invalidRequest('id-1');
      expect(r.code).assertEqual(ErrorCode.INVALID_REQUEST);
    });

    it('methodNotFound_factory_includesMethod', 0, () => {
      const r = BridgeResponse.methodNotFound('id-1', 'device.bogus');
      expect(r.code).assertEqual(ErrorCode.METHOD_NOT_FOUND);
      expect(r.message).assertContain('device.bogus');
    });

    it('invalidParams_factory', 0, () => {
      const r = BridgeResponse.invalidParams('id-1');
      expect(r.code).assertEqual(ErrorCode.INVALID_PARAMS);
    });

    it('internalError_factory', 0, () => {
      const r = BridgeResponse.internalError('id-1', 'oops');
      expect(r.code).assertEqual(ErrorCode.INTERNAL_ERROR);
      expect(r.message).assertEqual('oops');
    });

    it('toJson_roundtripsAllFields', 0, () => {
      const r = BridgeResponse.success('id-2', '{"x":42}');
      const json = r.toJson();
      expect(json).assertContain('"id":"id-2"');
      expect(json).assertContain('"code":"000000"');
      expect(json).assertContain('"message":"success"');
      expect(json).assertContain('"result":{"x":42}');
    });

    it('toJson_errorResponse_preservesMessage', 0, () => {
      const r = BridgeResponse.error('e-1', '200001', 'unknown component');
      const json = r.toJson();
      expect(json).assertContain('"code":"200001"');
      expect(json).assertContain('"message":"unknown component"');
      expect(json).assertContain('"result":{}');
    });
  });
}
