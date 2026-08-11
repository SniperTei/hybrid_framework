import { describe, it, expect } from '@ohos/hypium';
import { BridgeRequest } from '@coconut/sdk';

export default function bridgeRequestTest() {
  describe('BridgeRequest', () => {
    describe('isValidName', () => {
      it('validIdentifierNames_pass', 0, () => {
        expect(BridgeRequest.isValidName('device')).assertTrue();
        expect(BridgeRequest.isValidName('router')).assertTrue();
        expect(BridgeRequest.isValidName('myComponent')).assertTrue();
        expect(BridgeRequest.isValidName('comp_1')).assertTrue();
      });

      it('startsWithDigit_isInvalid', 0, () => {
        expect(BridgeRequest.isValidName('1device')).assertFalse();
        expect(BridgeRequest.isValidName('1func')).assertFalse();
      });

      it('empty_isInvalid', 0, () => {
        expect(BridgeRequest.isValidName('')).assertFalse();
      });

      it('specialChars_isInvalid', 0, () => {
        expect(BridgeRequest.isValidName('get-Info')).assertFalse();
        expect(BridgeRequest.isValidName('get Info')).assertFalse();
        expect(BridgeRequest.isValidName('device.foo')).assertFalse();
      });
    });

    describe('method getter', () => {
      it('componentDotFunction_joined', 0, () => {
        const req = new BridgeRequest();
        req.component = 'router';
        req.function = 'push';
        expect(req.method).assertEqual('router.push');
      });

      it('method_reflectsUpdatedFields', 0, () => {
        const req = new BridgeRequest();
        req.component = 'storage';
        req.function = 'setItem';
        expect(req.method).assertEqual('storage.setItem');
        req.function = 'getItem';
        expect(req.method).assertEqual('storage.getItem');
      });
    });

    describe('validate', () => {
      it('validRequest_passes', 0, () => {
        const req = new BridgeRequest();
        req.component = 'device';
        req.function = 'getInfo';
        req.id = 'req-1';
        const r = req.validate();
        expect(r.isValid).assertTrue();
      });

      it('blankId_fails', 0, () => {
        const req = new BridgeRequest();
        req.component = 'device';
        req.function = 'getInfo';
        req.id = '   ';
        const r = req.validate();
        expect(r.isValid).assertFalse();
        expect(r.message).assertContain('ID');
      });

      it('invalidComponent_fails', 0, () => {
        const req = new BridgeRequest();
        req.component = '1bad';
        req.function = 'getInfo';
        req.id = 'req-1';
        const r = req.validate();
        expect(r.isValid).assertFalse();
        expect(r.message).assertContain('component');
      });

      it('invalidFunction_fails', 0, () => {
        const req = new BridgeRequest();
        req.component = 'device';
        req.function = 'bad-name';
        req.id = 'req-1';
        const r = req.validate();
        expect(r.isValid).assertFalse();
        expect(r.message).assertContain('function');
      });
    });

    describe('fromJson', () => {
      it('parsesComponentAndFunction', 0, () => {
        const json = '{"component":"device","function":"getInfo","params":{"a":1},"id":"req-1","bridgeToken":"t1"}';
        const req = BridgeRequest.fromJson(json);
        expect(req.component).assertEqual('device');
        expect(req.function).assertEqual('getInfo');
        expect(req.method).assertEqual('device.getInfo');
        expect(req.id).assertEqual('req-1');
        expect(req.bridgeToken).assertEqual('t1');
        expect(req.params).assertEqual('{"a":1}');
      });

      it('parsesNullParamsToEmpty', 0, () => {
        const json = '{"component":"device","function":"getInfo","params":null,"id":"r"}';
        const req = BridgeRequest.fromJson(json);
        expect(req.params).assertEqual('');
      });
    });
  });
}
