import { describe, it, expect } from '@ohos/hypium';
import { BridgeRequest } from '@coconut/sdk';

export default function bridgeRequestTest() {
  describe('BridgeRequest', () => {
    describe('isValidMethod', () => {
      it('componentDotFunction_isValid', 0, () => {
        expect(BridgeRequest.isValidMethod('device.getInfo')).assertTrue();
        expect(BridgeRequest.isValidMethod('router.push')).assertTrue();
      });

      it('camelCaseAndUnderscores_isValid', 0, () => {
        expect(BridgeRequest.isValidMethod('myComponent.myFunc')).assertTrue();
        expect(BridgeRequest.isValidMethod('comp_1.func_2')).assertTrue();
      });

      it('withoutDot_isInvalid', 0, () => {
        expect(BridgeRequest.isValidMethod('noseparator')).assertFalse();
      });

      it('startsWithDigit_isInvalid', 0, () => {
        expect(BridgeRequest.isValidMethod('1device.getInfo')).assertFalse();
        expect(BridgeRequest.isValidMethod('device.1func')).assertFalse();
      });

      it('empty_isInvalid', 0, () => {
        expect(BridgeRequest.isValidMethod('')).assertFalse();
      });

      it('specialChars_isInvalid', 0, () => {
        expect(BridgeRequest.isValidMethod('device.get-Info')).assertFalse();
        expect(BridgeRequest.isValidMethod('device.get Info')).assertFalse();
      });
    });

    describe('extract', () => {
      it('extractComponent_returnsBeforeDot', 0, () => {
        expect(BridgeRequest.extractComponent('device.getInfo')).assertEqual('device');
      });

      it('extractFunction_returnsAfterDot', 0, () => {
        expect(BridgeRequest.extractFunction('device.getInfo')).assertEqual('getInfo');
      });

      it('componentName_functionName_getters', 0, () => {
        const req = new BridgeRequest();
        req.method = 'router.push';
        expect(req.componentName).assertEqual('router');
        expect(req.functionName).assertEqual('push');
      });
    });

    describe('validate', () => {
      it('validRequest_passes', 0, () => {
        const req = new BridgeRequest();
        req.jsonrpc = '2.0';
        req.method = 'device.getInfo';
        req.id = 'req-1';
        const r = req.validate();
        expect(r.isValid).assertTrue();
      });

      it('blankId_fails', 0, () => {
        const req = new BridgeRequest();
        req.jsonrpc = '2.0';
        req.method = 'device.getInfo';
        req.id = '   ';
        const r = req.validate();
        expect(r.isValid).assertFalse();
        expect(r.message).assertContain('ID');
      });

      it('invalidMethod_fails', 0, () => {
        const req = new BridgeRequest();
        req.jsonrpc = '2.0';
        req.method = 'no-dot';
        req.id = 'req-1';
        const r = req.validate();
        expect(r.isValid).assertFalse();
        expect(r.message).assertContain('method');
      });

      it('wrongJsonrpc_fails', 0, () => {
        const req = new BridgeRequest();
        req.jsonrpc = '1.0';
        req.method = 'device.getInfo';
        req.id = 'req-1';
        const r = req.validate();
        expect(r.isValid).assertFalse();
        expect(r.message).assertContain('version');
      });
    });

    describe('fromJson', () => {
      it('parsesValidJson', 0, () => {
        const json = '{"jsonrpc":"2.0","method":"device.getInfo","params":{"a":1},"id":"req-1","timestamp":123,"nonce":"n1","sign":"s1","bridgeToken":"t1"}';
        const req = BridgeRequest.fromJson(json);
        expect(req.jsonrpc).assertEqual('2.0');
        expect(req.method).assertEqual('device.getInfo');
        expect(req.id).assertEqual('req-1');
        expect(req.timestamp).assertEqual(123);
        expect(req.nonce).assertEqual('n1');
        expect(req.sign).assertEqual('s1');
        expect(req.bridgeToken).assertEqual('t1');
        expect(req.params).assertEqual('{"a":1}');
      });

      it('parsesNullParamsToEmpty', 0, () => {
        const json = '{"jsonrpc":"2.0","method":"device.getInfo","params":null,"id":"r"}';
        const req = BridgeRequest.fromJson(json);
        expect(req.params).assertEqual('');
      });
    });
  });
}
