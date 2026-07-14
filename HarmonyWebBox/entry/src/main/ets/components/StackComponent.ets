import { BaseComponent, ComponentContext, JsonObject } from '@coconut/sdk';

/**
 * Stack Component
 *
 * WebView page stack management using in-memory navigation stack
 */
export class StackComponent extends BaseComponent {
  name: string = 'stack';
  version: string = '1.0.0';
  description: string = 'WebView page stack management component';

  private urls: string[] = [];
  private titles: string[] = [];
  private timestamps: number[] = [];

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'push':
        return this.push(paramsJson);
      case 'pop':
        return this.pop();
      case 'replace':
        return this.replace(paramsJson);
      case 'backTo':
        return this.backTo(paramsJson);
      case 'getSize':
        return this.getSize();
      case 'getStack':
        return this.getStack();
      case 'canGoBack':
        return this.canGoBack();
      case 'getCurrent':
        return this.getCurrent();
      case 'getAll':
        return this.getAll();
      case 'clear':
        return this.clearStack();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private push(paramsJson: string): string {
    const url = this.getParam(paramsJson, 'url');
    if (!url) {
      return this.error('200007', 'URL is required');
    }

    this.urls.push(url);
    this.titles.push('');
    this.timestamps.push(Date.now());

    const ctx = this.getComponentContext();
    const host = ctx ? ctx.host : null;
    const webController = host ? host.getWebController() : null;
    if (webController) {
      webController.loadUrl(url);
    }

    const builder = new JsonObject();
    builder.putBool('success', true);
    builder.put('action', 'push');
    builder.putNumber('stackSize', this.urls.length);
    return this.success(builder);
  }

  private pop(): string {
    if (this.urls.length <= 1) {
      const builder = new JsonObject();
      builder.putBool('success', false);
      builder.put('message', 'Cannot go back, at bottom of stack');
      return this.success(builder);
    }

    this.urls.pop();
    this.titles.pop();
    this.timestamps.pop();

    const ctx = this.getComponentContext();
    const host = ctx ? ctx.host : null;
    const webController = host ? host.getWebController() : null;
    if (webController && webController.accessBackward()) {
      webController.backward();
    }

    const builder = new JsonObject();
    builder.putBool('success', true);
    builder.put('action', 'pop');
    builder.putNumber('stackSize', this.urls.length);
    return this.success(builder);
  }

  private replace(paramsJson: string): string {
    const url = this.getParam(paramsJson, 'url');
    if (!url) {
      return this.error('200007', 'URL is required');
    }

    const lastIndex = this.urls.length - 1;
    if (lastIndex >= 0) {
      this.urls[lastIndex] = url;
      this.titles[lastIndex] = '';
      this.timestamps[lastIndex] = Date.now();
    } else {
      this.urls.push(url);
      this.titles.push('');
      this.timestamps.push(Date.now());
    }

    const ctx = this.getComponentContext();
    const host = ctx ? ctx.host : null;
    const webController = host ? host.getWebController() : null;
    if (webController) {
      webController.runJavaScript(`window.location.replace('${url}')`);
    }

    const builder = new JsonObject();
    builder.putBool('success', true);
    builder.put('action', 'replace');
    return this.success(builder);
  }

