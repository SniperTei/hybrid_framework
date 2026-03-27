# 🧪 Coconut SDK 测试指南

## 📋 测试页面说明

Demo.vue 页面提供了完整的 Coconut SDK 测试功能，包括 Device、Network、Storage 三大组件的测试。

---

## 🌐 Network 组件测试

### 测试功能

#### 1. GET 请求
测试基本的 GET 请求功能。

**测试 API**: `https://api.github.com/zen`

**调用方式**:
```javascript
Coconut.network.get('https://api.github.com/zen', callback)
```

#### 2. POST 请求
测试 POST 请求发送 JSON 数据。

**测试 API**: `https://jsonplaceholder.typicode.com/posts`

**调用方式**:
```javascript
Coconut.network.post(url, {
  title: 'Coconut SDK Test',
  body: 'Testing POST request',
  userId: 1
}, callback)
```

#### 3. PUT 请求
测试 PUT 请求更新数据。

**测试 API**: `https://jsonplaceholder.typicode.com/posts/1`

**调用方式**:
```javascript
Coconut.network.request({
  url: url,
  method: 'PUT',
  body: JSON.stringify(data)
}, callback)
```

#### 4. DELETE 请求
测试 DELETE 请求删除数据。

**测试 API**: `https://jsonplaceholder.typicode.com/posts/1`

**调用方式**:
```javascript
Coconut.network.request({
  url: url,
  method: 'DELETE'
}, callback)
```

#### 5. 自定义请求头
测试发送自定义 HTTP 请求头。

**测试 API**: `https://httpbin.org/headers`

**调用方式**:
```javascript
Coconut.network.request({
  url: url,
  method: 'GET',
  headers: {
    'X-Custom-Header': 'Coconut-SDK',
    'X-Request-ID': '12345'
  }
}, callback)
```

#### 6. 超时测试
测试请求超时处理。

**测试 API**: `https://httpbin.org/delay/3`（延迟 3 秒响应）

**调用方式**:
```javascript
Coconut.network.request({
  url: url,
  method: 'GET',
  timeout: 2000 // 2 秒超时
}, callback)
```

---

## 💾 Storage 组件测试

### 测试功能

#### 1. 存储数据
测试存储键值对数据。

**调用方式**:
```javascript
Coconut.storage.setItem('demo_key', 'demo_value', callback)
```

**存储的数据格式**:
```javascript
{
  key: string,
  value: string
}
```

#### 2. 读取数据
测试读取已存储的数据。

**调用方式**:
```javascript
Coconut.storage.getItem('demo_key', callback)
```

**返回格式**:
```javascript
{
  code: '000000',
  message: 'success',
  data: 'stored_value'
}
```

#### 3. 删除数据
测试删除指定的键。

**调用方式**:
```javascript
Coconut.storage.removeItem('demo_key', callback)
```

#### 4. 获取所有键
测试获取所有已存储的键列表。

**测试流程**:
1. 存储多个测试键值对
2. 显示所有已存储的键
3. 显示存储的数据

**测试数据**:
```javascript
{
  'test_key_1': 'value_1',
  'test_key_2': 'value_2',
  'test_key_3': 'value_3'
}
```

#### 5. 清空存储
测试清空所有存储数据。

**调用方式**:
```javascript
Coconut.storage.clear(callback)
```

**⚠️ 警告**: 此操作会删除所有存储数据！

#### 6. 批量操作
测试批量存储和验证。

**测试流程**:
1. 批量存储 3 个键值对
2. 逐个读取验证
3. 显示所有操作结果

**测试数据**:
```javascript
[
  { key: 'batch_1', value: 'value_1_TIMESTAMP' },
  { key: 'batch_2', value: 'value_2_TIMESTAMP' },
  { key: 'batch_3', value: 'value_3_TIMESTAMP' }
]
```

---

## 📱 Device 组件测试

### 获取设备信息
测试获取 Android 设备信息。

**调用方式**:
```javascript
Coconut.device.getInfo(callback)
```

**返回数据**:
```javascript
{
  manufacturer: string,  // 制造商
  model: string,         // 型号
  version: string,       // Android 版本
  sdkVersion: string,    // SDK 版本
  platform: string       // 平台
}
```

