/**
 * 传输层接口 — 不依赖任何网络 SDK
 * 换底层（系统栈 / 第三方如 RCP / 测试 Fake）只需新增一个 Adapter 实现
 *
 * Adapter 契约：AdapterResponse.body 必须是已解析的 Object
 * （JSON 响应解析成对象；HarmonyHttpAdapter 用 expectDataType: OBJECT 让系统栈代劳，
 *  其他实现需自行 JSON.parse）
 */

/** 文件上传表单项（替代 http.MultiFormData，避免系统类型泄漏到上层） */
export interface FormDataItem {
  name: string
  contentType: string
  remoteFileName?: string
  data: string | ArrayBuffer
}

/** Adapter 层的请求对象 */
export interface AdapterRequest {
  method: string
  url: string
  headers: Record<string, string>
  body: Object | null
  contentType: string
  connectTimeout: number
  readTimeout: number
  multiFormDataList: FormDataItem[]
}

/** Adapter 层的响应对象 */
export interface AdapterResponse {
  httpStatus: number
  headers: Record<string, string>
  body: Object | null
}

/** 传输层接口 */
export interface IHttpAdapter {
  sendRequest(request: AdapterRequest): Promise<AdapterResponse>
}
