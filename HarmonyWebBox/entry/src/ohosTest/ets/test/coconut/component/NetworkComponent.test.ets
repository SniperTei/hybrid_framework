import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { ComponentException, JsonParser, CoconutSDK } from '@coconut/sdk';
import { HttpClient, HttpConfig } from '@coconut/network';
import { NetworkComponent } from '../../../../../main/ets/components/NetworkComponent';
import { FakeAdapter } from '../network/FakeAdapter';

/**
 * NetworkComponent tests: request wire parsing (method whitelist / headers /
 * params / body / timeout), result shape, guard → 200007 mapping, and
 * default-client allowedDomains sync. getNetworkType/network.change are
 * device behaviors covered by e2e (shape asserted here).
 */
export default function networkComponentTest() {
  describe('NetworkComponent', () => {
    let fake: FakeAdapter = new FakeAdapter();
    let comp: NetworkComponent = new NetworkComponent();

    beforeEach(() => {
      fake = new FakeAdapter()
      fake.envelopeResponse(200, '{"code":"000000","msg":"ok","data":{"id":1}}')
      const config = new HttpConfig()
      config.retryDelay = 10
      comp = new NetworkComponent(new HttpClient(config, fake))
    })

    const expectError = async (fn: () => Promise<string>, code: string): Promise<void> => {
      let thrown: Object | null = null
      try {
        await fn()
      } catch (e) {
        thrown = e as Object
      }
      expect(thrown instanceof ComponentException).assertTrue()
      expect((thrown as ComponentException).code).assertEqual(code)
    }

    it('meta_nameAndMethods', 0, () => {
      expect(comp.name).assertEqual('network')
      expect(comp.methods.join(',')).assertEqual('request,getNetworkType')
    });

    it('unknownFunction_throws200002', 0, async () => {
      await expectError(() => comp.handle('upload', '{}'), '200002')
    });

    it('missingUrl_throws200007', 0, async () => {
      await expectError(() => comp.handle('request', '{}'), '200007')
    });

    it('unknownMethod_throws200007', 0, async () => {
      await expectError(() =>
        comp.handle('request', '{"url":"http://api.test.com/x","method":"PATCH"}'), '200007')
    });

    it('lowercaseMethod_normalizedToUpper', 0, async () => {
      const result = await comp.handle('request',
        '{"url":"http://api.test.com/x","method":"post"}')
      expect(fake.requests[0].method).assertEqual('POST')
      expect(JsonParser.getBool(result, 'success')).assertTrue()
    });

    it('defaultMethod_get', 0, async () => {
      await comp.handle('request', '{"url":"http://api.test.com/x"}')
      expect(fake.requests[0].method).assertEqual('GET')
    });

    it('headers_extracted', 0, async () => {
      await comp.handle('request',
        '{"url":"http://api.test.com/x","headers":{"X-Token":"abc","X-Env":"test"}}')
      expect(fake.requests[0].headers['X-Token']).assertEqual('abc')
      expect(fake.requests[0].headers['X-Env']).assertEqual('test')
    });

    it('queryParams_extractedAndEncoded', 0, async () => {
      await comp.handle('request',
        '{"url":"http://api.test.com/x","params":{"a":"1 2"}}')
      expect(fake.requests[0].url).assertEqual('http://api.test.com/x?a=1%202')
    });

    it('body_passedAsRawJsonString', 0, async () => {
      await comp.handle('request',
        '{"url":"http://api.test.com/x","method":"POST","body":{"a":1,"b":"x"}}')
      expect(fake.requests[0].method).assertEqual('POST')
      expect(fake.requests[0].body).assertEqual('{"a":1,"b":"x"}')
      expect(fake.requests[0].contentType).assertEqual('application/json')
    });

    it('timeoutMs_appliedToConnectAndRead', 0, async () => {
      await comp.handle('request', '{"url":"http://api.test.com/x","timeoutMs":1500}')
      expect(fake.requests[0].connectTimeout).assertEqual(1500)
      expect(fake.requests[0].readTimeout).assertEqual(1500)
    });

    it('happyPath_resultShape', 0, async () => {
      const result = await comp.handle('request', '{"url":"http://api.test.com/x"}')
      expect(JsonParser.getBool(result, 'success')).assertTrue()
      expect(JsonParser.getNumber(result, 'httpStatus')).assertEqual(200)
      expect(JsonParser.getString(result, 'code')).assertEqual('000000')
      expect(JsonParser.getString(result, 'msg')).assertEqual('ok')
      expect(JsonParser.getObject(result, 'data')).assertEqual('{"id":1}')
      expect(JsonParser.getObject(result, 'headers').length > 2).assertTrue()
      expect(JsonParser.getNumber(result, 'costTime') >= 0).assertTrue()
      expect(JsonParser.getString(result, 'message')).assertEqual('ok')
    });

    it('http501_businessFail_successFalse', 0, async () => {
      fake.envelopeResponse(501, '{"code":"000000","msg":"not implemented"}')
      const result = await comp.handle('request', '{"url":"http://api.test.com/x"}')
      expect(JsonParser.getBool(result, 'success')).assertFalse()
      expect(JsonParser.getNumber(result, 'httpStatus')).assertEqual(501)
      expect(JsonParser.getString(result, 'code')).assertEqual('501')
    });

    it('nonEnvelopeBody_dataPassthrough', 0, async () => {
      fake.rawResponse(200, '{"name":"manifest","version":"1.0.0"}')
      const result = await comp.handle('request', '{"url":"http://api.test.com/m.json"}')
      expect(JsonParser.getBool(result, 'success')).assertTrue()
      expect(JsonParser.getObject(result, 'data')).assertEqual('{"name":"manifest","version":"1.0.0"}')
    });

    it('guardBlock_mapsToBridge200007', 0, async () => {
      const config = new HttpConfig()
      config.allowedDomains = ['foo.com']
      config.retryDelay = 10
      const guarded = new NetworkComponent(new HttpClient(config, fake))
      await expectError(() => guarded.handle('request', '{"url":"http://evil.com/steal"}'), '200007')
      expect(fake.sendCount).assertEqual(0)
    });

    it('defaultClient_syncsAllowedDomainsFromSdkConfig', 0, async () => {
      const saved = CoconutSDK.config.allowedDomains
      const domains: string[] = ['synced.com']
      CoconutSDK.config.allowedDomains = domains
      const defaultComp = new NetworkComponent()
      try {
        await expectError(() =>
          defaultComp.handle('request', '{"url":"http://other.com/x"}'), '200007')
      } finally {
        CoconutSDK.config.allowedDomains = saved
      }
    });

    it('getNetworkType_shape', 0, async () => {
      const result = await comp.handle('getNetworkType', '{}')
      const type = JsonParser.getString(result, 'type')
      const valid = ['wifi', 'cellular', 'ethernet', 'none', 'unknown']
      expect(valid.includes(type)).assertTrue()
      expect(JsonParser.getBool(result, 'success')).assertTrue()
    });
  });
}