---

## ⚡ 高级测试

### 异步调用示例
演示使用 async/await 调用原生方法。

```javascript
async function testAsync() {
  try {
    const response = await Coconut.callAsync('device.getInfo')
    console.log('设备信息:', response.result)
  } catch (error) {
    console.error('调用失败:', error)
  }
}
```

### 测试所有功能
一键测试所有组件功能。

**测试流程**:
1. ✅ 获取设备信息
2. ✅ 网络请求测试
3. ✅ 存储写入测试
4. ✅ 存储读取验证
5. ✅ 环境信息检查

---

## 🎯 使用说明

### 在浏览器中测试

1. **启动开发服务器**:
   ```bash
   npm run dev
   ```

2. **打开浏览器**:
   访问 `http://localhost:5174`

3. **环境显示**:
   - 平台: **Web 🌐**
   - 数据: 使用模拟数据

### 在 Android WebView 中测试

1. **启动开发服务器**:
   ```bash
   npm run dev
   ```

2. **获取电脑 IP**:
   ```bash
   ifconfig | grep "inet "
   ```

3. **修改 Android 项目**:
   ```kotlin
   // CoconutWebActivity.kt
   private fun loadTestPage() {
       webView.loadUrl("http://192.168.1.100:5174")
   }
   ```

4. **运行 Android 应用**:
   - 环境显示: **Android 🤖**
   - 数据: 真实的原生调用

---

## 📊 测试结果说明

### 成功响应格式
```javascript
{
  jsonrpc: "2.0",
  id: "req_xxx",
  result: {
    code: "000000",
    message: "success",
    data: { ... }
  }
}
```

### 错误响应格式
```javascript
{
  jsonrpc: "2.0",
  id: "req_xxx",
  error: {
    code: "error_code",
    message: "error message"
  }
}
```

### 超时响应格式
```javascript
{
  error: "Timeout after 30000ms"
}
```

---

## 🐛 调试技巧

### 1. 启用调试模式
```javascript
Coconut.init({ debug: true })
```

### 2. 查看控制台日志
- **浏览器**: F12 打开开发者工具
- **Android**: `adb logcat | grep Coconut`

### 3. 监控网络请求
- **浏览器**: Network 面板
- **Android**: Charles/Fiddler 抓包

### 4. 检查环境信息
```javascript
console.log(Coconut.env)
```

---

## ⚠️ 注意事项

### 1. 网络请求
- ✅ 支持 HTTP/HTTPS
- ✅ 支持自定义请求头
- ✅ 支持超时设置
- ⚠️ 跨域请求需要服务端支持 CORS

### 2. 数据存储
- ✅ 数据持久化存储
- ✅ 支持 JSON 字符串
- ⚠️ Value 需要转换为字符串
- ⚠️ 清空操作不可恢复

### 3. 环境差异
| 功能 | Web 环境 | Android 环境 |
|------|---------|-------------|
| Device 组件 | ❌ 模拟数据 | ✅ 真实数据 |
| Network 组件 | ✅ 真实请求 | ✅ 真实请求 |
| Storage 组件 | ✅ localStorage | ✅ 原生存储 |

---

## 📝 测试检查清单

### Network 组件
- [ ] GET 请求成功
- [ ] POST 请求成功
- [ ] PUT 请求成功
- [ ] DELETE 请求成功
- [ ] 自定义请求头生效
- [ ] 超时机制正常

### Storage 组件
- [ ] 存储数据成功
- [ ] 读取数据正确
- [ ] 删除数据成功
- [ ] 批量操作正常
- [ ] 清空存储成功

### Device 组件
- [ ] 获取设备信息成功
- [ ] 设备信息完整

### 集成测试
- [ ] 异步调用正常
- [ ] 错误处理正确
- [ ] 超时处理正确
- [ ] 环境判断准确

---

## 🎉 完成测试

所有测试通过后，您可以确认：
- ✅ Coconut JS SDK 工作正常
- ✅ Android 原生组件响应正确
- ✅ H5 与原生通信成功
- ✅ 可以开始开发您的混合应用了！

---

**🥥 开始测试 Coconut SDK 的强大功能吧！**
