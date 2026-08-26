import { describe, it, expect } from '@ohos/hypium';
import { NavConfig, NavTitleMode, NavClosePolicy } from '@coconut/sdk';

/**
 * NavConfig tests (mirrors Android NavConfigTest semantics):
 * three-tier merge truth table, shouldShowClose × closePolicy × canGoBack,
 * parseOverride field mapping / malformed JSON.
 */
export default function navConfigTest() {
  describe('NavConfig', () => {
    // ---- defaults ----

    it('default_isVisibleAutoTitleAutoClose', 0, () => {
      const d = NavConfig.default();
      expect(d.visible).assertTrue();
      expect(d.titleMode).assertEqual(NavTitleMode.AUTO);
      expect(d.closePolicy).assertEqual(NavClosePolicy.AUTO);
      expect(d.titleText).assertNull();
      expect(d.leftButtonText).assertNull();
      expect(d.rightButtonText).assertNull();
    });

    // ---- merge: null = inherit, non-null = override, per field ----

    it('merge_keepsBase_whenOverrideAllNull', 0, () => {
      const base = NavConfig.default();
      base.titleMode = NavTitleMode.FIXED;
      base.titleText = '基座';
      base.leftButtonText = '取消';
      const merged = NavConfig.merge(base, new NavConfig());
      expect(merged.visible).assertTrue();
      expect(merged.titleMode).assertEqual(NavTitleMode.FIXED);
      expect(merged.titleText).assertEqual('基座');
      expect(merged.leftButtonText).assertEqual('取消');
    });

    it('merge_overridesOnlySetFields', 0, () => {
      const base = NavConfig.default();
      base.titleText = '旧标题';
      base.rightButtonText = '旧按钮';
      const override = new NavConfig();
      override.visible = false;
      const merged = NavConfig.merge(base, override);
      expect(merged.visible).assertFalse();
      expect(merged.titleText).assertEqual('旧标题');
      expect(merged.rightButtonText).assertEqual('旧按钮');
    });

    it('merge_doesNotAliasInputs', 0, () => {
      const base = NavConfig.default();
      const override = new NavConfig();
      override.visible = false;
      const merged = NavConfig.merge(base, override);
      override.visible = true;
      expect(merged.visible).assertFalse();
    });

    it('mergeChain_globalTemplateHeader_perField', 0, () => {
      const global = NavConfig.default();
      global.rightButtonText = '全局分享';
      const template = new NavConfig();
      template.titleMode = NavTitleMode.FIXED;
      template.titleText = '模板页';
      const header = new NavConfig();
      header.visible = false;
      header.titleText = 'H5 标题';
      const merged = NavConfig.merge(NavConfig.merge(global, template), header);
      expect(merged.visible).assertFalse();                // header wins
      expect(merged.titleMode).assertEqual(NavTitleMode.FIXED); // template wins
      expect(merged.titleText).assertEqual('H5 标题');      // header wins
      expect(merged.rightButtonText).assertEqual('全局分享'); // global wins
    });

    // ---- shouldShowClose truth table ----

    it('closePolicyAuto_showsCloseOnlyAtRoot', 0, () => {
      const cfg = new NavConfig();
      cfg.closePolicy = NavClosePolicy.AUTO;
      expect(cfg.shouldShowClose(false)).assertTrue();
      expect(cfg.shouldShowClose(true)).assertFalse();
    });

    it('closePolicyAlways_showsCloseRegardless', 0, () => {
      const cfg = new NavConfig();
      cfg.closePolicy = NavClosePolicy.ALWAYS;
      expect(cfg.shouldShowClose(false)).assertTrue();
      expect(cfg.shouldShowClose(true)).assertTrue();
    });

    it('unresolvedClosePolicy_fallsBackToAuto', 0, () => {
      const cfg = new NavConfig();
      expect(cfg.shouldShowClose(false)).assertTrue();
      expect(cfg.shouldShowClose(true)).assertFalse();
    });

    // ---- parseOverride ----

    it('parseOverride_readsAllFields', 0, () => {
      const cfg = NavConfig.parseOverride(
        '{"visible":false,"title":"订单详情","closePolicy":"always",' +
        '"leftButtonText":"取消","rightButtonText":"分享"}');
      expect(cfg === null).assertFalse();
      expect((cfg as NavConfig).visible).assertFalse();
      expect((cfg as NavConfig).titleMode).assertEqual(NavTitleMode.FIXED);
      expect((cfg as NavConfig).titleText).assertEqual('订单详情');
      expect((cfg as NavConfig).closePolicy).assertEqual(NavClosePolicy.ALWAYS);
      expect((cfg as NavConfig).leftButtonText).assertEqual('取消');
      expect((cfg as NavConfig).rightButtonText).assertEqual('分享');
    });

    it('parseOverride_titleAuto_mapsToAutoMode', 0, () => {
      const cfg = NavConfig.parseOverride('{"title":"auto"}');
      expect(cfg === null).assertFalse();
      expect((cfg as NavConfig).titleMode).assertEqual(NavTitleMode.AUTO);
      expect((cfg as NavConfig).titleText).assertNull();
    });

    it('parseOverride_closePolicyAuto_inherits', 0, () => {
      const cfg = NavConfig.parseOverride('{"closePolicy":"auto"}');
      expect(cfg === null).assertFalse();
      expect((cfg as NavConfig).closePolicy).assertNull();
    });

    it('parseOverride_whitespaceTolerant', 0, () => {
      const cfg = NavConfig.parseOverride('{ "visible" : false, "title" : "空格标题" }');
      expect(cfg === null).assertFalse();
      expect((cfg as NavConfig).visible).assertFalse();
      expect((cfg as NavConfig).titleText).assertEqual('空格标题');
    });

    it('parseOverride_emptyObject_allNull', 0, () => {
      const cfg = NavConfig.parseOverride('{}');
      expect(cfg === null).assertFalse();
      expect((cfg as NavConfig).visible).assertNull();
      expect((cfg as NavConfig).titleMode).assertNull();
    });

    it('parseOverride_malformed_returnsNull', 0, () => {
      expect(NavConfig.parseOverride('{not json') === null).assertTrue();
      expect(NavConfig.parseOverride('') === null).assertTrue();
      expect(NavConfig.parseOverride('   ') === null).assertTrue();
    });
  });
}
