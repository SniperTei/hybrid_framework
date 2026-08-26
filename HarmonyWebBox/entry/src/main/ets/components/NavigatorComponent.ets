import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { BaseComponent, ComponentContext, CoconutSDK, JsonObject, JsonParser,
  NavResultBus } from '@coconut/sdk';
import { UrlGuard } from '@coconut/network';
import { TemplateRegistry } from './TemplateRegistry';

/** Topic pushed to H5 when a custom nav-bar button is tapped ({side: left|right}). */
export const NAV_TOPIC_BUTTON: string = 'nav.button';

/** Topic pushed to the previous container's H5 when a child closes with a result ({result}). */
export const NAV_TOPIC_RESULT: string = 'nav.result';

/** Container stack cap (self-forward loop protection). */
export const NAV_MAX_STACK_DEPTH: number = 10;

/** Standard container route page (template pages resolve to their own routes). */
const DEFAULT_CONTAINER_PAGE: string = 'pages/WebContainer';

/**
 * Navigator Component — H5 opens/controls native containers (第 6 个组件).
 *
 * - forward({template?, url*, params?, header?}): open a new container via
 *   router.pushUrl. url passes the UrlGuard (coconut:// offline packages
 *   are scheme-whitelisted); params flatten into the query string; header
 *   becomes the per-open NavConfig override JSON. Stack capped at
 *   [NAV_MAX_STACK_DEPTH] (router.getLength); unregistered templates fail
 *   loudly — never silently fall back to the standard container.
 * - back(): same path as nav-bar / physical back (goBack, degrade to close).
 * - backToTop(): webviewController has no scrollTo — runJavaScript
 *   window.scrollTo(0,0) fallback.
 * - close({result?}): close this container even with history; a result is
 *   delivered to the previous container as the nav.result event on its
 *   next resume (NavResultBus single slot).
 *
 * Failure conventions: guard/validation → bridge error 200007; business
 * failures (stack limit, template 未注册, no host) → code 000000 +
 * success:false in the payload.
 *
 * Test seams: stack depth supplier, launcher, template resolver and host
 * web-controller supplier are injectable lambdas; defaults read the real
 * router, coconut_templates.json and the ComponentManager host.
 */
export class NavigatorComponent extends BaseComponent {
  name: string = 'navigator';
  version: string = '1.0.0';
  description: string = 'Container navigation component (forward/back/backToTop/close)';
  methods: string[] = ['forward', 'back', 'backToTop', 'close'];

  private readonly stackDepthSupplier: () => number;
  private readonly launcher: (routePage: string, params: Record<string, string>) => void;
  private readonly templateResolver: () => Map<string, string>;
  private readonly hostWebControllerSupplier: () => webview.WebviewController | null;

  constructor(seams?: NavSeams) {
    super();
    if (seams !== undefined) {
      this.stackDepthSupplier = seams.stackDepth;
      this.launcher = seams.launcher;
      this.templateResolver = seams.templateResolver;
      this.hostWebControllerSupplier = seams.hostWebController;
    } else {
      this.stackDepthSupplier = (): number => parseInt(router.getLength());
      this.launcher = (routePage: string, params: Record<string, string>): void => {
        router.pushUrl({ url: routePage, params: params });
      };
      this.templateResolver = (): Map<string, string> => {
        const ctx = this.getComponentContext();
        return TemplateRegistry.load(ctx !== null ? ctx.context : null);
      };
      this.hostWebControllerSupplier = (): webview.WebviewController | null => {
        const ctx = this.getComponentContext();
        if (ctx === null || ctx.host === null) {
          return null;
        }
        return ctx.host.getWebController();
      };
    }
  }

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'forward':
        return this.forwardHandler(paramsJson);
      case 'back':
        return this.backHandler();
      case 'backToTop':
        return this.backToTopHandler();
      case 'close':
        return this.closeHandler(paramsJson);
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  // ---- forward ----

