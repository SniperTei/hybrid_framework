# AndroidWebBox 网络请求插件 API

## 概述

网络请求插件提供了完整的HTTP请求能力，包括GET/POST/PUT/DELETE/PATCH以及文件上传/下载功能。

## 特性

- ✅ 支持所有HTTP方法 (GET/POST/PUT/DELETE/PATCH)
- ✅ 文件上传/下载（带进度回调）
- ✅ 自定义请求头
- ✅ JSON和表单数据支持
- ✅ 请求/响应拦截器
- ✅ 自动重试
- ✅ HTTP缓存
- ✅ Cookie管理
- ✅ 超时控制

## 快速开始

### 基础GET请求

```javascript
AndroidWebBox.http.get({
    url: 'https://api.example.com/users'
}, function(response) {
    if (response.statusCode === 200) {
        console.log(response.data); // 响应数据
    }
});
```

### POST请求

```javascript
AndroidWebBox.http.post({
    url: 'https://api.example.com/login',
    data: {
        username: 'test',
        password: '123456'
    }
}, function(response) {
    console.log(response);
});
```

### 自定义请求头

```javascript
AndroidWebBox.http.get({
    url: 'https://api.example.com/data',
    headers: {
        'Authorization': 'Bearer token123',
        'X-Custom-Header': 'value'
    }
}, callback);
```

## 完整API

### 1. GET 请求

```javascript
AndroidWebBox.http.get({
    url: '/api/users',              // 请求URL（相对或绝对路径）
    headers: {},                      // 可选：自定义请求头
    timeout: 30000                    // 可选：超时时间（毫秒）
}, callback);
```

### 2. POST 请求

```javascript
AndroidWebBox.http.post({
    url: '/api/users',
    data: {                           // 请求体（JSON对象）
        name: 'John',
        email: 'john@example.com'
    },
    contentType: 'application/json',  // 可选：Content-Type
    headers: {},                      // 可选：自定义请求头
    timeout: 30000                    // 可选：超时时间
}, callback);
```

### 3. PUT 请求

```javascript
AndroidWebBox.http.put({
    url: '/api/users/1',
    data: {
        name: 'John Updated'
    }
}, callback);
```

### 4. DELETE 请求

```javascript
AndroidWebBox.http.delete({
    url: '/api/users/1'
}, callback);
```

### 5. PATCH 请求

```javascript
AndroidWebBox.http.patch({
    url: '/api/users/1',
    data: {
        status: 'active'
    }
}, callback);
```

### 6. 文件上传

```javascript
AndroidWebBox.http.upload({
    url: '/api/upload',
    file: 'file:///storage/emulated/0/Pictures/image.jpg',  // 文件路径
    name: 'file',                    // 可选：表单字段名，默认'file'
    mimeType: 'image/jpeg',          // 可选：MIME类型
    progress: true                   // 可选：启用进度回调
}, function(response) {
    if (response.progress !== undefined) {
        console.log('上传进度:', response.progress + '%');
    } else if (response.statusCode === 200) {
        console.log('上传成功');
    }
});
```

### 7. 文件下载

```javascript
AndroidWebBox.http.download({
    url: 'https://example.com/file.pdf',
    savePath: '/storage/emulated/0/Download/file.pdf'
}, function(response) {
    if (response.success) {
        console.log('保存路径:', response.data.savedPath);
        console.log('文件大小:', response.data.contentLength);
    }
});
```

### 8. 设置网络配置

```javascript
AndroidWebBox.http.setConfig({
    baseUrl: 'https://api.example.com',
    connectTimeout: 30000,
    readTimeout: 30000,
    writeTimeout: 30000,
    enableCache: true,
    retryCount: 2
}, function(response) {
    console.log('网络配置已更新');
});
```

## 响应格式

所有请求的回调都返回统一格式的响应：

