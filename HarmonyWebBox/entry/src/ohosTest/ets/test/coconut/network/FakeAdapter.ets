import { IHttpAdapter, AdapterRequest, AdapterResponse } from '@coconut/network';

/**
 * 测试用 Fake 传输层：可脚本化响应 / 前 N 次抛错
 */
export class FakeAdapter implements IHttpAdapter {
  /** 收到的所有请求（按顺序） */
  requests: AdapterRequest[] = []
  /** 成功时返回的响应 */
  response: AdapterResponse = {
    httpStatus: 200,
    headers: {},
    body: null,
  };
  /** 前 failFirstCount 次调用抛 failError（模拟瞬时故障测重试） */
  failFirstCount: number = 0
  failError: Error | null = null
  /** 总调用次数 */
  sendCount: number = 0

  sendRequest(request: AdapterRequest): Promise<AdapterResponse> {
    this.requests.push(request)
    this.sendCount++
    if (this.failError !== null && this.sendCount <= this.failFirstCount) {
      return Promise.reject(this.failError)
    }
    return Promise.resolve(this.response)
  }

  /** 设置 envelope 形式的成功响应 */
  envelopeResponse(httpStatus: number, bodyJson: string): void {
    const resp: AdapterResponse = {
      httpStatus: httpStatus,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.parse(bodyJson) as Record<string, Object>,
    }
    this.response = resp
  }

  /** 设置非 envelope 响应（body 直通） */
  rawResponse(httpStatus: number, bodyJson: string): void {
    const resp: AdapterResponse = {
      httpStatus: httpStatus,
      headers: {},
      body: JSON.parse(bodyJson) as Record<string, Object>,
    }
    this.response = resp
  }
}
