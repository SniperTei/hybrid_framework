// CoconutNetwork - Module Exports
export { HttpClient } from './src/main/ets/HttpClient'
export { HttpConfig } from './src/main/ets/HttpConfig'
export { HttpRequest, HttpMethod, RequestOptions, HttpClientContext } from './src/main/ets/HttpRequest'
export { ApiResponse, HttpResponse, API_SUCCESS_CODE } from './src/main/ets/HttpResponse'
export { Call } from './src/main/ets/Call'
export { HttpError, HttpErrorCode } from './src/main/ets/HttpError'

// Guard (outbound SSRF protection)
export { UrlGuard, UrlGuardResult } from './src/main/ets/guard/UrlGuard'

// Adapter Layer (pluggable transport: system stack / 3rd-party / fake)
export { IHttpAdapter, AdapterRequest, AdapterResponse, FormDataItem } from './src/main/ets/adapter/IHttpAdapter'
export { HarmonyHttpAdapter } from './src/main/ets/adapter/HarmonyHttpAdapter'

// Interceptors
export { RequestInterceptor } from './src/main/ets/interceptors/RequestInterceptor'
export { LogInterceptor } from './src/main/ets/interceptors/LogInterceptor'
export { MockInterceptor, MockRule, MockResult } from './src/main/ets/interceptors/MockInterceptor'

// Utils
export { Logger } from './src/main/ets/utils/Logger'
