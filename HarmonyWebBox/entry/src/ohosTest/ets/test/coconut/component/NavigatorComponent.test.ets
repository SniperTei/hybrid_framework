import { describe, it, expect } from '@ohos/hypium';
import { ComponentException, JsonParser, CoconutSDK, NavResultBus } from '@coconut/sdk';
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

    // Regression (e2e scenario ⑨): close({result}) sends result as an
    // OBJECT — the old primitive-only regex missed it and NavResultBus
    // never received the payload.
    it('rawValue_handlesObjectsAndArrays', 0, () => {
      expect(NavigatorComponent.rawValue('{"result":{"from":"driver","d":"child"}}', 'result'))
        .assertEqual('{"from":"driver","d":"child"}');
      expect(NavigatorComponent.rawValue('{"result":{"a":{"b":1}},"x":1}', 'result'))
        .assertEqual('{"a":{"b":1}}');
      expect(NavigatorComponent.rawValue('{"result":{"a":{"b":1}},"x":1}', 'x'))
        .assertEqual('1');
      expect(NavigatorComponent.rawValue('{"list":[1,2],"tail":null}', 'list'))
        .assertEqual('[1,2]');
      expect(NavigatorComponent.rawValue('{"list":[1,2],"tail":null}', 'tail'))
        .assertEqual('null');
      // string value containing braces / colons / commas must not confuse depth
      expect(NavigatorComponent.rawValue('{"msg":"a{b}c,d:e","n":2}', 'msg'))
        .assertEqual('"a{b}c,d:e"');
      expect(NavigatorComponent.rawValue('{"msg":"a{b}c,d:e","n":2}', 'n'))
        .assertEqual('2');
    });

    it('close_objectResult_postsToNavResultBus', 0, async () => {
      NavResultBus.post('stale'); // ensure consume clears pre-existing state
      expect(NavResultBus.consume()).assertEqual('stale');
      const comp = new NavigatorComponent(makeSeams());
      const result = await comp.handle('close',
        '{"result":{"from":"driver","d":"child"}}');
      expect(JsonParser.getBool(result, 'success')).assertTrue();
      const posted = NavResultBus.consume();
      expect(posted !== null).assertTrue();
      expect(posted).assertEqual('{"from":"driver","d":"child"}');
      expect(NavResultBus.consume()).assertEqual(null); // single slot drained
    });

    it('close_noResult_doesNotPost', 0, async () => {
      NavResultBus.post('stale');
      const comp = new NavigatorComponent(makeSeams());
      const result = await comp.handle('close', '{}');
      expect(JsonParser.getBool(result, 'success')).assertTrue();
      expect(NavResultBus.consume()).assertEqual('stale'); // untouched
      NavResultBus.consume(); // cleanup
    });
  });
}
