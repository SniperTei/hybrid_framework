package com.sniper.coconut.components.network

import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.DataOutputStream
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * HttpClient implementation using HttpURLConnection (always available).
 */
class UrlConnectionHttpClient : HttpClient {

    override suspend fun execute(request: HttpRequest): HttpResponse = withContext(Dispatchers.IO) {
        try {
            val connection = URL(request.url).openConnection() as HttpURLConnection
            connection.requestMethod = request.method
            connection.connectTimeout = request.timeout
            connection.readTimeout = request.timeout
            connection.instanceFollowRedirects = true

            // Apply headers
            request.headers.forEach { (k, v) -> connection.setRequestProperty(k, v) }

            // Write body for non-GET
            if (request.method != "GET" && !request.body.isNullOrEmpty()) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", request.contentType)
                DataOutputStream(connection.outputStream).use { dos ->
                    dos.writeBytes(request.body)
                    dos.flush()
                }
            }

            val responseCode = connection.responseCode
            val responseBody = if (responseCode in 200..299) {
                BufferedReader(InputStreamReader(connection.inputStream)).readText()
            } else {
                try {
                    BufferedReader(InputStreamReader(connection.errorStream)).readText()
                } catch (e: Exception) {
                    ""
                }
            }

            val responseHeaders = connection.headerFields
                .filter { it.key != null }
                .mapValues { (_, values) -> values.joinToString(", ") }

            Logger.d(TAG, "Response: $responseCode (${responseBody.length} bytes)")

            HttpResponse(responseCode, responseBody, responseHeaders)
        } catch (e: Exception) {
            Logger.e(TAG, "Request failed: ${request.url}", e)
            HttpResponse(-1, e.message ?: "Request failed", emptyMap())
        }
    }

    companion object {
        private const val TAG = "UrlConnectionHttpClient"
    }
}
