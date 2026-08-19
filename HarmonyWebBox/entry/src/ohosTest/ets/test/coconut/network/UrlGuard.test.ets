import { describe, it, expect } from '@ohos/hypium';
import { UrlGuard } from '@coconut/network';

export default function urlGuardTest() {
  describe('UrlGuard', () => {
    it('http_withEmptyDomains_allows', 0, () => {
      const r = UrlGuard.validate('http://anything.example.com/path', [])
      expect(r.allowed).assertTrue()
    });

    it('https_exactHostMatch_allows', 0, () => {
      const r = UrlGuard.validate('https://foo.com/api', ['foo.com'])
      expect(r.allowed).assertTrue()
    });

    it('subdomainSuffixMatch_allows', 0, () => {
      const r = UrlGuard.validate('https://api.foo.com/api', ['foo.com'])
      expect(r.allowed).assertTrue()
    });

    it('subdomainSuffixMatch_multiLevel_allows', 0, () => {
      const r = UrlGuard.validate('https://a.b.foo.com/api', ['foo.com'])
      expect(r.allowed).assertTrue()
    });

    it('suffixAttack_isBlocked', 0, () => {
      const r = UrlGuard.validate('https://api.foo.com.evil.com/api', ['foo.com'])
      expect(r.allowed).assertFalse()
      expect(r.reason.includes('allowedDomains')).assertTrue()
    });

    it('portIsStrippedFromHost', 0, () => {
      const r = UrlGuard.validate('https://api.foo.com:8443/api', ['foo.com'])
      expect(r.allowed).assertTrue()
    });

    it('caseInsensitiveSchemeAndHost', 0, () => {
      const r = UrlGuard.validate('HTTP://API.FOO.COM/api', ['FOO.com'])
      expect(r.allowed).assertTrue()
    });

    it('coconutScheme_isBlocked', 0, () => {
      const r = UrlGuard.validate('coconut://demo/index.html', [])
      expect(r.allowed).assertFalse()
      expect(r.reason.includes('scheme')).assertTrue()
    });

    it('fileScheme_isBlocked', 0, () => {
      const r = UrlGuard.validate('file:///etc/passwd', [])
      expect(r.allowed).assertFalse()
    });

    it('javascriptUri_isBlocked', 0, () => {
      const r = UrlGuard.validate('javascript:alert(1)', [])
      expect(r.allowed).assertFalse()
    });

    it('noScheme_isBlocked', 0, () => {
      const r = UrlGuard.validate('www.foo.com/path', ['foo.com'])
      expect(r.allowed).assertFalse()
    });

    it('emptyHost_isBlocked', 0, () => {
      const r = UrlGuard.validate('http:///path', [])
      expect(r.allowed).assertFalse()
    });

    it('hostNotInWhitelist_isBlocked', 0, () => {
      const r = UrlGuard.validate('https://evil.com/api', ['foo.com', 'bar.com'])
      expect(r.allowed).assertFalse()
      expect(r.reason.includes('evil.com')).assertTrue()
    });
  });
}
