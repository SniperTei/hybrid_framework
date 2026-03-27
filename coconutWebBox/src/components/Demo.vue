<template>
  <div class="demo-container">
    <div class="header">
      <h1>🥥 Coconut SDK Demo</h1>
      <div class="env-info">
        <span class="label">环境:</span>
        <span class="value">{{ environmentText }}</span>
        <span class="divider">|</span>
        <span class="label">版本:</span>
        <span class="value">{{ version }}</span>
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

    <div class="info-card">
      <div class="info-icon">💡</div>
      <div class="info-content">
        <div class="info-title">提示</div>
        <div class="info-text">
          在浏览器中打开时，SDK 会使用模拟数据。在 Android WebView 中才能调用真实的原生功能。
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

// 状态
const loading = ref(false)
const loadingBtn = ref(null)
const result = ref(null)
const status = ref(null)
const version = ref('1.0.0')
const environment = ref('web')

// 计算属性
const environmentText = computed(() => {
  const envMap = {
    android: 'Android 🤖',
    ios: 'iOS 🍎',
    web: 'Web 🌐',
    node: 'Node.js 📦'
  }
  return envMap[environment.value] || environment.value
})

const formattedResult = computed(() => {
  if (!result.value) return ''
  return JSON.stringify(result.value, null, 2)
})

// 按钮配置
const buttons = [
  { id: 'device', text: '📱 获取设备信息', type: 'primary', action: getDeviceInfo },
  { id: 'network', text: '🌐 网络请求测试', type: 'success', action: testNetwork },
  { id: 'storage-set', text: '💾 存储数据', type: 'info', action: testSetStorage },
  { id: 'storage-get', text: '📂 读取数据', type: 'info', action: testGetStorage },
  { id: 'async', text: '⚡ 异步调用示例', type: 'warning', action: testAsync },
  { id: 'all', text: '🚀 测试所有功能', type: 'danger', action: testAll }
]

// 初始化
onMounted(() => {
  // 初始化 Coconut SDK
  if (window.Coconut) {
    window.Coconut.init({ debug: true })
    version.value = window.Coconut.version
    environment.value = window.Coconut.environment

    console.log('%c🥥 Coconut JS SDK v' + version.value, 'color: #667eea; font-size: 20px; font-weight: bold;')
    console.log('%c环境: ' + environment.value, 'color: #718096; font-size: 14px;')
  } else {
    console.error('Coconut SDK 未加载')
  }
})

// 显示结果
function showResult(data, isSuccess, statusText) {
  result.value = data
  status.value = {
    type: isSuccess ? 'success' : 'error',
    text: statusText || (isSuccess ? '成功' : '失败')
  }
}

// 设置加载状态
function setLoading(btnId, isLoading) {
  loading.value = isLoading
  loadingBtn.value = isLoading ? btnId : null
}

// 获取设备信息
function getDeviceInfo() {
  setLoading('device', true)

  window.Coconut.device.getInfo((response, isError) => {
    setLoading('device', false)
    showResult(response, !isError, isError ? '失败' : '成功')
  })
}

// 测试网络请求
function testNetwork() {
  setLoading('network', true)

  window.Coconut.network.request({
    url: 'https://api.github.com/zen',
    method: 'GET'
  }, (response, isError) => {
    setLoading('network', false)
    showResult(response, !isError, isError ? '失败' : '成功')
  })
}

// 测试存储
function testSetStorage() {
  setLoading('storage-set', true)

  const testValue = 'test_value_' + Date.now()
  window.Coconut.storage.setItem('demo_key', testValue, (response, isError) => {
    setLoading('storage-set', false)
    showResult({
      ...response,
      storedValue: testValue
    }, !isError, isError ? '失败' : '已存储')
  })
}

// 读取存储
function testGetStorage() {
  setLoading('storage-get', true)

  window.Coconut.storage.getItem('demo_key', (response, isError) => {
    setLoading('storage-get', false)
    showResult(response, !isError, isError ? '失败' : '已读取')
  })
}

// 异步调用示例
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

// 测试所有功能
async function testAll() {
  setLoading('all', true)

  try {
    // 1. 获取设备信息
    const deviceResponse = await window.Coconut.callAsync('device.getInfo')

    // 2. 存储测试
    await window.Coconut.callAsync('storage.setItem', {
      key: 'test_all',
      value: 'value_' + Date.now()
    })

    // 3. 读取存储
    const storageResponse = await window.Coconut.callAsync('storage.getItem', {
      key: 'test_all'
    })

    setLoading('all', false)

    showResult({
      device: deviceResponse.result?.data,
      storage: storageResponse.result?.data,
      message: '所有测试完成'
    }, true, '全部完成')
  } catch (error) {
    setLoading('all', false)
    showResult(error, false, '失败')
  }
}
</script>

<style scoped>
.demo-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.header {
  text-align: center;
  margin-bottom: 32px;
}

.header h1 {
  color: #667eea;
  font-size: 32px;
  margin-bottom: 16px;
}

.env-info {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  font-size: 14px;
  color: #718096;
  background: #f7fafc;
  padding: 12px;
  border-radius: 8px;
}

.label {
  font-weight: 600;
}

.value {
  color: #667eea;
}

.divider {
  color: #cbd5e0;
}

.button-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.action-btn {
  padding: 16px 24px;
  border: none;
  border-radius: 12px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.action-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.action-btn:active:not(:disabled) {
  transform: translateY(0);
}

.action-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.action-btn.primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.action-btn.success {
  background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
  color: white;
}

.action-btn.info {
  background: linear-gradient(135deg, #4299e1 0%, #3182ce 100%);
  color: white;
}

.action-btn.warning {
  background: linear-gradient(135deg, #ed8936 0%, #dd6b20 100%);
  color: white;
}

.action-btn.danger {
  background: linear-gradient(135deg, #f56565 0%, #e53e3e 100%);
  color: white;
}

.spinner {
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.result-container {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
  margin-bottom: 24px;
}

.result-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  background: #f7fafc;
  border-bottom: 1px solid #e2e8f0;
}

.result-title {
  font-weight: 600;
  color: #2d3748;
  font-size: 16px;
}

.status-badge {
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.status-badge.success {
  background: #c6f6d5;
  color: #22543d;
}

.status-badge.error {
  background: #fed7d7;
  color: #742a2a;
}

.result-content {
  padding: 20px;
  max-height: 500px;
  overflow-y: auto;
}

.result-json {
  margin: 0;
  font-family: 'Monaco', 'Menlo', monospace;
  font-size: 13px;
  line-height: 1.6;
  color: #2d3748;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.result-placeholder {
  color: #a0aec0;
  text-align: center;
  padding: 40px 20px;
}

.info-card {
  display: flex;
  gap: 16px;
  background: #fefce8;
  border: 1px solid #fde68a;
  border-radius: 12px;
  padding: 20px;
}

.info-icon {
  font-size: 32px;
}

.info-content {
  flex: 1;
}

.info-title {
  font-weight: 600;
  color: #92400e;
  margin-bottom: 8px;
}

.info-text {
  color: #b45309;
  font-size: 14px;
  line-height: 1.6;
}

@media (max-width: 640px) {
  .demo-container {
    padding: 16px;
  }

  .button-grid {
    grid-template-columns: 1fr;
  }

  .header h1 {
    font-size: 24px;
  }
}
</style>
