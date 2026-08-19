import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { HttpClient, HttpConfig, HttpMethod, HttpRequest, HttpResponse,
  RequestInterceptor, HttpErrorCode } from '@coconut/network';
import { FakeAdapter } from './FakeAdapter';

class RecordingInterceptor implements RequestInterceptor {
  name: string
  log: string[]

  constructor(name: string, log: string[]) {
    this.name = name
    this.log = log
  }

  async onRequest(request: HttpRequest): Promise<HttpRequest> {
    this.log.push(`${this.name}:req`)
    return request
  }

  async onResponse(response: HttpResponse): Promise<HttpResponse> {
    this.log.push(`${this.name}:resp`)
    return response
  }
}

export default function callTest() {
  describe('Call', () => {
    let fake: FakeAdapter = new FakeAdapter()
    let client: HttpClient = new HttpClient(new HttpConfig(), fake)

    beforeEach(() => {
      fake = new FakeAdapter()
      const config = new HttpConfig()
      config.baseUrl = 'https://api.test.com'  // UrlGuard 要求完整 http/https URL
      config.retryDelay = 10  // 测试重试不等 1s
      client = new HttpClient(config, fake)
    })

    it('envelope200_parsesCodeMsgData', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000","msg":"ok","data":{"id":1},"timestamp":"t1"}')
      const resp = await client.newRequest('/users/1').buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      expect(resp.httpStatus).assertEqual(200)
      expect(resp.msg).assertEqual('ok')
      expect(resp.timestamp).assertEqual('t1')
      const data = resp.data as Record<string, Object>
      expect(data['id']).assertEqual(1)
      // 响应头透传 + 请求 contentType 默认值
      expect(resp.headers['Content-Type']).assertEqual('application/json')
      expect(fake.requests[0].contentType).assertEqual('application/json')
    });

    it('envelopeBusinessFail_codeKept_successFalse', 0, async () => {
      fake.envelopeResponse(200, '{"code":"500000","msg":"server busy","data":null}')
      const resp = await client.newRequest('/x').buildCall().execute()
      expect(resp.httpStatus).assertEqual(200)
      expect(resp.isSuccess()).assertFalse()
      expect(resp.code).assertEqual('500000')
    });

    it('http404_returnsHttpError', 0, async () => {
      fake.envelopeResponse(404, '{"code":"000000","msg":"not found"}')
      const resp = await client.newRequest('/missing').buildCall().execute()
      expect(resp.isSuccess()).assertFalse()
      expect(resp.httpStatus).assertEqual(404)
      expect(resp.code).assertEqual('404')
      expect(resp.msg).assertEqual('资源不存在')
    });

    it('nonEnvelopeBody_passesThroughWithDefaultCode', 0, async () => {
      fake.rawResponse(200, '{"name":"manifest","version":"1.0.0"}')
      const resp = await client.newRequest('/manifest.json').buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      expect(resp.code).assertEqual('000000')
      const data = resp.data as Record<string, Object>
      expect(data['version']).assertEqual('1.0.0')
    });

    it('retry_failsTwiceThenSucceeds', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000","msg":"ok"}')
      fake.failFirstCount = 2
      fake.failError = new Error('connection reset')
      const config = client.getConfig()
      expect(config.retryCount).assertEqual(2)
      const resp = await client.newRequest('/x').buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      expect(fake.sendCount).assertEqual(3)
    });

    it('retryExhausted_returnsNetworkError', 0, async () => {
      fake.failFirstCount = 10  // 永远失败
      fake.failError = new Error('connection refused')
      const resp = await client.newRequest('/x').buildCall().execute()
      expect(resp.isSuccess()).assertFalse()
      expect(resp.code).assertEqual(String(HttpErrorCode.NETWORK_ERROR))
      expect(resp.httpStatus).assertEqual(0)
      expect(fake.sendCount).assertEqual(3)  // 1 + 2 retries
    });

    it('timeoutError_mapsToTimeoutCode', 0, async () => {
      fake.failFirstCount = 10
      fake.failError = new Error('Timeout after 5000ms')
      const resp = await client.newRequest('/x').buildCall().execute()
      expect(resp.code).assertEqual(String(HttpErrorCode.TIMEOUT_ERROR))
    });

    it('headerMerge_requestOverridesConfig', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      const config = client.getConfig()
      config.headers['X-Common'] = '1'
      config.headers['X-Over'] = 'config'
      const headers: Record<string, string> = { 'X-Over': 'req', 'X-Only': 'r' }
      await client.newRequest('/x', { headers: headers }).buildCall().execute()
      const sent = fake.requests[0].headers
      expect(sent['X-Common']).assertEqual('1')
      expect(sent['X-Over']).assertEqual('req')
      expect(sent['X-Only']).assertEqual('r')
    });

    it('getUrlParams_encodedAndAppended', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      const config = client.getConfig()
      config.baseUrl = 'https://api.test.com'
      const params: Record<string, string> = { 'a': '1', 'b': '2 3' }
      await client.newRequest('/items', { params: params }).buildCall().execute()
      expect(fake.requests[0].url).assertEqual('https://api.test.com/items?a=1&b=2%203')
    });

    it('urlGuardBlock_doesNotHitAdapter', 0, async () => {
      const config = new HttpConfig()  // 无 baseUrl，用绝对 URL 测守卫
      config.allowedDomains = ['foo.com']
      config.retryDelay = 10
      const guardClient = new HttpClient(config, fake)
      const resp = await guardClient.newRequest('http://evil.com/steal').buildCall().execute()
      expect(resp.isSuccess()).assertFalse()
      expect(resp.code).assertEqual(String(HttpErrorCode.URL_BLOCKED))
      expect(fake.sendCount).assertEqual(0)
      expect(resp.msg.includes('出站守卫')).assertTrue()
    });

    it('urlGuard_allowedDomain_passes', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      const config = new HttpConfig()  // 无 baseUrl，用绝对 URL 测守卫
      config.allowedDomains = ['foo.com']
      config.retryDelay = 10
      const guardClient = new HttpClient(config, fake)
      const resp = await guardClient.newRequest('https://api.foo.com/x').buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      expect(fake.sendCount).assertEqual(1)
    });

    it('interceptors_requestOrder_responseReverse', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      const log: string[] = []
      client.addInterceptor(new RecordingInterceptor('A', log))
      client.addInterceptor(new RecordingInterceptor('B', log))
      await client.newRequest('/x').buildCall().execute()
      expect(log.join(',')).assertEqual('A:req,B:req,B:resp,A:resp')
    });

    it('requestTimeout_overridesConfig', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      const config = client.getConfig()
      config.connectTimeout = 5000
      config.readTimeout = 6000
      await client.newRequest('/x').setTimeout(111, 222).buildCall().execute()
      expect(fake.requests[0].connectTimeout).assertEqual(111)
      expect(fake.requests[0].readTimeout).assertEqual(222)
      // 不覆盖时走 config
      await client.newRequest('/y').buildCall().execute()
      expect(fake.requests[1].connectTimeout).assertEqual(5000)
      expect(fake.requests[1].readTimeout).assertEqual(6000)
    });
  });
}
