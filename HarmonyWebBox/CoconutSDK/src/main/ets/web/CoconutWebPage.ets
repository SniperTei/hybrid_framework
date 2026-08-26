import { webview } from '@kit.ArkWeb';
import { CoconutSDK } from '../../CoconutSDK';
import { ComponentManager } from '../component/ComponentManager';
import { Logger } from '../utils/Logger';
import { WebViewHelper } from './WebViewHelper';
import { CoconutOfflineResources } from './CoconutOfflineResources';
import { CoconutWebDelegate } from './CoconutWebDelegate';

/**
 * Bridge proxy class for javaScriptProxy registration.
 * Must be a named class (not inline object) to comply with ArkTS strict mode.
 */
class CoconutBridgeProxy {
  private onPage: CoconutWebPage | null = null;

  constructor() {}

  bind(page: CoconutWebPage): void {
    this.onPage = page;
  }

  call(jsonData: string): void {
    if (this.onPage) {
      this.onPage.handleBridgeCall(jsonData);
    }
  }
}

/**
 * Coconut Web Page Component
 *
 * Custom component that hosts a WebView with CoconutSDK bridge support.
 * Implements ComponentHost interface for component access.
 */
@Component
export struct CoconutWebPage {
  @Prop url: string = '';
  @State private isLoading: boolean = false;

  webController: webview.WebviewController = new webview.WebviewController();
  @State private bridgeProxy: CoconutBridgeProxy = new CoconutBridgeProxy();
  // Optional behavioral hooks (title sync / history / load fail / back
  // intercept). Plain field: host route pages pass their delegate at
  // construction — CoconutWebPage({ url, delegate, webController }).
  delegate: CoconutWebDelegate | null = null;

  aboutToAppear(): void {
    // ArkWeb cannot load a custom scheme directly: translate coconut://
    // to resource://rawfile/coconut-web/… before the Web component
    // builds with this.url as src. onInterceptRequest then applies the
    // sandbox overlay per file.
    this.url = CoconutOfflineResources.translateUrl(this.url);
    // Ensure bridge exists
    CoconutSDK.bridge?.securityValidator;
    // Bind proxy to this page
    this.bridgeProxy.bind(this);
    // Wire EventEmitter → WebView. EventEmitter owns no WebView reference,
    // so the host owns the dispatch hop.
    const ctx = ComponentManager.getInstance().getSharedContext();
    if (ctx !== null) {
      ctx.eventEmitter.setJsExecutor((script: string) => {
        try {
          this.webController.runJavaScript(script);
        } catch (e) {
          Logger.e('CoconutWebPage', `EventEmitter dispatch failed: ${e}`);
        }
      });
    }
  }

