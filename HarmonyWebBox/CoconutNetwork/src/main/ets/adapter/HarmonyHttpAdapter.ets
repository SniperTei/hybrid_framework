/**
 * 基于 @kit.NetworkKit 系统栈的 Adapter 实现
 * 唯一依赖 HarmonyOS HTTP SDK 的地方
 */

import { http } from '@kit.NetworkKit'
import { IHttpAdapter, AdapterRequest, AdapterResponse, FormDataItem, HttpResponseType } from './IHttpAdapter'

export class HarmonyHttpAdapter implements IHttpAdapter {
  async sendRequest(request: AdapterRequest): Promise<AdapterResponse> {
    const httpRequest = http.createHttp()
    try {
      const options = this.toSystemOptions(request)
      const response = await httpRequest.request(request.url, options)
      return this.toAdapterResponse(response)
    } finally {
      httpRequest.destroy()
    }
  }

  /** AdapterRequest → http.HttpRequestOptions */
  private toSystemOptions(request: AdapterRequest): http.HttpRequestOptions {
    const options: http.HttpRequestOptions = {
      method: this.toSystemMethod(request.method),
      header: request.headers,
      connectTimeout: request.connectTimeout,
      readTimeout: request.readTimeout,
      expectDataType: request.responseType === HttpResponseType.BYTES ?
        http.HttpDataType.ARRAY_BUFFER : http.HttpDataType.OBJECT,
    }

    if (request.multiFormDataList.length > 0) {
      const items: http.MultiFormData[] = []
      for (const item of request.multiFormDataList) {
        const fd: http.MultiFormData = {
          name: item.name,
          contentType: item.contentType,
          remoteFileName: item.remoteFileName ?? '',
          data: item.data,
        }
        items.push(fd)
      }
      options.multiFormDataList = items
    } else if (request.body !== null) {
      options.extraData = request.body
    }

    return options
  }

  /** 字符串方法名 → http.RequestMethod */
  private toSystemMethod(method: string): http.RequestMethod {
    const map: Record<string, http.RequestMethod> = {
      'GET': http.RequestMethod.GET,
      'POST': http.RequestMethod.POST,
      'PUT': http.RequestMethod.PUT,
      'DELETE': http.RequestMethod.DELETE,
    }
    return map[method] ?? http.RequestMethod.GET
  }

  /** http.HttpResponse → AdapterResponse */
  private toAdapterResponse(response: http.HttpResponse): AdapterResponse {
    const headers: Record<string, string> = {}
    if (response.header) {
      const headerObj = response.header as Record<string, string>
      for (const key of Object.keys(headerObj)) {
        headers[key] = String(headerObj[key])
      }
    }

    // bytes 模式：result 为 ArrayBuffer，透传到 rawBody，body 置 null
    if (response.result instanceof ArrayBuffer) {
      const bytesResp: AdapterResponse = {
        httpStatus: response.responseCode as number,
        headers: headers,
        body: null,
        rawBody: response.result,
      }
      return bytesResp
    }

    const adapterResponse: AdapterResponse = {
      httpStatus: response.responseCode as number,
      headers: headers,
      body: (response.result as Object) ?? null,
    }
    return adapterResponse
  }
}
