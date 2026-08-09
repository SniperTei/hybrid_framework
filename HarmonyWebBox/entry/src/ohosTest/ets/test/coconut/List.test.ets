import errorCodeTest from './bridge/model/ErrorCode.test';
import bridgeRequestTest from './bridge/model/BridgeRequest.test';
import bridgeResponseTest from './bridge/model/BridgeResponse.test';
import securityResultTest from './bridge/model/SecurityResult.test';
import jsonHelperTest from './utils/JsonHelper.test';
import bridgeTokenManagerTest from './bridge/BridgeTokenManager.test';
import bridgeSecurityValidatorTest from './bridge/BridgeSecurityValidator.test';
import bridgePerformanceTest from './bridge/BridgePerformance.test';
import securityAuditLogTest from './bridge/SecurityAuditLog.test';
import baseComponentTest from './component/BaseComponent.test';
import componentManagerTest from './component/ComponentManager.test';
import componentExceptionTest from './component/ComponentException.test';
import environmentTest from './config/Environment.test';

export default function testsuite() {
  errorCodeTest();
  bridgeRequestTest();
  bridgeResponseTest();
  securityResultTest();
  jsonHelperTest();
  bridgeTokenManagerTest();
  bridgeSecurityValidatorTest();
  bridgePerformanceTest();
  securityAuditLogTest();
  baseComponentTest();
  componentManagerTest();
  componentExceptionTest();
  environmentTest();
}
