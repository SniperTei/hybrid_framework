package com.sniper.androidwebbox.components

import android.content.Context
import android.content.SharedPreferences
import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Login Component - 登录组件
 *
 * 业务组件示例：处理用户登录、登出、获取用户信息等
 * 
 * H5 调用示例：
 * ```javascript
 * // 登录
 * Coconut.call('login.login', {
 *   username: 'admin',
 *   password: '123456'
 * }, callback);
 *
 * // 登出
 * Coconut.call('login.logout', {}, callback);
 *
 * // 检查登录状态
 * Coconut.call('login.isLoggedIn', {}, callback);
 *
 * // 获取用户信息
 * Coconut.call('login.getUserInfo', {}, callback);
 * ```
 */
@ComponentMetadata(
    name = "login",
    version = "1.0.0",
    description = "User login and authentication component",
    dependencies = []
)
class LoginComponent : BaseComponent() {

    override val name = "login"
    override val version = "1.0.0"
    override val description = "User login and authentication component"

    // SharedPreferences 用于存储登录状态
    private lateinit var prefs: SharedPreferences

    /**
     * 组件初始化时获取 SharedPreferences
     */
    override suspend fun onInit(context: com.sniper.coconut.component.ComponentContext) {
        super.onInit(context)
        prefs = context.applicationContext.getSharedPreferences("login_prefs", Context.MODE_PRIVATE)
        Logger.d(name, "LoginComponent initialized with SharedPreferences")
    }

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "login" -> login(params)
            "logout" -> logout()
            "isLoggedIn" -> isLoggedIn()
            "getUserInfo" -> getUserInfo()
            "register" -> register(params)
            else -> functionNotSupportedError(function)
        }
    }

    /**
     * 用户登录
     * 
     * @param params 包含 username 和 password
     * @return 登录结果
     */
    private suspend fun login(params: JsonObject?): JsonElement = withContext(Dispatchers.IO) {
        val username = getParam(params, "username")
        val password = getParam(params, "password")

        Logger.d(name, "Login attempt for user: $username")

        // 模拟登录验证
        // 实际项目中应该调用后端 API
        if (username.isNotEmpty() && password.isNotEmpty()) {
            // 登录成功，保存用户信息
            prefs.edit().apply {
                putBoolean("isLoggedIn", true)
                putString("username", username)
                putLong("loginTime", System.currentTimeMillis())
                apply()
            }

            buildJsonObject {
                put("success", JsonPrimitive(true))
                put("message", JsonPrimitive("登录成功"))
                put("username", JsonPrimitive(username))
                put("loginTime", JsonPrimitive(System.currentTimeMillis()))
            }.let { success(it) }
        } else {
            Logger.w(name, "Login failed: empty username or password")
            paramValidationError("用户名或密码不能为空")
        }
    }

    /**
     * 用户登出
     */
    private suspend fun logout(): JsonElement = withContext(Dispatchers.IO) {
        Logger.d(name, "User logout")

        prefs.edit().clear().apply()

        buildJsonObject {
            put("success", JsonPrimitive(true))
            put("message", JsonPrimitive("登出成功"))
        }.let { success(it) }
    }

    /**
     * 检查登录状态
     */
    private suspend fun isLoggedIn(): JsonElement = withContext(Dispatchers.IO) {
        val loggedIn = prefs.getBoolean("isLoggedIn", false)
        val username = prefs.getString("username", null)

        buildJsonObject {
            put("loggedIn", JsonPrimitive(loggedIn))
            put("username", JsonPrimitive(username ?: ""))
        }.let { success(it) }
    }

    /**
     * 获取用户信息
     */
    private suspend fun getUserInfo(): JsonElement = withContext(Dispatchers.IO) {
        val username = prefs.getString("username", null)
        val loginTime = prefs.getLong("loginTime", 0)

        buildJsonObject {
            put("username", JsonPrimitive(username ?: ""))
            put("loginTime", JsonPrimitive(loginTime))
            put("isLoggedIn", JsonPrimitive(prefs.getBoolean("isLoggedIn", false)))
        }.let { success(it) }
    }

    /**
     * 用户注册
     */
    private suspend fun register(params: JsonObject?): JsonElement = withContext(Dispatchers.IO) {
        val username = getParam(params, "username")
        val password = getParam(params, "password")
        val email = getParam(params, "email")

        Logger.d(name, "Register attempt for user: $username")

        // 模拟注册
        // 实际项目中应该调用后端 API
        if (username.isNotEmpty() && password.isNotEmpty()) {
            buildJsonObject {
                put("success", JsonPrimitive(true))
                put("message", JsonPrimitive("注册成功"))
                put("username", JsonPrimitive(username))
                put("email", JsonPrimitive(email))
            }.let { success(it) }
        } else {
            paramValidationError("用户名或密码不能为空")
        }
    }
}
