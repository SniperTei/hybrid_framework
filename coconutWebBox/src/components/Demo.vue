<template>
  <div class="demo-container">
    <div class="header">
      <h1>🥥 Coconut SDK Demo</h1>
      <div class="env-info">
        <span class="label">平台:</span>
        <span class="value">{{ platformText }}</span>
        <span class="divider">|</span>
        <span class="label">SDK版本:</span>
        <span class="value">{{ version }}</span>
        <span class="divider">|</span>
        <span class="label">WebView:</span>
        <span class="value">{{ isWebView ? '是' : '否' }}</span>
      </div>

      <div class="env-details">
        <div class="env-detail-item">
          <span class="detail-label">isAndroid:</span>
          <span class="detail-value">{{ env.isAndroid }}</span>
        </div>
        <div class="env-detail-item">
          <span class="detail-label">isiOS:</span>
          <span class="detail-value">{{ env.isiOS }}</span>
        </div>
        <div class="env-detail-item">
          <span class="detail-label">isWeb:</span>
          <span class="detail-value">{{ env.isWeb }}</span>
        </div>
        <div class="env-detail-item">
          <span class="detail-label">isMobile:</span>
          <span class="detail-value">{{ env.isMobile }}</span>
        </div>
        <div class="env-detail-item">
          <span class="detail-label">isTouch:</span>
          <span class="detail-value">{{ env.isTouchDevice }}</span>
        </div>
      </div>
    </div>

    <div class="button-grid">
      <button
        v-for="btn in buttons"
        :key="btn.id"
        :class="['action-btn', btn.type || 'primary']"
        @click="btn.action"
        :disabled="loading"
      >
        <span v-if="loading && btn.id === loadingBtn" class="spinner"></span>
        {{ btn.text }}
      </button>
    </div>

    <div class="test-sections">
      <div class="test-section">
        <h3>🌐 Network 组件测试</h3>
        <div class="test-buttons">
          <button class="test-btn" @click="testGetRequest" :disabled="loading">GET 请求</button>
          <button class="test-btn" @click="testPostRequest" :disabled="loading">POST 请求</button>
          <button class="test-btn" @click="testPutRequest" :disabled="loading">PUT 请求</button>
          <button class="test-btn" @click="testDeleteRequest" :disabled="loading">DELETE 请求</button>
        </div>
      </div>

      <div class="test-section">
        <h3>💾 Storage 组件测试</h3>
        <div class="test-buttons">
          <button class="test-btn" @click="testSetStorage" :disabled="loading">存储数据</button>
          <button class="test-btn" @click="testGetStorage" :disabled="loading">读取数据</button>
          <button class="test-btn" @click="testRemoveStorage" :disabled="loading">删除数据</button>
          <button class="test-btn" @click="testClearStorage" :disabled="loading">清空存储</button>
        </div>
      </div>
    </div>

    <div class="result-container">
      <div class="result-header">
        <span class="result-title">执行结果</span>
        <span v-if="status" :class="['status-badge', status.type]">
          {{ status.text }}
        </span>
      </div>
      <div class="result-content">
        <pre v-if="result" class="result-json">{{ formattedResult }}</pre>
        <div v-else class="result-placeholder">点击上方按钮开始测试...</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const loading = ref(false)
const loadingBtn = ref(null)
const result = ref(null)
const status = ref(null)
const version = ref('1.0.0')
const environment = ref('web')
const env = ref({})

const platformText = computed(() => {
  const envMap = {
    android: 'Android 🤖',
    ios: 'iOS 🍎',
    web: 'Web 🌐',
    node: 'Node.js 📦'
  }
  return envMap[environment.value] || environment.value
})

const isWebView = computed(() => env.value.isWebView || false)

const formattedResult = computed(() => {
  if (!result.value) return ''
  return JSON.stringify(result.value, null, 2)
})

const buttons = [
  { id: 'device', text: '📱 获取设备信息', type: 'primary', action: getDeviceInfo },
  { id: 'async', text: '⚡ 异步调用示例', type: 'warning', action: testAsync },
  { id: 'all', text: '🚀 测试所有功能', type: 'danger', action: testAll }
]

onMounted(() => {
  if (window.Coconut) {
    try {
      window.Coconut.init({ debug: true })
      version.value = String(window.Coconut.version || '1.0.0')
      environment.value = String(window.Coconut.environment || 'unknown')
      env.value = JSON.parse(JSON.stringify(window.Coconut.env || {}))
      console.log('%c🥥 Coconut JS SDK v' + version.value, 'color: #667eea; font-size: 20px; font-weight: bold;')
    } catch (error) {
      console.error('初始化出错:', error)
    }
  }
})

function showResult(data, isSuccess, statusText) {
  result.value = data
  status.value = {
    type: isSuccess ? 'success' : 'error',
    text: statusText || (isSuccess ? '成功' : '失败')
  }
}

function setLoading(btnId, isLoading) {
  loading.value = isLoading
  loadingBtn.value = isLoading ? btnId : null
}

function getDeviceInfo() {
  setLoading('device', true)
  window.Coconut.call('device.getInfo', {}, (response, isError) => {
    setLoading('device', false)
    showResult(response, !isError, isError ? '失败' : '成功')
  })
}

function testGetRequest() {
  setLoading('network-get', true)
  window.Coconut.call('network.request', { url: 'https://api.github.com/zen', method: 'GET' }, (response, isError) => {
    setLoading('network-get', false)
    showResult({ ...response, _test: 'GET 请求' }, !isError, '完成')
  })
}

