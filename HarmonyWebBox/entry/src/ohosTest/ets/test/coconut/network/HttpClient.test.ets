import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { util } from '@kit.ArkTS';
import { HttpClient, HttpConfig, HttpMethod, HttpResponse, HttpResponseType,
  MockInterceptor } from '@coconut/network';
import { FakeAdapter } from './FakeAdapter';

/** string → 精确长度 ArrayBuffer */
function strToBuffer(s: string): ArrayBuffer {
  const encoder = new util.TextEncoder()
  return encoder.encodeInto(s).buffer as ArrayBuffer
}

/** 两个 ArrayBuffer 字节级比较 */
function bytesEqual(a: ArrayBuffer, b: ArrayBuffer): boolean {
  if (a.byteLength !== b.byteLength) {
    return false
  }
  const va = new Uint8Array(a)
  const vb = new Uint8Array(b)
  for (let i = 0; i < va.length; i++) {
    if (va[i] !== vb[i]) {
      return false
    }
  }
  return true
}

export default function httpClientTest() {
  describe('HttpClient', () => {
    let fake: FakeAdapter = new FakeAdapter()
    let client: HttpClient = new HttpClient(new HttpConfig(), fake)

    beforeEach(() => {
      fake = new FakeAdapter()
      const config = new HttpConfig()
      config.baseUrl = 'https://api.test.com'
      config.retryDelay = 10
      client = new HttpClient(config, fake)
    })

    it('oneShotGet_envelope200', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000","msg":"ok","data":{"id":1}}')
      const resp = await client.get('/users/1')
      expect(resp.isSuccess()).assertTrue()
      expect(resp.httpStatus).assertEqual(200)
      expect(fake.requests[0].method).assertEqual('GET')
    });

    it('oneShotPost_bodyDelivered', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      const body: Record<string, Object> = { 'name': 'coconut' }
      const resp = await client.post('/users', body)
      expect(resp.isSuccess()).assertTrue()
      expect(fake.requests[0].method).assertEqual('POST')
      const sent = fake.requests[0].body as Record<string, Object>
      expect(sent['name']).assertEqual('coconut')
    });

    it('oneShotPutDelete_methods', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      await client.put('/users/1')
      expect(fake.requests[0].method).assertEqual('PUT')
      await client.delete('/users/1')
      expect(fake.requests[1].method).assertEqual('DELETE')
    });

    it('oneShotGet_paramsBecomeQuery', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      const params: Record<string, string> = { 'page': '2', 'size': '10' }
      await client.get('/items', { params: params })
      expect(fake.requests[0].url).assertEqual('https://api.test.com/items?page=2&size=10')
    });

    it('oneShotGet_timeoutOverride', 0, async () => {
      fake.envelopeResponse(200, '{"code":"000000"}')
      await client.get('/slow', { connectTimeout: 111, readTimeout: 222 })
      expect(fake.requests[0].connectTimeout).assertEqual(111)
      expect(fake.requests[0].readTimeout).assertEqual(222)
    });

    it('bytes200_rawDataPassthrough', 0, async () => {
      const payload = strToBuffer('binary-content-\x00\x01')
      fake.bytesResponse(200, payload)
      const resp = await client.get('/pkg/file.bin', { responseType: HttpResponseType.BYTES })
      expect(resp.isSuccess()).assertTrue()
      expect(resp.data).assertNull()
      expect(resp.rawData !== null).assertTrue()
      expect(bytesEqual(resp.rawData!, payload)).assertTrue()
    });

    it('bytes404_httpError', 0, async () => {
      fake.bytesResponse(404, strToBuffer('not found'))
      const resp = await client.get('/missing.bin', { responseType: HttpResponseType.BYTES })
      expect(resp.isSuccess()).assertFalse()
      expect(resp.code).assertEqual('404')
      expect(resp.msg).assertEqual('资源不存在')
    });

    it('bytesNonEnvelopeNoSniffing', 0, async () => {
      // bytes 内容恰为 envelope 形状的 JSON 也不进 envelope 解析
      fake.bytesResponse(200, strToBuffer('{"code":"999999","msg":"x"}'))
      const resp = await client.get('/manifest.json', { responseType: HttpResponseType.BYTES })
      expect(resp.code).assertEqual('000000')
      expect(resp.data).assertNull()
      expect(resp.rawData !== null).assertTrue()
    });

    it('bytesAdapterRequestCarriesResponseType', 0, async () => {
      fake.bytesResponse(200, strToBuffer('x'))
      await client.get('/f.bin', { responseType: HttpResponseType.BYTES })
      expect(fake.requests[0].responseType).assertEqual('bytes')
      // 默认 JSON
      fake.envelopeResponse(200, '{"code":"000000"}')
      await client.get('/api')
      expect(fake.requests[1].responseType).assertEqual('json')
    });

    it('mockShortCircuit_bytesRequest_rawDataNull', 0, async () => {
      const mockData: Record<string, Object> = { 'mocked': true }
      const mock = new MockInterceptor()
      mock.addRule({ url: '/mocked.bin', data: mockData })
      client.addInterceptor(mock)
      const resp = await client.get('/mocked.bin', { responseType: HttpResponseType.BYTES })
      // 已知限制：mock 短路返回 object data，rawData 恒为 null（不出网无原始字节）
      expect(resp.isSuccess()).assertTrue()
      expect(resp.rawData).assertNull()
      expect(fake.sendCount).assertEqual(0)
      const data = resp.data as Record<string, Object>
      expect(data['mocked']).assertTrue()
    });
  });
}
