import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { BridgeTokenManager } from '@coconut/sdk';

export default function bridgeTokenManagerTest() {
  describe('BridgeTokenManager', () => {
    beforeAll(() => {
      BridgeTokenManager.reset();
      BridgeTokenManager.enabled = true;
    });

    afterAll(() => {
      BridgeTokenManager.reset();
      BridgeTokenManager.enabled = true;
    });

    it('initial_token_isEmpty', 0, () => {
      BridgeTokenManager.reset();
      expect(BridgeTokenManager.getToken()).assertEqual('');
    });

    it('emptyToken_validatesAnyToken', 0, () => {
      BridgeTokenManager.reset();
      expect(BridgeTokenManager.validateToken('whatever')).assertTrue();
      expect(BridgeTokenManager.validateToken('')).assertTrue();
    });

    it('generateToken_returnsNonEmpty', 0, () => {
      const token = BridgeTokenManager.generateToken();
      expect(token.length > 0).assertTrue();
    });

    it('generateToken_twice_producesDifferentTokens', 0, () => {
      const a = BridgeTokenManager.generateToken();
      const b = BridgeTokenManager.generateToken();
      expect(a !== b).assertTrue();
    });

    it('validateToken_correctToken_passes', 0, () => {
      const token = BridgeTokenManager.generateToken();
      expect(BridgeTokenManager.validateToken(token)).assertTrue();
    });

    it('validateToken_wrongToken_fails', 0, () => {
      BridgeTokenManager.generateToken();
      expect(BridgeTokenManager.validateToken('wrong-token')).assertFalse();
    });

    it('disabled_passesAllTokens', 0, () => {
      BridgeTokenManager.generateToken();
      BridgeTokenManager.enabled = false;
      expect(BridgeTokenManager.validateToken('wrong')).assertTrue();
      BridgeTokenManager.enabled = true;
    });

    it('reset_clearsToken', 0, () => {
      BridgeTokenManager.generateToken();
      BridgeTokenManager.reset();
      expect(BridgeTokenManager.getToken()).assertEqual('');
    });
  });
}
