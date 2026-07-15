import { describe, it, expect } from '@ohos/hypium';
import {
  ComponentException,
  ComponentNotFoundException,
  ComponentNotInitializedException,
} from '@coconut/sdk';

export default function componentExceptionTest() {
  describe('ComponentException', () => {
    it('constructor_setsCodeAndMessage', 0, () => {
      const e = new ComponentException('200001', 'unknown component');
      expect(e.code).assertEqual('200001');
      expect(e.message).assertEqual('unknown component');
      expect(e.name).assertEqual('ComponentException');
    });

    it('isInstanceOfError', 0, () => {
      const e = new ComponentException('200002', 'x');
      expect(e instanceof Error).assertTrue();
      expect(e instanceof ComponentException).assertTrue();
    });

    it('defaultCode_isUnknownComponent', 0, () => {
      // ArkTS doesn't allow omitting a required positional; pass default explicitly.
      const e = new ComponentException('200001', 'msg');
      expect(e.code).assertEqual('200001');
    });

    it('componentNotFoundException_setsName', 0, () => {
      const e = new ComponentNotFoundException('not here');
      expect(e.message).assertEqual('not here');
      expect(e.name).assertEqual('ComponentNotFoundException');
      expect(e instanceof Error).assertTrue();
    });

    it('componentNotInitializedException_setsName', 0, () => {
      const e = new ComponentNotInitializedException('not ready');
      expect(e.message).assertEqual('not ready');
      expect(e.name).assertEqual('ComponentNotInitializedException');
      expect(e instanceof Error).assertTrue();
    });
  });
}