  build() {
    Stack() {
      Web({ src: this.url, controller: this.webController })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(true)
        .mixedMode(MixedMode.All)
        .onlineImageAccess(true)
        .zoomAccess(true)
        .overviewModeAccess(true)
        .databaseAccess(true)
        .mediaPlayGestureAccess(true)
        .cacheMode(CacheMode.Default)
        .darkMode(WebDarkMode.Auto)
        .javaScriptProxy({
          object: this.bridgeProxy,
          name: 'CoconutHarmonyBridge',
          methodList: ['call'],
          controller: this.webController
        })
        .onPageBegin((event) => {
          if (event) {
            this.isLoading = true;
            // Critical: clear stale H5 event subscriptions on reload / new
            // navigation. Otherwise emit() dispatches into the fresh page
            // context using subscriptionIds that no longer have callbacks.
            const ctx = ComponentManager.getInstance().getSharedContext();
            ctx?.eventEmitter.clearAll();
            this.notifyHistory();
            Logger.d('CoconutWebPage', `Page begin: ${event.url}`);
          }
        })
        .onPageEnd((event) => {
          if (event) {
            this.isLoading = false;
            Logger.d('CoconutWebPage', `Page end: ${event.url}`);
            // Inject security config
            this.injectConfig();
            this.notifyHistory();
            // Title fallback: if onTitleReceive never fired (ArkWeb doc
            // deviation risk), getTitle() at page end still syncs AUTO bars.
            this.pushTitle();
          }
        })
        .onTitleReceive((event) => {
          if (event) {
            this.delegate?.onTitleChange(event.title);
          }
        })
        .onSslErrorEventReceive((event) => {
          if (event) {
            Logger.w('CoconutWebPage', 'SSL error, allowing');
            event.handler.handleConfirm();
          }
        })
        .onErrorReceive((event) => {
          if (event) {
            this.isLoading = false;
            // Main-frame heuristic: ArkWeb's WebResourceError carries no
            // explicit isForMainFrame flag — treat a failing request whose
            // URL equals the current page URL as the main frame (empty
            // request URL fails toward rescue too). Subresource errors are
            // logged only.
            let errorUrl = '';
            try {
              errorUrl = event.request.getRequestUrl();
            } catch (e) {
              // request accessor unavailable — keep empty, assume main frame
            }
            const errorInfo = event.error.getErrorInfo();
            Logger.e('CoconutWebPage', `Error: ${errorInfo} (${errorUrl})`);
            if (errorUrl === this.url || errorUrl.length === 0) {
              this.delegate?.onLoadFail(errorInfo);
            }
          }
        })
        .onHttpErrorReceive((event) => {
          if (event) {
            // HTTP 4xx/5xx responses render the server error body and are
            // NOT white screens (container-nav design #5) — log only.
            Logger.e('CoconutWebPage', `HTTP error: ${event.response.getResponseCode()}`);
          }
        })
        .onConsole((event) => {
          if (event) {
            Logger.d('CoconutWebPage', `[JS] ${event.message.getMessage()}`);
          }
          return false;
        })
        .onInterceptRequest((event) => {
          if (event) {
            const ctx = ComponentManager.getInstance().getSharedContext();
            return CoconutOfflineResources.intercept(
              event.request.getRequestUrl(),
              ctx !== null ? ctx.context : null);
          }
          // null response = keep default loading (non-offline requests)
          return null;
        })

      // Loading indicator
      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#007DFF')
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * Handle bridge call from JavaScript
   */
  handleBridgeCall(jsonData: string): void {
    const bridge = CoconutSDK.bridge;
    if (!bridge) {
      Logger.e('CoconutWebPage', 'Bridge not initialized');
      return;
    }

    // Get current URL for domain validation
    const currentUrl = this.url;

    // Async handling - don't block JavaScript thread
    bridge.handleCall(jsonData, currentUrl, this.webController).catch((e: Error) => {
      Logger.e('CoconutWebPage', `Bridge call error: ${e.message}`);
    });
  }

  /**
   * Inject CoconutSDK config into WebView
   */
  private injectConfig(): void {
    const config = CoconutSDK.getSecurityConfig();
    const script = WebViewHelper.buildConfigScript(config);
    this.webController.runJavaScript(script);
  }

  /**
   * Recompute WebView history state and notify the host delegate
   * (drives × close-button visibility under AUTO close policy).
   */
  private notifyHistory(): void {
    let canGoBack = false;
    try {
      canGoBack = this.webController.accessBackward();
    } catch (e) {
      Logger.e('CoconutWebPage', `accessBackward failed: ${e}`);
    }
    this.delegate?.onHistoryChange(canGoBack);
  }

  /**
   * Push the current document title to the delegate (page-end fallback
   * for kernels that do not fire onTitleReceive).
   */
  private pushTitle(): void {
    let title = '';
    try {
      title = this.webController.getTitle();
    } catch (e) {
      return;
    }
    if (title.length > 0) {
      this.delegate?.onTitleChange(title);
    }
  }

  /**
   * Load a new URL
   */
  loadUrl(url: string): void {
    const translated = CoconutOfflineResources.translateUrl(url);
    if (translated !== url) {
      Logger.d('CoconutWebPage', `Offline URL: ${url} -> ${translated}`);
    }
    this.url = translated;
    this.webController.loadUrl(translated);
  }

  /**
   * Go back
   */
  goBack(): boolean {
    if (this.webController.accessBackward()) {
      this.webController.backward();
      return true;
    }
    return false;
  }

  /**
   * Refresh page
   */
  refresh(): void {
    this.webController.refresh();
  }
}
