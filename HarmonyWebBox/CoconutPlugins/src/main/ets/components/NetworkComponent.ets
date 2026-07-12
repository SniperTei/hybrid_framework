import { http, connection } from '@kit.NetworkKit';
import { BaseComponent, Logger, JsonObject, JsonParser } from '@coconut/sdk';

/**
 * Network Component
 *
 * Provides network status and HTTP request proxy
 */
export class NetworkComponent extends BaseComponent {
  name: string = 'network';
  version: string = '2.0.0';
  description: string = 'Network status and native HTTP proxy component';

  async handle(functionName: string, paramsJson: string): Promise<string> {
    switch (functionName) {
      case 'getType':
        return this.getNetworkType();
      case 'getState':
        return this.getNetworkState();
      case 'isConnected':
        return this.isConnected();
      case 'request':
        return this.httpRequest(paramsJson);
      case 'get':
        return this.httpGet(paramsJson);
      case 'post':
        return this.httpPost(paramsJson);
      default:
        return this.functionNotSupportedError(functionName);
    }
  }

  private async getNetworkType(): Promise<string> {
    try {
      const netHandle = await connection.getDefaultNet();
      const capabilities = await connection.getNetCapabilities(netHandle);
      let type = 'unknown';
      if (capabilities && capabilities.bearerTypes) {
        if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) !== -1) {
          type = 'wifi';
        } else if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_CELLULAR) !== -1) {
          type = 'cellular';
        } else if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_ETHERNET) !== -1) {
          type = 'ethernet';
        }
      }
      const builder = new JsonObject();
      builder.put('type', type);
      return this.success(builder);
    } catch (e) {
      const builder = new JsonObject();
      builder.put('type', 'none');
      return this.success(builder);
    }
  }

  private async getNetworkState(): Promise<string> {
    try {
      const netHandle = await connection.getDefaultNet();
      const capabilities = await connection.getNetCapabilities(netHandle);
      let type = 'unknown';
      if (capabilities && capabilities.bearerTypes) {
        if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) !== -1) {
          type = 'wifi';
        } else if (capabilities.bearerTypes.indexOf(connection.NetBearType.BEARER_CELLULAR) !== -1) {
          type = 'cellular';
        }
      }
      const builder = new JsonObject();
      builder.putBool('isConnected', true);
      builder.put('type', type);
      return this.success(builder);
    } catch (e) {
      const builder = new JsonObject();
      builder.putBool('isConnected', false);
      builder.put('type', 'none');
      return this.success(builder);
    }
  }

  private async isConnected(): Promise<string> {
    try {
      const netHandle = await connection.getDefaultNet();
      const capabilities = await connection.getNetCapabilities(netHandle);
      const builder = new JsonObject();
      builder.putBool('isConnected', capabilities != null);
      return this.success(builder);
    } catch (e) {
      const builder = new JsonObject();
      builder.putBool('isConnected', false);
      return this.success(builder);
    }
  }

  private async httpRequest(paramsJson: string): Promise<string> {
    const url = this.getParam(paramsJson, 'url');
    if (!url) {
      return this.error('200007', 'url is required');
    }

    const method = this.getParam(paramsJson, 'method', 'GET').toUpperCase();
    const timeout = this.getIntParam(paramsJson, 'timeout', 15000);
    const body = this.getParam(paramsJson, 'body', '');
    const contentType = this.getParam(paramsJson, 'contentType', 'application/json');

    Logger.d(this.name, `Native request: ${method} ${url}`);

    const httpRequest = http.createHttp();

    class HttpRequestHeader {
      public contentType: string;
      constructor(contentType: string) {
        this.contentType = contentType;
      }
    }

    try {
      const option: http.HttpRequestOptions = {
        method: method as http.RequestMethod,
        header: new HttpRequestHeader(contentType),
        readTimeout: timeout,
        connectTimeout: timeout,
        expectDataType: http.HttpDataType.STRING
      };
      if (body && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
        option.extraData = body;
      }
      const response = await httpRequest.request(url, option);
      const builder = new JsonObject();
      builder.putNumber('statusCode', response.responseCode);
      if (typeof response.result === 'string') {
        builder.put('body', response.result as string);
      } else {
        builder.put('body', JSON.stringify(response.result));
      }
      return this.success(builder);
    } catch (e) {
      const builder = new JsonObject();
      builder.putNumber('statusCode', -1);
      builder.put('error', e instanceof Error ? e.message : 'Request failed');
      return this.success(builder);
    } finally {
      httpRequest.destroy();
    }
  }

  private async httpGet(paramsJson: string): Promise<string> {
    // Inject method=GET into the paramsJson
    const mergedJson = this.mergeMethod(paramsJson, 'GET');
    return this.httpRequest(mergedJson);
  }

  private async httpPost(paramsJson: string): Promise<string> {
    const mergedJson = this.mergeMethod(paramsJson, 'POST');
    return this.httpRequest(mergedJson);
  }

  /**
   * Merge method into paramsJson by injecting "method":"GET"/"POST" at the right position
   */
  private mergeMethod(paramsJson: string, method: string): string {
    // Simple approach: replace closing brace or insert before it
    const injection = `"method":"${method}",`;
    const openBrace = paramsJson.indexOf('{');
    if (openBrace === -1) {
      return `{${injection}"placeholder":""}`;
    }
    // Insert right after the opening brace
    return paramsJson.substring(0, openBrace + 1) + injection + paramsJson.substring(openBrace + 1);
  }
}
