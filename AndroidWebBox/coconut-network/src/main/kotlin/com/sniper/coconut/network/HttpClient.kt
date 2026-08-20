package com.sniper.coconut.network

import com.sniper.coconut.network.adapter.HttpURLConnectionAdapter
import com.sniper.coconut.network.adapter.IHttpAdapter
import com.sniper.coconut.network.interceptors.RequestInterceptor

/**
 * HTTP 客户端 — Call 的工厂
 * 持有全局配置、适配器、拦截器
 */
class HttpClient(
    private val config: HttpConfig,
    adapter: IHttpAdapter? = null,
) : HttpClientContext {

    private val adapter: IHttpAdapter = adapter ?: defaultAdapter ?: HttpURLConnectionAdapter()
    private val interceptors = mutableListOf<RequestInterceptor>()

    /** 创建请求（绑定了 this 的 config + adapter + interceptors） */
    fun newRequest(url: String, options: RequestOptions? = null): HttpRequest {
        return HttpRequest(url, options, this)
    }

    /** 添加拦截器 */
    fun addInterceptor(interceptor: RequestInterceptor) {
        interceptors.add(interceptor)
    }

    override fun getConfig(): HttpConfig = config

    override fun getAdapter(): IHttpAdapter = adapter

    override fun getInterceptors(): List<RequestInterceptor> = interceptors

    /**
     * 向后兼容：直接执行请求
     * 内部创建 Call 并 execute
     */
    suspend fun execute(request: HttpRequest): HttpResponse {
        // 如果 request 没有绑定 context，用当前 client 的上下文补绑
        val call = Call(request, config, adapter, interceptors)
        return call.execute()
    }

    companion object {
        /** 全局默认 Adapter，启动时设置一次即可 */
        private var defaultAdapter: IHttpAdapter? = null

        /** 设置全局默认 Adapter（不设则用 HttpURLConnectionAdapter） */
        fun setDefaultAdapter(adapter: IHttpAdapter) {
            defaultAdapter = adapter
        }
    }
}
