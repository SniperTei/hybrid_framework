import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { HttpClient, HttpConfig, HttpMethod, MockInterceptor } from '@coconut/network';
import { FakeAdapter } from './FakeAdapter';

export default function mockInterceptorTest() {
  describe('MockInterceptor', () => {
    let fake: FakeAdapter = new FakeAdapter()
    let client: HttpClient = new HttpClient(new HttpConfig(), fake)
    let mock: MockInterceptor = new MockInterceptor()

    beforeEach(() => {
      fake = new FakeAdapter()
      fake.envelopeResponse(200, '{"code":"000000","msg":"real"}')
      mock = new MockInterceptor()
      const config = new HttpConfig()
      config.baseUrl = 'https://api.test.com'  // passthrough 用例需完整 URL 过 UrlGuard
      config.retryDelay = 10
      client = new HttpClient(config, fake)
      client.addInterceptor(mock)
    })

    it('exactUrlHit_returnsMockData_skipsAdapter', 0, async () => {
      mock.addRule({ url: '/api/user', method: HttpMethod.GET, data: JSON.parse('{"name":"test"}') })
      const resp = await client.newRequest('/api/user').buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      expect(resp.httpStatus).assertEqual(200)
      const data = resp.data as Record<string, Object>
      expect(data['name']).assertEqual('test')
      expect(fake.sendCount).assertEqual(0)
    });

    it('prefixUrlHit_withWildcard', 0, async () => {
      mock.addRule({ url: '/api/items*', data: JSON.parse('{"list":[]}') })
      const resp = await client.newRequest('/api/items/1').buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      expect(fake.sendCount).assertEqual(0)
    });

    it('methodMismatch_passesThroughToAdapter', 0, async () => {
      mock.addRule({ url: '/api/user', method: HttpMethod.POST, data: JSON.parse('{}') })
      const resp = await client.newRequest('/api/user').buildCall().execute()  // GET
      expect(fake.sendCount).assertEqual(1)
      expect(resp.msg).assertEqual('real')
    });

    it('urlMismatch_passesThroughToAdapter', 0, async () => {
      mock.addRule({ url: '/api/other', data: JSON.parse('{}') })
      await client.newRequest('/api/user').buildCall().execute()
      expect(fake.sendCount).assertEqual(1)
    });

    it('errorRule_mockFailures_withStatusAndCode', 0, async () => {
      mock.addRule({ url: '/api/login', httpStatus: 500, code: '500000', msg: 'mock fail' })
      const resp = await client.newRequest('/api/login', { method: HttpMethod.POST }).buildCall().execute()
      expect(resp.isSuccess()).assertFalse()
      expect(resp.httpStatus).assertEqual(500)
      expect(resp.code).assertEqual('500000')
      expect(resp.msg).assertEqual('mock fail')
      expect(fake.sendCount).assertEqual(0)
    });

    it('mockRule_anyMethod_whenOmitted', 0, async () => {
      mock.addRule({ url: '/api/any', data: JSON.parse('{"ok":1}') })
      const respGet = await client.newRequest('/api/any').buildCall().execute()
      const respPost = await client.newRequest('/api/any', { method: HttpMethod.POST }).buildCall().execute()
      expect(respGet.isSuccess()).assertTrue()
      expect(respPost.isSuccess()).assertTrue()
      expect(fake.sendCount).assertEqual(0)
    });

    it('clearAll_removesRules', 0, async () => {
      mock.addRule({ url: '/api/user', data: JSON.parse('{}') })
      mock.clearAll()
      await client.newRequest('/api/user').buildCall().execute()
      expect(fake.sendCount).assertEqual(1)
    });

    it('manualEnableMocking_withoutInterceptor', 0, async () => {
      const bareClient = new HttpClient(new HttpConfig(), fake)
      const resp = await bareClient.newRequest('/api/user')
        .enableMocking(JSON.parse('{"name":"manual"}'))
        .buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      const data = resp.data as Record<string, Object>
      expect(data['name']).assertEqual('manual')
      expect(fake.sendCount).assertEqual(0)
    });

    it('mockSkipsUrlGuard_notBlocked', 0, async () => {
      // 守卫配置成拦所有，mock 仍应短路成功（mock 不出网）
      const config = new HttpConfig()
      config.allowedDomains = ['foo.com']
      const guardedClient = new HttpClient(config, fake)
      guardedClient.addInterceptor(mock)
      mock.addRule({ url: 'http://evil.com/api', data: JSON.parse('{"ok":1}') })
      const resp = await guardedClient.newRequest('http://evil.com/api').buildCall().execute()
      expect(resp.isSuccess()).assertTrue()
      expect(fake.sendCount).assertEqual(0)
    });
  });
}
