import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import {
  CoconutSDK,
  CoconutWebPage,
  CoconutWebDelegate,
  ComponentManager,
  WebViewHelper,
  JsExecutor
} from '@coconut/sdk';

/**
 * 最小容器页（消费者示例）—— WebBox 的 WebContainer 裁剪版：
 * 无自绘导航栏，系统返回 = WebView 历史优先、退化 router.back()。
 * 容器接线三件事照做：resume-claim 事件执行器 / 配置重注入 / host 注册。
 */
@Entry
@Component
struct WebContainer {
  pageUrl: string = '';
  webController: webview.WebviewController = new webview.WebviewController();
  private claimedExecutor: JsExecutor | null = null;

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw !== undefined && raw !== null) {
      const params = raw as Record<string, Object>;
      const u = params['url'];
      if (typeof u === 'string') {
        this.pageUrl = u;
      }
    }
  }

  onPageShow(): void {
    this.claimBridge();
  }

  aboutToDisappear(): void {
    if (this.claimedExecutor !== null) {
      const ctx = ComponentManager.getInstance().getSharedContext();
      ctx?.eventEmitter.releaseJsExecutor(this.claimedExecutor);
      this.claimedExecutor = null;
    }
  }

  private claimBridge(): void {
    const ctx = ComponentManager.getInstance().getSharedContext();
    if (ctx === null) {
      return;
    }
    const executor: JsExecutor = (script: string) => {
      try {
        this.webController.runJavaScript(script);
      } catch (e) {
        console.error(`[WebContainer] event dispatch failed: ${e}`);
      }
    };
    ctx.eventEmitter.setJsExecutor(executor);
    this.claimedExecutor = executor;
    if (CoconutSDK.isInitialized) {
      try {
        const script = WebViewHelper.buildConfigScript(CoconutSDK.getSecurityConfig());
        this.webController.runJavaScript(script);
      } catch (e) {
        // controller not attached yet — config injection also happens on
        // every onPageEnd inside CoconutWebPage
      }
    }
  }

  onBackPress(): boolean {
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

  build() {
    Column() {
      CoconutWebPage({
        webController: this.webController,
        url: this.pageUrl,
        delegate: new CoconutWebDelegate()
      })
        .layoutWeight(1)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
