import { describe, it, expect } from '@ohos/hypium';
import { Environment, EnvironmentConfig } from '@coconut/sdk';

export default function environmentTest() {
  describe('Environment', () => {
    it('enumValues_areDistinct', 0, () => {
      expect(Environment.DEV).assertEqual('dev');
      expect(Environment.TEST).assertEqual('test');
      expect(Environment.STAGING).assertEqual('staging');
      expect(Environment.PROD).assertEqual('prod');
    });

    it('getH5Domain_returnsNonEmptyForAll', 0, () => {
      expect(EnvironmentConfig.getH5Domain(Environment.DEV).length > 0).assertTrue();
      expect(EnvironmentConfig.getH5Domain(Environment.TEST).length > 0).assertTrue();
      expect(EnvironmentConfig.getH5Domain(Environment.STAGING).length > 0).assertTrue();
      expect(EnvironmentConfig.getH5Domain(Environment.PROD).length > 0).assertTrue();
    });

    it('getApiDomain_returnsNonEmptyForAll', 0, () => {
      expect(EnvironmentConfig.getApiDomain(Environment.DEV).length > 0).assertTrue();
      expect(EnvironmentConfig.getApiDomain(Environment.TEST).length > 0).assertTrue();
      expect(EnvironmentConfig.getApiDomain(Environment.STAGING).length > 0).assertTrue();
      expect(EnvironmentConfig.getApiDomain(Environment.PROD).length > 0).assertTrue();
    });

    it('getDisplayName_returnsHumanReadable', 0, () => {
      expect(EnvironmentConfig.getDisplayName(Environment.DEV)).assertEqual('Development');
      expect(EnvironmentConfig.getDisplayName(Environment.TEST)).assertEqual('Test');
      expect(EnvironmentConfig.getDisplayName(Environment.STAGING)).assertEqual('Staging');
      expect(EnvironmentConfig.getDisplayName(Environment.PROD)).assertEqual('Production');
    });
  });
}