  /**
   * Go back to a specific position in the stack.
   * params: { index } (0-based) or { url } (substring match)
   */
  private backTo(paramsJson: string): string {
    const targetIndex = this.getIntParam(paramsJson, 'index', -1);
    const targetUrl = this.getParam(paramsJson, 'url');
    const currentIndex = this.urls.length - 1;

    let stepsBack = 0;
    if (targetIndex >= 0) {
      stepsBack = currentIndex - targetIndex;
      if (stepsBack <= 0) {
        return this.error('200007', `Invalid stack index: ${targetIndex} (current: ${currentIndex})`);
      }
    } else if (targetUrl) {
      // Search backwards for matching URL
      let foundIdx = -1;
      for (let i = currentIndex - 1; i >= 0; i--) {
        if (this.urls[i].indexOf(targetUrl) !== -1) {
          foundIdx = i;
          break;
        }
      }
      if (foundIdx < 0) {
        return this.error('200007', `URL not found in stack: ${targetUrl}`);
      }
      stepsBack = currentIndex - foundIdx;
    } else {
      return this.error('200007', 'index or url parameter required');
    }

    // Trim stack to target position
    const keepCount = currentIndex - stepsBack + 1;
    this.urls = this.urls.slice(0, keepCount);
    this.titles = this.titles.slice(0, keepCount);
    this.timestamps = this.timestamps.slice(0, keepCount);

    // Navigate webview back N steps
    const ctx = this.getComponentContext();
    const host = ctx ? ctx.host : null;
    const webController = host ? host.getWebController() : null;
    if (webController) {
      for (let i = 0; i < stepsBack; i++) {
        if (webController.accessBackward()) {
          webController.backward();
        }
      }
    }

    const builder = new JsonObject();
    builder.putBool('success', true);
    builder.put('action', 'backTo');
    builder.putNumber('stackSize', this.urls.length);
    return this.success(builder);
  }

  /**
   * Get current stack size and index.
   */
  private getSize(): string {
    const builder = new JsonObject();
    builder.putNumber('size', this.urls.length);
    builder.putNumber('currentIndex', this.urls.length - 1);
    return this.success(builder);
  }

  /**
   * Get full page stack info (standard shape aligned with iOS/Android).
   */
  private getStack(): string {
    const pages: JsonObject[] = [];
    const currentIdx = this.urls.length - 1;
    for (let i = 0; i < this.urls.length; i++) {
      const page = new JsonObject();
      page.putNumber('index', i);
      page.put('url', this.urls[i]);
      page.put('title', this.titles[i]);
      page.putBool('isCurrent', i === currentIdx);
      pages.push(page);
    }

    const root = new JsonObject();
    root.putNumber('currentIndex', currentIdx);
    root.putNumber('totalSize', this.urls.length);
    root.putObjectArray('pages', pages);
    return this.success(root);
  }

  /**
   * Check if can go back.
   */
  private canGoBack(): string {
    const ctx = this.getComponentContext();
    const host = ctx ? ctx.host : null;
    const webController = host ? host.getWebController() : null;
    const canBack = webController ? webController.accessBackward() : this.urls.length > 1;

    const builder = new JsonObject();
    builder.putBool('canGoBack', canBack);
    return this.success(builder);
  }

  private getCurrent(): string {
    if (this.urls.length === 0) {
      const builder = new JsonObject();
      builder.putNull('current');
      builder.putNumber('stackSize', 0);
      return this.success(builder);
    }
    const lastIdx = this.urls.length - 1;
    const current = new JsonObject();
    current.put('url', this.urls[lastIdx]);
    current.put('title', this.titles[lastIdx]);
    current.putNumber('timestamp', this.timestamps[lastIdx]);

    const root = new JsonObject();
    root.putObject('current', current);
    root.putNumber('index', lastIdx);
    root.putNumber('stackSize', this.urls.length);
    return this.success(root);
  }

  private getAll(): string {
    const pages: JsonObject[] = [];
    for (let i = 0; i < this.urls.length; i++) {
      const page = new JsonObject();
      page.putNumber('index', i);
      page.put('url', this.urls[i]);
      page.put('title', this.titles[i]);
      page.putNumber('timestamp', this.timestamps[i]);
      page.putBool('isCurrent', i === this.urls.length - 1);
      pages.push(page);
    }

    const root = new JsonObject();
    root.putNumber('currentIndex', this.urls.length - 1);
    root.putNumber('totalSize', this.urls.length);
    root.putObjectArray('pages', pages);
    return this.success(root);
  }

  private clearStack(): string {
    this.urls = [];
    this.titles = [];
    this.timestamps = [];
    const builder = new JsonObject();
    builder.putBool('success', true);
    return this.success(builder);
  }

  protected async onCleanup(): Promise<void> {
    this.urls = [];
    this.titles = [];
    this.timestamps = [];
  }
}