```javascript
{
    statusCode: 200,           // HTTP状态码
    headers: {                 // 响应头
        "content-type": "application/json",
        "content-length": "1234"
    },
    data: "{...}",            // 响应体（字符串）
    error: {                  // 可选：错误信息
        code: "HTTP_ERROR_404",
        message: "Not Found",
        httpCode: 404
    }
}
```

### 成功响应

```javascript
{
    statusCode: 200,
    headers: {...},
    data: '{"id": 1, "name": "John"}'
}
```

### 错误响应

```javascript
{
    statusCode: 404,
    headers: {...},
    data: "Not Found",
    error: {
        code: "HTTP_ERROR_404",
        message: "Not Found",
        httpCode: 404
    }
}
```

## 数据格式

### JSON数据

```javascript
AndroidWebBox.http.post({
    url: '/api/users',
    data: {
        name: 'John',
        age: 30
    }
}, function(response) {
    const user = JSON.parse(response.data);
    console.log(user.name);
});
```

### 表单数据

```javascript
AndroidWebBox.http.post({
    url: '/api/form',
    data: 'field1=value1&field2=value2',
    contentType: 'application/x-www-form-urlencoded'
}, callback);
```

## 进度回调

文件上传支持进度回调：

```javascript
AndroidWebBox.http.upload({
    url: '/api/upload',
    file: 'file:///path/to/file',
    progress: true
}, function(response) {
    if (response.progress !== undefined) {
        // 进度回调
        console.log('上传进度: ' + response.progress + '%');
    } else if (response.statusCode === 200) {
        // 上传完成
        console.log('上传成功');
    }
});
```

## 配置选项

### Native端配置

在 `MainActivity.kt` 中配置网络插件：

```kotlin
val networkConfig = NetworkConfig.Builder()
    .setBaseUrl("https://api.example.com")       // 基础URL
    .setConnectTimeout(30_000)                    // 连接超时
    .setReadTimeout(30_000)                       // 读取超时
    .setWriteTimeout(30_000)                      // 写入超时
    .setEnableCache(true)                         // 启用缓存
    .setRetryCount(2)                             // 重试次数
    .setDefaultHeaders(mapOf(                     // 默认请求头
        "Content-Type" to "application/json",
        "Accept" to "application/json"
    ))
    .addRequestInterceptor {                      // 请求拦截器
        it.proceed(it.request().newBuilder()
            .header("X-App-Version", "1.0.0")
            .build())
    }
    .addResponseInterceptor {                     // 响应拦截器
        val response = it.proceed(it.request())
        // 统一错误处理
        response
    }
    .build()

networkPlugin.setConfig(networkConfig)
```

### H5端配置

```javascript
AndroidWebBox.http.setConfig({
    baseUrl: 'https://api.example.com',
    connectTimeout: 30000,
    readTimeout: 30000,
    writeTimeout: 30000,
    enableCache: true,
    retryCount: 2
}, callback);
```

## 拦截器示例

### 添加Token

```kotlin
.addRequestInterceptor(Interceptor { chain ->
    val originalRequest = chain.request()
    val token = getAuthToken() // 获取token的方法

    val newRequest = originalRequest.newBuilder()
        .header("Authorization", "Bearer $token")
        .build()

    chain.proceed(newRequest)
})
```

### 统一错误处理

```kotlin
.addResponseInterceptor(Interceptor { chain ->
    val response = chain.proceed(chain.request())

    when (response.code) {
        401 -> {
            // Token过期，跳转到登录页
            runOnUiThread {
                Toast.makeText(context, "登录已过期", Toast.LENGTH_SHORT).show()
            }
        }
        403 -> {
            // 无权限
        }
        500 -> {
            // 服务器错误
        }
    }

    response
})
```

### 日志拦截器

SDK内置了日志拦截器，在Debug模式下自动启用：

```
D/NetworkPlugin: Sending request: https://api.example.com/users
D/NetworkPlugin: Headers: {Authorization=Bearer token}
D/NetworkPlugin: Received response in 234ms: 200
```

## 错误处理

### 常见错误码

