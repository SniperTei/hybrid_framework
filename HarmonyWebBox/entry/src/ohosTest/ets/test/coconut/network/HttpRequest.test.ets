import { describe, it, expect } from '@ohos/hypium';
import { HttpRequest, HttpMethod, HttpClient, HttpConfig, Call } from '@coconut/network';

export default function httpRequestTest() {
  describe('HttpRequest', () => {
    it('defaultMethod_isGet', 0, () => {
      const req = new HttpRequest('/x')
      expect(req.method).assertEqual(HttpMethod.GET)
      expect(req.connectTimeout).assertEqual(-1)
      expect(req.readTimeout).assertEqual(-1)
    });

    it('postParams_becomeBody', 0, () => {
      const params: Record<string, string> = { 'a': '1' }
      const req = new HttpRequest('/x', { method: HttpMethod.POST, params: params })
      expect(req.body).assertEqual(params)
      expect(Object.keys(req.params).length).assertEqual(0)
    });

    it('putParams_becomeBody', 0, () => {
      const params: Record<string, string> = { 'a': '1' }
      const req = new HttpRequest('/x', { method: HttpMethod.PUT, params: params })
      expect(req.body).assertEqual(params)
    });

    it('getParams_stayAsQuery', 0, () => {
      const params: Record<string, string> = { 'a': '1' }
      const req = new HttpRequest('/x', { method: HttpMethod.GET, params: params })
      expect(req.params).assertEqual(params)
      expect(req.body).assertEqual(null)
    });

    it('explicitBody_overridesParamsBody', 0, () => {
      const params: Record<string, string> = { 'a': '1' }
      const body: Record<string, Object> = { 'b': '2' }
      const req = new HttpRequest('/x', { method: HttpMethod.POST, params: params, body: body })
      expect(req.body).assertEqual(body)
    });

    it('chainSetters_returnSelf', 0, () => {
      const req = new HttpRequest('/x')
      const body: Record<string, Object> = { 'k': 'v' }
      const self = req.setHeader('X-A', '1').setBody(body).setTag('t1').setTimeout(100, 200)
      expect(self).assertEqual(req)
      expect(req.headers['X-A']).assertEqual('1')
      expect(req.body).assertEqual(body)
      expect(req.tag).assertEqual('t1')
      expect(req.connectTimeout).assertEqual(100)
      expect(req.readTimeout).assertEqual(200)
    });

    it('buildCall_withoutContext_throws', 0, () => {
      const req = new HttpRequest('/x')
      let thrown = false
      let message = ''
      try {
        req.buildCall()
      } catch (e) {
        thrown = true
        message = (e as Error).message
      }
      expect(thrown).assertTrue()
      expect(message.includes('未绑定 HttpClient')).assertTrue()
    });

    it('buildCall_withClientContext_returnsCall', 0, () => {
      const client = new HttpClient(new HttpConfig())
      const req = client.newRequest('/x')
      const call = req.buildCall()
      expect(call instanceof Call).assertTrue()
    });
  });
}
