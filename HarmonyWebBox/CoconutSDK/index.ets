// CoconutSDK - Module Exports
export { CoconutSDK } from './src/main/CoconutSDK'
export { CoconutConfig } from './src/main/ets/config/CoconutConfig'
export { Environment, EnvironmentConfig } from './src/main/ets/config/Environment'
export { Logger } from './src/main/ets/utils/Logger'
export { JsonObject, JsonParser } from './src/main/ets/utils/JsonHelper'

// Bridge
export { CoconutBridgeImpl } from './src/main/ets/bridge/CoconutBridgeImpl'
export { BridgeTokenManager } from './src/main/ets/bridge/BridgeTokenManager'
export { BridgeSecurityValidator } from './src/main/ets/bridge/BridgeSecurityValidator'
export { SecurityAuditLog, AuditEntry } from './src/main/ets/bridge/SecurityAuditLog'
export { BridgePerformance, CallRecord, MethodStats } from './src/main/ets/bridge/BridgePerformance'

// Bridge Models
export { BridgeRequest, ValidationResult } from './src/main/ets/bridge/model/BridgeRequest'
export { BridgeResponse } from './src/main/ets/bridge/model/BridgeResponse'
export { ErrorCode } from './src/main/ets/bridge/model/ErrorCode'
export { SecurityResult } from './src/main/ets/bridge/model/SecurityResult'

// Component Layer
export { CoconutPlugin } from './src/main/ets/component/CoconutPlugin'
export { BaseComponent } from './src/main/ets/component/BaseComponent'
export { ComponentManager, ComponentInfo } from './src/main/ets/component/ComponentManager'
export { ComponentContext } from './src/main/ets/component/ComponentContext'
export { ComponentHost } from './src/main/ets/component/ComponentHost'
export { ComponentException, ComponentNotFoundException, ComponentNotInitializedException } from './src/main/ets/component/ComponentException'

// Event Layer (native → H5 push)
export { EventEmitter, JsExecutor } from './src/main/ets/event/EventEmitter'

// Web Container
export { CoconutWebPage } from './src/main/ets/web/CoconutWebPage'
export { WebViewHelper } from './src/main/ets/web/WebViewHelper'

