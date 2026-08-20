package com.sniper.coconut.network.interceptors

import com.sniper.coconut.network.HttpRequest
import com.sniper.coconut.network.HttpResponse

/**
 * 请求拦截器接口
 * 请求阶段正序执行，响应阶段逆序执行
 */
interface RequestInterceptor {
    /** 请求拦截 */
    suspend fun onRequest(request: HttpRequest): HttpRequest

    /** 响应拦截 */
    suspend fun onResponse(response: HttpResponse): HttpResponse
}