  private async forwardHandler(paramsJson: string): Promise<string> {
    const url = this.getParam(paramsJson, 'url');
    if (url.length === 0) {
      return this.error('200007', 'url is required');
    }

    // Outbound guard (container has no address bar — phishing defense):
    // http(s) URLs go through UrlGuard exactly like network.request;
    // coconut:// offline packages are scheme-whitelisted (moduleId is not
    // a domain; they ride the app-internal resource:// virtual path).
    if (!url.startsWith('coconut://')) {
      // config getter returns the live config object (empty default when
      // uninitialized) — matches UrlGuard's empty-whitelist = allow-all.
      const domains = CoconutSDK.config.allowedDomains;
      const guard = UrlGuard.validate(url, domains);
      if (!guard.allowed) {
        return this.error('200007', `forward blocked: ${guard.reason}`);
      }
    }

    if (this.stackDepthSupplier() >= NAV_MAX_STACK_DEPTH) {
      return this.businessFailure(`container stack limit reached (${NAV_MAX_STACK_DEPTH})`);
    }

    let routePage = DEFAULT_CONTAINER_PAGE;
    const templateName = this.getParam(paramsJson, 'template');
    if (templateName.length > 0) {
      const resolved = this.templateResolver().get(templateName);
      if (resolved === undefined) {
        return this.businessFailure(`template not registered: ${templateName}`);
      }
      routePage = resolved;
    }

    const finalUrl = NavigatorComponent.appendQuery(
      url, JsonParser.getObject(paramsJson, 'params'));

    const params: Record<string, string> = { 'url': finalUrl };
    if (this.hasParam(paramsJson, 'header')) {
      const header = JsonParser.getObject(paramsJson, 'header');
      if (header.length > 2) {
        params['header'] = header;
      }
    }

    this.launcher(routePage, params);
    return this.ack();
  }

  /**
   * Flatten a flat kv object into a URL-encoded query string and append it
   * (merged with `&` when the url already carries a query). String values
   * are unquoted (raw JSON inner text, JsonParser-consistent — no escape
   * decoding, callers pass plain kv strings).
   */
  static appendQuery(url: string, paramsJson: string): string {
    const keys = JsonParser.getKeys(paramsJson);
    if (keys.length === 0) {
      return url;
    }
    const pairs: string[] = [];
    for (const key of keys) {
      const raw = NavigatorComponent.rawValue(paramsJson, key);
      if (raw.length === 0) {
        continue;
      }
      const value = NavigatorComponent.unquote(raw);
      pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    }
    if (pairs.length === 0) {
      return url;
    }
    const query = pairs.join('&');
    return url.indexOf('?') >= 0 ? `${url}&${query}` : `${url}?${query}`;
  }

  /** Strip surrounding quotes of a raw JSON string value; bare otherwise. */
  static unquote(raw: string): string {
    if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  // ---- back / backToTop / close ----

  private async backHandler(): Promise<string> {
    const wc = this.hostWebControllerSupplier();
    if (wc !== null) {
      try {
        if (wc.accessBackward()) {
          wc.backward();
          return this.ack();
        }
      } catch (e) {
        // fall through to router.back()
      }
    }
    router.back();
    return this.ack();
  }

  private async backToTopHandler(): Promise<string> {
    const wc = this.hostWebControllerSupplier();
    if (wc === null) {
      return this.businessFailure('no active webview');
    }
    // webviewController has no scrollTo API — JS fallback.
    try {
      wc.runJavaScript('window.scrollTo(0, 0)');
    } catch (e) {
      return this.businessFailure(`backToTop failed: ${e}`);
    }
    return this.ack();
  }

  private async closeHandler(paramsJson: string): Promise<string> {
    if (this.hasParam(paramsJson, 'result')) {
      const raw = NavigatorComponent.rawValue(paramsJson, 'result');
      if (raw.length > 0) {
        NavResultBus.post(raw);
      }
    }
    router.back();
    return this.ack();
  }

  // ---- helpers ----

  /**
   * Raw JSON value extraction for a top-level key: keeps strings quoted,
   * numbers/bools/null bare; used for query flattening and result
   * passthrough (JsonParser.getString misses non-string values).
   */
  static rawValue(json: string, key: string): string {
    const m = json.match(
      new RegExp(`"${key}"\\s*:\\s*("(?:[^"\\\\]|\\\\)*"|-?\\d+(?:\\.\\d+)?|true|false|null)`));
    if (m === null || m.length < 2) {
      return '';
    }
    return m[1];
  }

  private businessFailure(message: string): string {
    const builder = new JsonObject();
    builder.putBool('success', false);
    builder.put('message', message);
    return this.success(builder);
  }

  private ack(): string {
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }
}

/**
 * Injectable seams for handler tests (default: real router / rawfile / host).
 */
export class NavSeams {
  stackDepth: () => number = (): number => parseInt(router.getLength());
  launcher: (routePage: string, params: Record<string, string>) => void =
    (routePage: string, params: Record<string, string>): void => {
      router.pushUrl({ url: routePage, params: params });
    };
  templateResolver: () => Map<string, string> = (): Map<string, string> => new Map<string, string>();
  hostWebController: () => webview.WebviewController | null = (): webview.WebviewController | null => null;
}
