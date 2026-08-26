import { describe, it, expect } from '@ohos/hypium';
import { ComponentException, JsonParser, CoconutSDK } from '@coconut/sdk';
import { NavigatorComponent, NavSeams } from '../../../../../main/ets/components/NavigatorComponent';

/**
 * NavigatorComponent handler tests (test seams: injected stack depth,
 * launcher, template resolver — the real router/rawfile are not
 * exercised here; multi-container flows are e2e scenarios).
 *
 * Conventions asserted: guard/validation → ComponentException 200007;
 * business failures (stack limit / template 未注册) → 000000 wrapper with
 * success:false in the payload.
 */
export default function navigatorComponentTest() {
  describe('NavigatorComponent', () => {
    const makeSeams = (): CaptureSeams => {
      const capture = new CaptureSeams();
      return capture;
    };

    class CaptureSeams extends NavSeams {
      public depth: number = 1;
      public launchedRoute: string = '';
      public launchedParams: Record<string, string> = {};
      public templates: Map<string, string> = new Map<string, string>();

      constructor() {
        super();
        this.stackDepth = (): number => this.depth;
        this.launcher = (routePage: string, params: Record<string, string>): void => {
          this.launchedRoute = routePage;
          this.launchedParams = params;
        };
        this.templateResolver = (): Map<string, string> => this.templates;
      }
    }

    const expectError = async (fn: () => Promise<string>, code: string): Promise<void> => {
      let thrown: Object | null = null;
      try {
        await fn();
      } catch (e) {
        thrown = e as Object;
      }
      expect(thrown instanceof ComponentException).assertTrue();
      expect((thrown as ComponentException).code).assertEqual(code);
    };

    it('meta_nameAndMethods', 0, () => {
      const comp = new NavigatorComponent();
      expect(comp.name).assertEqual('navigator');
      expect(comp.methods.join(',')).assertEqual('forward,back,backToTop,close');
    });

    it('unknownFunction_throws200002', 0, async () => {
      const comp = new NavigatorComponent(makeSeams());
      await expectError(() => comp.handle('refresh', '{}'), '200002');
    });

    it('missingUrl_throws200007', 0, async () => {
      const comp = new NavigatorComponent(makeSeams());
      await expectError(() => comp.handle('forward', '{}'), '200007');
    });

    it('guardBlockedUrl_throws200007', 0, async () => {
      // allowedDomains empty = allow all — so set a whitelist first
      CoconutSDK.config.allowedDomains = ['allowed.com'];
      const seams = makeSeams();
      const comp = new NavigatorComponent(seams);
      await expectError(() =>
        comp.handle('forward', '{"url":"http://evil.example.com/x"}'), '200007');
      // restore
      CoconutSDK.config.allowedDomains = [];
    });

    it('guardAllowedHost_passes', 0, async () => {
      CoconutSDK.config.allowedDomains = ['allowed.com'];
      const seams = makeSeams();
      const comp = new NavigatorComponent(seams);
      const result = await comp.handle('forward', '{"url":"https://api.allowed.com/x"}');
      expect(JsonParser.getBool(result, 'success')).assertTrue();
      expect(seams.launchedRoute).assertEqual('pages/WebContainer');
      CoconutSDK.config.allowedDomains = [];
    });

    it('coconutScheme_bypassesGuard', 0, async () => {
      CoconutSDK.config.allowedDomains = ['allowed.com'];
      const seams = makeSeams();
      const comp = new NavigatorComponent(seams);
      const result = await comp.handle('forward', '{"url":"coconut://demo/index.html"}');
      expect(JsonParser.getBool(result, 'success')).assertTrue();
      CoconutSDK.config.allowedDomains = [];
    });

    it('stackLimit businessFailure', 0, async () => {
      const seams = makeSeams();
      seams.depth = 10;
      const comp = new NavigatorComponent(seams);
      const result = await comp.handle('forward', '{"url":"https://allowed.com/x"}');
      expect(JsonParser.getBool(result, 'success')).assertFalse();
      expect(JsonParser.getString(result, 'message').indexOf('stack limit') >= 0).assertTrue();
      expect(seams.launchedRoute).assertEqual('');  // not launched
    });

    it('templateNotRegistered_businessFailure', 0, async () => {
      const seams = makeSeams();
      seams.templates = new Map<string, string>();  // empty registry
      const comp = new NavigatorComponent(seams);
      const result = await comp.handle('forward',
        '{"url":"coconut://demo/index.html","template":"ghost"}');
      expect(JsonParser.getBool(result, 'success')).assertFalse();
      expect(JsonParser.getString(result, 'message').indexOf('ghost') >= 0).assertTrue();
      expect(seams.launchedRoute).assertEqual('');  // no silent fallback
    });

    it('templateRegistered_launchesTemplateRoute', 0, async () => {
      const seams = makeSeams();
      seams.templates.set('demo', 'pages/DemoTemplatePage');
      const comp = new NavigatorComponent(seams);
      const result = await comp.handle('forward',
        '{"url":"coconut://demo/index.html","template":"demo"}');
      expect(JsonParser.getBool(result, 'success')).assertTrue();
      expect(seams.launchedRoute).assertEqual('pages/DemoTemplatePage');
      expect(seams.launchedParams['url']).assertEqual('coconut://demo/index.html');
    });

    it('forwardParams_flattenedIntoQuery', 0, async () => {
      const seams = makeSeams();
      const comp = new NavigatorComponent(seams);
      await comp.handle('forward',
        '{"url":"https://allowed.com/x","params":{"a":"1 2","b":"中文"}}');
      const launched = seams.launchedParams['url'];
      expect(launched.indexOf('https://allowed.com/x?') === 0).assertTrue();
      expect(launched.indexOf('a=1%202') >= 0).assertTrue();
      expect(launched.indexOf(`b=${encodeURIComponent('中文')}`) >= 0).assertTrue();
    });

    it('forwardHeader_passedAsRouterParam', 0, async () => {
      const seams = makeSeams();
      const comp = new NavigatorComponent(seams);
      await comp.handle('forward',
        '{"url":"https://allowed.com/x","header":{"title":"订单详情","closePolicy":"always"}}');
      const header = seams.launchedParams['header'];
      expect(header !== undefined).assertTrue();
      expect(header.indexOf('"title":"订单详情"') >= 0).assertTrue();
    });

    // ---- static helpers ----

    it('appendQuery_mergesWithExistingQuery', 0, () => {
      const url = NavigatorComponent.appendQuery('https://x.com/p?k=1', '{"a":"2"}');
      expect(url).assertEqual('https://x.com/p?k=1&a=2');
    });

    it('appendQuery_emptyParams_noop', 0, () => {
      expect(NavigatorComponent.appendQuery('https://x.com/p', '{}'))
        .assertEqual('https://x.com/p');
    });

    it('rawValue_handlesStringsNumbersBools', 0, () => {
      expect(NavigatorComponent.rawValue('{"a":"x","b":1,"c":true}', 'a'))
        .assertEqual('"x"');
      expect(NavigatorComponent.rawValue('{"a":"x","b":1,"c":true}', 'b'))
        .assertEqual('1');
      expect(NavigatorComponent.rawValue('{"a":"x","b":1,"c":true}', 'c'))
        .assertEqual('true');
      expect(NavigatorComponent.rawValue('{"a":"x"}', 'missing')).assertEqual('');
    });
  });
}
