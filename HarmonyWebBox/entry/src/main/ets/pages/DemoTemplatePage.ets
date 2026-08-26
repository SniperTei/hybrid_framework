import { router, promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { CoconutSDK, CoconutWebPage, CoconutWebDelegate, NavConfig, NavTitleMode,
  NavResultBus, ComponentManager, WebViewHelper, JsonObject, JsExecutor } from '@coconut/sdk';
import { ContainerHost } from './WebContainer';

/**
 * Template delegate: same wiring as the standard container, plus an
 * onBack override demonstrating the delegate hook (container-nav
 * design #23) — toast then let the default semantics proceed.
 */
class TemplateDelegate extends CoconutWebDelegate {
  private page: DemoTemplatePage;

  constructor(page: DemoTemplatePage) {
    super();
    this.page = page;
  }

  onBack(): boolean {
    promptAction.showToast({ message: '模板页 onBack 拦截 → 默认返回', duration: 1500 });
    return false;  // false = proceed with default back semantics
  }

  onTitleChange(title: string): void {
    this.page.onPageTitle(title);
  }

  onHistoryChange(canGoBack: boolean): void {
    this.page.onPageHistory(canGoBack);
  }

  onLoadFail(error: string): void {
    this.page.showLoadFailDialog(error);
  }
}

/**
 * DemoTemplatePage — 模板示范容器路由页 (v3.5.0 container-nav Phase 3d).
 *
 * Registered in coconut_templates.json as template name "demo":
 *   coconut.navigator.forward({ template: 'demo', url: 'coconut://demo/index.html' })
 *
 * Isomorphic to WebContainer (composition, not inheritance — ArkTS @Entry
 * pages cannot subclass) plus:
 * - Template-tier NavConfig default (middle tier of the three-tier chain):
 *   FIXED title「Demo 模板页」; per-open header still overrides per field.
 * - Host custom UI: bottom native banner below the WebView.
 * - Delegate onBack override demo (see TemplateDelegate).
 *
 * MUST be registered in main_pages.json — missing registration crashes at
 * router.pushUrl time (reflection cannot pre-check this; e2e scenario ⑩).
 */
@Entry
@Component
struct DemoTemplatePage {
  @State pageTitle: string = '';
  @State canGoBack: boolean = false;
  @State navVisible: boolean = true;

  navConfig: NavConfig = NavConfig.default();
  pageUrl: string = '';
  enableErrorDialog: boolean = true;
  private errorDialogShowing: boolean = false;
  webController: webview.WebviewController = new webview.WebviewController();
  private delegate: TemplateDelegate | null = null;
  private claimedExecutor: JsExecutor | null = null;
  private hostAdapter: ContainerHost | null = null;

  aboutToAppear(): void {
    let url = '';
    let header = '';
    const raw = router.getParams();
    if (raw !== undefined && raw !== null) {
      const params = raw as Record<string, Object>;
      const u = params['url'];
      if (typeof u === 'string') {
        url = u;
      }
      const h = params['header'];
      if (typeof h === 'string') {
        header = h;
      }
    }
    this.pageUrl = url;

    if (CoconutSDK.isInitialized) {
      this.enableErrorDialog = CoconutSDK.config.enableErrorDialog;
    }

    // NavConfig: global ← template default (this page's tier) ← header.
    let cfg = NavConfig.default();
    if (CoconutSDK.isInitialized) {
      cfg = CoconutSDK.config.nav.copy();
    }
    const templateDefault = new NavConfig();
    templateDefault.titleMode = NavTitleMode.FIXED;
    templateDefault.titleText = 'Demo 模板页';
    cfg = NavConfig.merge(cfg, templateDefault);
    if (header.length > 0) {
      const parsed = NavConfig.parseOverride(header);
      if (parsed !== null) {
        cfg = NavConfig.merge(cfg, parsed);
      }
    }
    this.navConfig = cfg;
    this.navVisible = this.navConfig.visible === true;

    const fixedTitle = this.navConfig.titleText;
    if (fixedTitle !== null && fixedTitle.length > 0) {
      this.pageTitle = fixedTitle;
    }

    this.delegate = new TemplateDelegate(this);
  }

  onPageTitle(title: string): void {
    if (this.navConfig.titleMode === NavTitleMode.FIXED) {
      return;
    }
    if (title.length === 0) {
      return;
    }
    this.pageTitle = title;
  }

  onPageHistory(canGoBack: boolean): void {
    this.canGoBack = canGoBack;
  }

  showLoadFailDialog(error: string): void {
    if (!this.enableErrorDialog || this.errorDialogShowing) {
      return;
    }
    this.errorDialogShowing = true;
    promptAction.showDialog({
      title: '加载失败',
      message: error.length > 0 ? error : '网络异常，请稍后重试',
      buttons: [
        { text: '退出', color: '#666666' },
        { text: '重试', color: '#007DFF' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      this.errorDialogShowing = false;
      if (result.index === 1) {
        try {
          this.webController.refresh();
        } catch (e) {
          // controller detached — container is closing anyway
        }
      } else {
        router.back();
      }
    }).catch(() => {
      this.errorDialogShowing = false;
    });
  }

  handleBack(): boolean {
    if (this.delegate !== null && this.delegate.onBack()) {
      return true;
    }
    try {
      if (this.webController.accessBackward()) {
        this.webController.backward();
        return true;
      }
    } catch (e) {
      // controller not attached yet — fall through to close
    }
    router.back();
    return true;
  }

  onBackPress(): boolean {
    return this.handleBack();
  }

  onPageShow(): void {
    // Same resume-claim + drain + host registration as WebContainer.
    const ctx = ComponentManager.getInstance().getSharedContext();
    if (ctx !== null) {
      const executor: JsExecutor = (script: string) => {
        try {
          this.webController.runJavaScript(script);
        } catch (e) {
          console.error(`[DemoTemplatePage] event dispatch failed: ${e}`);
        }
      };
      ctx.eventEmitter.setJsExecutor(executor);
      this.claimedExecutor = executor;
      if (CoconutSDK.isInitialized) {
        try {
          const script = WebViewHelper.buildConfigScript(CoconutSDK.getSecurityConfig());
          this.webController.runJavaScript(script);
        } catch (e) {
          // config also re-injected on every onPageEnd
        }
      }
      const raw = NavResultBus.consume();
      if (raw !== null) {
        let jsonValue = raw;
        try {
          JSON.parse(raw);
        } catch (e) {
          jsonValue = JSON.stringify(raw);
        }
        const payload = new JsonObject();
        payload.putJson('result', jsonValue);
        ctx.eventEmitter.emitBypassingSubscription('nav.result', payload.build());
      }
    }
    this.hostAdapter = new ContainerHost(this.webController);
    ComponentManager.getInstance().setHost(this.hostAdapter);
  }

  aboutToDisappear(): void {
    if (this.claimedExecutor !== null) {
      const ctx = ComponentManager.getInstance().getSharedContext();
      ctx?.eventEmitter.releaseJsExecutor(this.claimedExecutor);
      this.claimedExecutor = null;
    }
    if (this.hostAdapter !== null) {
      const ctx = ComponentManager.getInstance().getSharedContext();
      if (ctx !== null && ctx.host === this.hostAdapter) {
        ComponentManager.getInstance().setHost(null);
      }
      this.hostAdapter = null;
    }
  }

  build() {
    Column() {
      if (this.navVisible) {
        Row() {
          Row() {
            Text('‹')
              .fontSize(34)
              .fontColor('#333333')
              .fontWeight(FontWeight.Bold)
              .onClick(() => {
                this.handleBack();
              })
          }
          .width(72)
          .height('100%')
          .justifyContent(FlexAlign.Center)

          Text(this.pageTitle)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .layoutWeight(1)

          Row() {
            if (this.navConfig.shouldShowClose(this.canGoBack)) {
              Text('✕')
                .fontSize(18)
                .fontColor('#333333')
                .onClick(() => {
                  router.back();
                })
            }
          }
          .width(72)
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(48)
        .backgroundColor('#FFFFFF')
        .alignItems(VerticalAlign.Center)
      }

      CoconutWebPage({
        webController: this.webController,
        url: this.pageUrl,
        delegate: this.delegate
      })
        .layoutWeight(1)
        .width('100%')

      // Host custom UI: native banner below the WebView (template demo).
      Text('宿主原生底部 Banner — 模板页专属 UI')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .width('100%')
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor('#00B42C')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
