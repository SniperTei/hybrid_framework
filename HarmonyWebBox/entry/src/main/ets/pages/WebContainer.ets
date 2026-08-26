import { router, promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { CoconutSDK, CoconutWebPage, CoconutWebDelegate, NavConfig, NavTitleMode } from '@coconut/sdk';

/**
 * Delegate adapter: forwards CoconutWebPage hooks into this container's
 * @State (title sync / history-driven close button).
 */
class ContainerDelegate extends CoconutWebDelegate {
  private container: WebContainer;

  constructor(container: WebContainer) {
    super();
    this.container = container;
  }

  onTitleChange(title: string): void {
    this.container.onPageTitle(title);
  }

  onHistoryChange(canGoBack: boolean): void {
    this.container.onPageHistory(canGoBack);
  }

  onLoadFail(error: string): void {
    this.container.showLoadFailDialog(error);
  }
}

/**
 * WebContainer — 标准容器路由页 (v3.5.0 container-nav).
 *
 * Opened via router.pushUrl({ url: 'pages/WebContainer',
 *   params: { 'url': <target>, 'header': <NavConfig override JSON, optional> } }).
 *
 * - NavConfig three-tier merge: CoconutConfig.nav (global) ← per-open header.
 * - Self-drawn nav bar (back / title / × or custom text buttons) — does not
 *   depend on NavTitleBar (icon-version API mismatch).
 * - Unified back semantics: nav-bar back and onBackPress share one path —
 *   WebView history first (goBack), degrade to router.back() (close).
 * - AUTO title syncs document.title (onTitleReceive + page-end fallback);
 *   FIXED keeps the configured text.
 *
 * MUST be registered in main_pages.json — missing registration crashes at
 * router.pushUrl time (same class of risk as Android manifest declaration).
 */
@Entry
@Component
struct WebContainer {
  @State pageTitle: string = '';
  @State canGoBack: boolean = false;
  @State navVisible: boolean = true;

  navConfig: NavConfig = NavConfig.default();
  pageUrl: string = '';
  enableErrorDialog: boolean = true;
  private errorDialogShowing: boolean = false;
  webController: webview.WebviewController = new webview.WebviewController();
  private delegate: ContainerDelegate | null = null;

  aboutToAppear(): void {
    let url = '';
    let header = '';
    let errorDialogParam = '';
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
      const d = params['errorDialog'];
      if (typeof d === 'string') {
        errorDialogParam = d;
      }
    }
    this.pageUrl = url;

    // White-screen rescue dialog: global config default, per-open override
    // (e2e off-switch). Accepted values: 'false'/'0' off, 'true'/'1' on.
    if (CoconutSDK.isInitialized) {
      this.enableErrorDialog = CoconutSDK.config.enableErrorDialog;
    }
    if (errorDialogParam.length > 0) {
      this.enableErrorDialog = errorDialogParam !== 'false' && errorDialogParam !== '0';
    }

    // NavConfig resolution: global config ← per-open header (JSON override).
    let global = NavConfig.default();
    if (CoconutSDK.isInitialized) {
      global = CoconutSDK.config.nav.copy();
    }
    let override = new NavConfig();
    if (header.length > 0) {
      const parsed = NavConfig.parseOverride(header);
      if (parsed !== null) {
        override = parsed;
      }
    }
    this.navConfig = NavConfig.merge(global, override);
    this.navVisible = this.navConfig.visible === true;

    // FIXED title renders the configured text; AUTO starts empty and syncs.
    const fixedTitle = this.navConfig.titleText;
    if (fixedTitle !== null && fixedTitle.length > 0) {
      this.pageTitle = fixedTitle;
    }

    this.delegate = new ContainerDelegate(this);
  }

  /** AUTO-mode title sync; FIXED keeps the configured text. */
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

  /**
   * White-screen rescue dialog on main-frame network-level load failure.
   * 重试 = refresh; 退出 = router.back(). Independent of nav-bar visibility
   * (a hidden bar still gets rescue). No stacking within one attempt: the
   * dialog is modal and the flag resets when a button resolves it. NB:
   * promptAction dialogs have no onDidDismiss callback on this SDK
   * (memory pitfall #3) — button action is the only result path.
   */
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

  /**
   * Unified back path: delegate intercept → WebView history → degrade to
   * closing the container. Nav-bar back tap and onBackPress both land here.
   */
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

  build() {
    Column() {
      if (this.navVisible) {
        Row() {
          // Left zone: custom text button (nav.button tap) or back chevron.
          // Equal fixed widths left/right keep the title visually centered.
          Row() {
            if (this.hasLeftText()) {
              Text(this.navConfig.leftButtonText as string)
                .fontSize(16)
                .fontColor('#333333')
                .maxLines(1)
                .onClick(() => {
                  this.handleBack();
                })
            } else {
              Text('‹')
                .fontSize(34)
                .fontColor('#333333')
                .fontWeight(FontWeight.Bold)
                .onClick(() => {
                  this.handleBack();
                })
            }
          }
          .width(72)
          .height('100%')
          .justifyContent(FlexAlign.Center)

          // Center: title (AUTO syncs document.title; FIXED static text).
          Text(this.pageTitle)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .layoutWeight(1)

          // Right zone: custom text button, or × when history exhausted
          // (AUTO close policy) / always (ALWAYS).
          Row() {
            if (this.hasRightText()) {
              Text(this.navConfig.rightButtonText as string)
                .fontSize(16)
                .fontColor('#333333')
                .maxLines(1)
                .onClick(() => {
                  // Custom right-button tap: nav.button dispatch lands in
                  // Phase 3b; until then a configured right text is a no-op
                  // (close capability is yielded to the custom action).
                })
            } else if (this.navConfig.shouldShowClose(this.canGoBack)) {
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  private hasLeftText(): boolean {
    const text = this.navConfig.leftButtonText;
    return text !== null && text.length > 0;
  }

  private hasRightText(): boolean {
    const text = this.navConfig.rightButtonText;
    return text !== null && text.length > 0;
  }
}
