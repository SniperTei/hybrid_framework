import { BaseComponent, ComponentContext, Logger, JsonObject } from '@coconut/sdk';

/**
 * Router Component
 *
 * Unified routing protocol for WebView navigation
 */
export class RouterComponent extends BaseComponent {
  name: string = 'router';
  version: string = '1.0.0';
  description: string = 'Unified routing protocol component';

  static readonly SCHEME_COCONUT_NATIVE = 'coconut://native/';
  static readonly SCHEME_COCONUT_H5 = 'coconut://h5/';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'open':
        return this.open(paramsJson);
      case 'back':
        return this.back();
      case 'getScheme':
        return this.getScheme();
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private open(paramsJson: string): string {
    const url = this.getParam(paramsJson, 'url');
    if (!url) {
      return this.error('200007', 'URL is required');
    }

    const isNewWindow = this.getParam(paramsJson, 'isNewWindow') === 'true';
    Logger.d(this.name, `Routing to: ${url} (newWindow: ${isNewWindow})`);

    if (url.startsWith(RouterComponent.SCHEME_COCONUT_NATIVE)) {
      return this.handleNativeRoute(url);
    } else if (url.startsWith(RouterComponent.SCHEME_COCONUT_H5)) {
      return this.handleH5Route(url, isNewWindow);
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      return this.handleHttpRoute(url, isNewWindow);
    }

    return this.error('200007', `Unsupported URL scheme: ${url}`);
  }

  private handleNativeRoute(url: string): string {
    const match = url.match(/^coconut:\/\/native\/([^?]+)/);
    const pageName = match ? match[1] : '';
    Logger.d(this.name, `Native route: page=${pageName}`);
    const builder = new JsonObject();
    builder.putBool('routed', true);
    builder.put('type', 'native');
    builder.put('page', pageName);
    return this.success(builder);
  }

  private handleH5Route(url: string, isNewWindow: boolean): string {
    const match = url.match(/^coconut:\/\/h5\/(.+)/);
    const path = match ? match[1] : '';
    Logger.d(this.name, `H5 route: path=${path}, newWindow=${isNewWindow}`);
    const builder = new JsonObject();
    builder.putBool('routed', true);
    builder.put('type', 'h5');
    builder.put('path', path);
    return this.success(builder);
  }

  private handleHttpRoute(url: string, isNewWindow: boolean): string {
    Logger.d(this.name, `HTTP route: ${url}, newWindow=${isNewWindow}`);

    const ctx = this.getComponentContext();
    const host = ctx ? ctx.host : null;
    const webController = host ? host.getWebController() : null;
    if (webController && !isNewWindow) {
      webController.loadUrl(url);
    }

    const builder = new JsonObject();
    builder.putBool('routed', true);
    builder.put('type', 'http');
    builder.put('url', url);
    return this.success(builder);
  }

  private back(): string {
    const ctx = this.getComponentContext();
    const host = ctx ? ctx.host : null;
    const webController = host ? host.getWebController() : null;
    if (webController && webController.accessBackward()) {
      webController.backward();
      const builder = new JsonObject();
      builder.putBool('success', true);
      return this.success(builder);
    }
    const builder = new JsonObject();
    builder.putBool('success', false);
    builder.put('message', 'Cannot go back');
    return this.success(builder);
  }

  private getScheme(): string {
    const builder = new JsonObject();
    builder.put('scheme', 'coconut');
    builder.put('nativePrefix', RouterComponent.SCHEME_COCONUT_NATIVE);
    builder.put('h5Prefix', RouterComponent.SCHEME_COCONUT_H5);
    return this.success(builder);
  }
}