function testPostRequest() {
  setLoading('network-post', true)
  window.Coconut.call('network.request', {
    url: 'https://jsonplaceholder.typicode.com/posts',
    method: 'POST',
    body: JSON.stringify({ title: 'Test', body: 'Test' })
  }, (response, isError) => {
    setLoading('network-post', false)
    showResult({ ...response, _test: 'POST 请求' }, !isError, '完成')
  })
}

function testSetStorage() {
  setLoading('storage-set', true)
  window.Coconut.call('storage.setItem', { key: 'demo', value: 'test_' + Date.now() }, (response, isError) => {
    setLoading('storage-set', false)
    showResult(response, !isError, isError ? '失败' : '已存储')
  })
}

function testGetStorage() {
  setLoading('storage-get', true)
  window.Coconut.call('storage.getItem', { key: 'demo' }, (response, isError) => {
    setLoading('storage-get', false)
    showResult(response, !isError, isError ? '失败' : '已读取')
  })
}

function testRemoveStorage() {
  setLoading('storage-remove', true)
  window.Coconut.call('storage.removeItem', { key: 'demo' }, (response, isError) => {
    setLoading('storage-remove', false)
    showResult({ ...response, _test: '删除数据' }, !isError, '已删除')
  })
}

function testClearStorage() {
  setLoading('storage-clear', true)
  window.Coconut.call('storage.clear', {}, (response, isError) => {
    setLoading('storage-clear', false)
    showResult({ ...response, _test: '清空存储' }, !isError, '已清空')
  })
}

async function testAsync() {
  setLoading('async', true)
  try {
    const response = await window.Coconut.callAsync('device.getInfo')
    setLoading('async', false)
    showResult(response, true, '成功')
  } catch (error) {
    setLoading('async', false)
    showResult(error, false, '失败')
  }
}

async function testAll() {
  setLoading('all', true)
  try {
    const results = {}
    const deviceResponse = await window.Coconut.callAsync('device.getInfo')
    results.device = deviceResponse.result?.data
    results.environment = {
      platform: window.Coconut.env.platform,
      isNative: window.Coconut.env.isNative
    }
    setLoading('all', false)
    showResult({ _test: '完整测试', ...results }, true, '完成')
  } catch (error) {
    setLoading('all', false)
    showResult(error, false, '失败')
  }
}
</script>

<style scoped>
.demo-container { max-width: 800px; margin: 0 auto; padding: 24px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
.header { text-align: center; margin-bottom: 32px; }
.header h1 { color: #667eea; font-size: 32px; margin-bottom: 16px; }
.env-info { display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 13px; color: #718096; background: #f7fafc; padding: 10px; border-radius: 8px; margin-bottom: 12px; }
.label { font-weight: 600; }
.value { color: #667eea; }
.divider { color: #cbd5e0; }
.env-details { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 8px; padding: 12px; background: #edf2f7; border-radius: 8px; margin-bottom: 24px; }
.env-detail-item { display: flex; flex-direction: column; align-items: center; padding: 8px; background: white; border-radius: 6px; font-size: 12px; }
.detail-label { font-weight: 600; color: #4a5568; margin-bottom: 4px; }
.detail-value { color: #667eea; font-weight: 700; }
.button-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px; }
.action-btn { padding: 16px 24px; border: none; border-radius: 12px; font-size: 15px; font-weight: 600; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 8px; box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1); }
.action-btn:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15); }
.action-btn:disabled { opacity: 0.6; cursor: not-allowed; }
.action-btn.primary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
.action-btn.warning { background: linear-gradient(135deg, #ed8936 0%, #dd6b20 100%); color: white; }
.action-btn.danger { background: linear-gradient(135deg, #f56565 0%, #e53e3e 100%); color: white; }
.spinner { width: 14px; height: 14px; border: 2px solid rgba(255, 255, 255, 0.3); border-top-color: white; border-radius: 50%; animation: spin 0.6s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.test-sections { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 20px; margin-bottom: 24px; }
.test-section { background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; }
.test-section h3 { margin: 0 0 16px 0; font-size: 16px; font-weight: 600; color: #2d3748; }
.test-buttons { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.test-btn { padding: 10px 16px; background: white; border: 1px solid #cbd5e0; border-radius: 6px; font-size: 13px; font-weight: 500; color: #4a5568; cursor: pointer; transition: all 0.2s; }
.test-btn:hover:not(:disabled) { background: #667eea; color: white; border-color: #667eea; }
.test-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.result-container { background: white; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; margin-bottom: 24px; }
.result-header { display: flex; justify-content: space-between; align-items: center; padding: 16px 20px; background: #f7fafc; border-bottom: 1px solid #e2e8f0; }
.result-title { font-weight: 600; color: #2d3748; font-size: 16px; }
.status-badge { padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
.status-badge.success { background: #c6f6d5; color: #22543d; }
.status-badge.error { background: #fed7d7; color: #742a2a; }
.result-content { padding: 20px; max-height: 500px; overflow-y: auto; }
.result-json { margin: 0; font-family: 'Monaco', 'Menlo', monospace; font-size: 13px; line-height: 1.6; color: #2d3748; white-space: pre-wrap; word-wrap: break-word; }
.result-placeholder { color: #a0aec0; text-align: center; padding: 40px 20px; }
</style>