| 错误码 | 说明 |
|--------|------|
| HTTP_ERROR_200 | 成功 |
| HTTP_ERROR_400 | 请求参数错误 |
| HTTP_ERROR_401 | 未授权 |
| HTTP_ERROR_403 | 禁止访问 |
| HTTP_ERROR_404 | 资源不存在 |
| HTTP_ERROR_500 | 服务器错误 |
| REQUEST_ERROR | 请求失败 |
| NETWORK_ERROR | 网络错误 |
| UPLOAD_ERROR | 上传失败 |
| DOWNLOAD_ERROR | 下载失败 |

### 错误处理示例

```javascript
AndroidWebBox.http.get({
    url: '/api/users'
}, function(response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
        // 成功
        const data = JSON.parse(response.data);
        console.log('成功:', data);
    } else {
        // 错误
        if (response.statusCode === 401) {
            alert('未授权，请登录');
        } else if (response.statusCode === 404) {
            alert('资源不存在');
        } else {
            alert('错误: ' + (response.error?.message || '未知错误'));
        }
    }
});
```

## 最佳实践

### 1. 使用BaseURL

```kotlin
// Native端设置
networkConfig.setBaseUrl("https://api.example.com")

// H5端使用相对路径
AndroidWebBox.http.get({
    url: '/users'  // 会自动拼接为 https://api.example.com/users
}, callback);
```

### 2. 统一的错误处理

```javascript
function makeRequest(options, callback) {
    AndroidWebBox.http.get(options, function(response) {
        if (response.error) {
            // 统一错误处理
            handleError(response.error);
        } else {
            callback(response);
        }
    });
}

function handleError(error) {
    switch (error.httpCode) {
        case 401:
            // 跳转登录
            break;
        case 403:
            // 提示无权限
            break;
        default:
            // 显示错误消息
            alert(error.message);
    }
}
```

### 3. 请求队列管理

```javascript
class RequestQueue {
    constructor() {
        this.queue = [];
        this.requesting = false;
    }

    add(options, callback) {
        this.queue.push({ options, callback });
        this.process();
    }

    process() {
        if (this.requesting || this.queue.length === 0) return;

        this.requesting = true;
        const { options, callback } = this.queue.shift();

        AndroidWebBox.http.get(options, (response) => {
            callback(response);
            this.requesting = false;
            this.process();
        });
    }
}
```

### 4. 取消请求

使用OkHttpClient的取消功能：

```kotlin
// 在NetworkPlugin中添加
fun cancelRequest(tag: String) {
    okHttpClient?.dispatcher?.queuedCalls()?.forEach {
        if (it.request().tag() == tag) {
            it.cancel()
        }
    }
}
```

## 安全建议

1. **HTTPS优先** - 生产环境始终使用HTTPS
2. **证书校验** - 不要禁用SSL证书校验
3. **敏感数据** - 不要在URL中传递敏感信息
4. **Token管理** - 使用安全的Token存储方式
5. **输入验证** - 在Native和H5端都验证输入

## 测试

使用网络测试页面进行调试：

```bash
# 打开网络测试页面
window.location.href = 'file:///android_asset/network-test.html';
```

或使用在线测试API：

- JSONPlaceholder: https://jsonplaceholder.typicode.com/
- Reqres: https://reqres.in/

## 性能优化

1. **启用缓存** - 减少重复请求
2. **请求合并** - 合并多个小请求
3. **压缩** - 启用GZIP压缩
4. **连接池** - 复用HTTP连接
5. **异步处理** - 使用协程处理网络请求

## 常见问题

### Q: 如何处理跨域问题？
A: 使用Native网络请求会自动绕过CORS限制。

### Q: 如何上传多个文件？
A: 多次调用upload方法，或在Native端实现批量上传。

### Q: 如何实现断点续传？
A: 在download方法中添加Range头支持。

### Q: 如何监听上传进度？
A: 设置 `progress: true` 并监听回调中的 `progress` 字段。

### Q: 如何自定义SSL证书？
A: 在NetworkConfig中配置自定义的OkHttpClient。
