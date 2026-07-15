import { describe, beforeAll, it, expect } from '@ohos/hypium';
import { BaseComponent } from '@coconut/sdk';

/**
 * Concrete subclass that exposes the protected param helpers so they can be
 * exercised in tests.
 */
class TestComponent extends BaseComponent {
  name: string = 'test';
  version: string = '1.0.0';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    return '{}';
  }

  public param(paramsJson: string, key: string, def: string = ''): string {
    return this.getParam(paramsJson, key, def);
  }

  public intParam(paramsJson: string, key: string, def: number = 0): number {
    return this.getIntParam(paramsJson, key, def);
  }

  public boolParam(paramsJson: string, key: string, def: boolean = false): boolean {
    return this.getBoolParam(paramsJson, key, def);
  }

  public has(paramsJson: string, key: string): boolean {
    return this.hasParam(paramsJson, key);
  }
}

export default function baseComponentTest() {
  describe('BaseComponent', () => {
    let c: TestComponent;

    beforeAll(() => {
      c = new TestComponent();
    });

    it('getParam_returnsValue', 0, () => {
      expect(c.param('{"name":"alice"}', 'name')).assertEqual('alice');
    });

    it('getParam_missingKey_returnsDefault', 0, () => {
      expect(c.param('{"a":"b"}', 'missing', 'fallback')).assertEqual('fallback');
    });

    it('getIntParam_parsesNumber', 0, () => {
      expect(c.intParam('{"count":42}', 'count')).assertEqual(42);
    });

    it('getIntParam_invalid_returnsDefault', 0, () => {
      expect(c.intParam('{"count":"abc"}', 'count', 7)).assertEqual(7);
    });

    it('getBoolParam_parsesTrueFalse', 0, () => {
      expect(c.boolParam('{"a":true}', 'a')).assertTrue();
      expect(c.boolParam('{"a":false}', 'a')).assertFalse();
    });

    it('getBoolParam_missing_returnsDefault', 0, () => {
      expect(c.boolParam('{"x":1}', 'a', true)).assertTrue();
    });

    it('hasParam_trueWhenKeyPresent', 0, () => {
      expect(c.has('{"name":"x"}', 'name')).assertTrue();
      expect(c.has('{"other":"x"}', 'name')).assertFalse();
    });

    it('init_cleanup_togglesIsInitialized', 0, async () => {
      const comp = new TestComponent();
      expect(comp.isInitialized).assertFalse();
      await comp.init(new Object());
      expect(comp.isInitialized).assertTrue();
      await comp.cleanup();
      expect(comp.isInitialized).assertFalse();
    });
  });
}
