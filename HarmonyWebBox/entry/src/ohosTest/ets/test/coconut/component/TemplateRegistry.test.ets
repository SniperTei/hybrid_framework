import { describe, it, expect } from '@ohos/hypium';
import { TemplateRegistry } from '../../../../../main/ets/components/TemplateRegistry';

/**
 * TemplateRegistry tests: JSON parsing, shallow validation (blank name /
 * empty page / duplicate name → throw with context), cache reset.
 */
export default function templateRegistryTest() {
  describe('TemplateRegistry', () => {
    const expectThrows = (fn: () => void, fragment: string): void => {
      let thrown: Object | null = null;
      try {
        fn();
      } catch (e) {
        thrown = e as Object;
      }
      expect(thrown instanceof Error).assertTrue();
      expect((thrown as Error).message.indexOf(fragment) >= 0).assertTrue();
    };

    it('parse_readsEntries', 0, () => {
      const entries = TemplateRegistry.parse(
        '[{"templateName":"demo","templatePage":"pages/DemoTemplatePage"}]');
      expect(entries.length).assertEqual(1);
      expect(entries[0].templateName).assertEqual('demo');
      expect(entries[0].templatePage).assertEqual('pages/DemoTemplatePage');
    });

    it('parse_emptyArray_yieldsNoEntries', 0, () => {
      expect(TemplateRegistry.parse('[]').length).assertEqual(0);
    });

    it('parse_malformedJson_throws', 0, () => {
      expectThrows(() => TemplateRegistry.parse('[{"templateName":'), 'not valid JSON');
      expectThrows(() => TemplateRegistry.parse(''), 'not valid JSON');
    });

    it('validate_buildsMap', 0, () => {
      const entries = TemplateRegistry.parse(
        '[{"templateName":"a","templatePage":"pages/A"},' +
        '{"templateName":"b","templatePage":"pages/B"}]');
      const map = TemplateRegistry.validate(entries);
      expect(map.size).assertEqual(2);
      expect(map.get('a')).assertEqual('pages/A');
    });

    it('validate_duplicateName_throws', 0, () => {
      const entries = TemplateRegistry.parse(
        '[{"templateName":"a","templatePage":"pages/A"},' +
        '{"templateName":"a","templatePage":"pages/B"}]');
      expectThrows(() => TemplateRegistry.validate(entries), 'duplicate templateName');
    });

    it('validate_blankName_throws', 0, () => {
      const entries = TemplateRegistry.parse('[{"templateName":"","templatePage":"pages/A"}]');
      expectThrows(() => TemplateRegistry.validate(entries), 'blank templateName');
    });

    it('validate_emptyPage_throws', 0, () => {
      const entries = TemplateRegistry.parse('[{"templateName":"a","templatePage":""}]');
      expectThrows(() => TemplateRegistry.validate(entries), 'empty templatePage');
    });

    it('load_nullContext_returnsEmptyMap', 0, () => {
      TemplateRegistry.resetCache();
      const map = TemplateRegistry.load(null);
      expect(map.size).assertEqual(0);
    });
  });
}
