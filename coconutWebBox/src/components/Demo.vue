<template>
  <div class="demo-container">
    <div class="header">
      <h1>🥥 Coconut SDK Demo</h1>
      <div class="env-info">
        <span class="label">平台:</span>
        <span class="value">{{ platformText }}</span>
        <span class="divider">|</span>
        <span class="label">SDK版本:</span>
        <span class="value">{{ sdkVersion }}</span>
        <span class="divider">|</span>
        <span class="label">协议版本:</span>
        <span class="value">v{{ hybridVersion }}</span>
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
          <span class="detail-label">isHarmony:</span>
          <span class="detail-value">{{ env.isHarmony }}</span>
        </div>
        <div class="env-detail-item">
          <span class="detail-label">isWeb:</span>
          <span class="detail-value">{{ env.isWeb }}</span>
        </div>
        <div class="env-detail-item">
          <span class="detail-label">appName:</span>
          <span class="detail-value">{{ env.appName || '(空)' }}</span>
        </div>
        <div class="env-detail-item">
          <span class="detail-label">appVersion:</span>
          <span class="detail-value">{{ env.appVersion || '(空)' }}</span>
        </div>
      </div>
    </div>

    <div class="test-sections">
      <div class="test-section">
        <h3>📱 Device 组件</h3>
        <div class="test-buttons">
          <button class="test-btn" @click="testDeviceInfo" :disabled="loading">getInfo</button>
        </div>
      </div>

      <div class="test-section">
        <h3>💾 Storage 组件</h3>
        <div class="test-buttons">
          <button class="test-btn" @click="testSetItem" :disabled="loading">setItem</button>
          <button class="test-btn" @click="testGetItem" :disabled="loading">getItem</button>
          <button class="test-btn" @click="testRemoveItem" :disabled="loading">removeItem</button>
          <button class="test-btn" @click="testClear" :disabled="loading">clear</button>
          <button class="test-btn" @click="testGetAllKeys" :disabled="loading">getAllKeys</button>
          <button class="test-btn" @click="testGetLength" :disabled="loading">getLength</button>
        </div>
      </div>

      <div class="test-section">
        <h3>📡 Event 组件（native → H5 push）</h3>
        <div class="test-buttons">
          <button class="test-btn" @click="eventOn" :disabled="loading">订阅 test.echo</button>
          <button class="test-btn" @click="eventEcho" :disabled="loading">触发 echo</button>
          <button class="test-btn" @click="eventOff" :disabled="loading">取消订阅</button>
        </div>
        <div class="event-log">
          <div class="event-log-title">事件日志</div>
          <div v-if="eventLogs.length === 0" class="event-log-empty">（暂无事件）</div>
          <div v-for="(log, idx) in eventLogs" :key="idx" class="event-log-item">
            <span class="event-log-time">{{ log.time }}</span>
            <pre class="event-log-payload">{{ log.payload }}</pre>
          </div>
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
        <div v-if="result" class="result-cols">
          <div class="result-col">
            <div class="result-col-title">error</div>
            <pre class="result-json">{{ formattedError }}</pre>
          </div>
          <div class="result-col">
            <div class="result-col-title">data</div>
            <pre class="result-json">{{ formattedData }}</pre>
          </div>
        </div>
        <div v-else class="result-placeholder">点击上方按钮开始测试...</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const loading = ref(false)
const errorValue = ref(null)
const dataValue = ref(null)
const status = ref(null)
const sdkVersion = ref('0.0.0')
const hybridVersion = ref('?')
const environment = ref('web')
const env = ref({})
const eventLogs = ref([])

const platformText = computed(() => {
  const envMap = {
    android: 'Android 🤖',
    ios: 'iOS 🍎',
    harmony: 'HarmonyOS 🌈',
    web: 'Web 🌐',
    node: 'Node.js 📦'
  }
  return envMap[environment.value] || environment.value
})

const isWebView = computed(() => env.value.isWebView || false)

const formattedError = computed(() =>
  errorValue.value === null ? 'null' : JSON.stringify(errorValue.value, null, 2)
)
const formattedData = computed(() =>
  dataValue.value === undefined ? 'undefined' : JSON.stringify(dataValue.value, null, 2)
)

onMounted(() => {
  const coconut = window.coconut
  if (!coconut) {
    status.value = { type: 'error', text: 'coconut.js 未加载' }
    return
  }
  try {
    coconut.init({ debug: true })
    sdkVersion.value = String(coconut.version || '0.0.0')
    environment.value = String(coconut.environment || 'unknown')
    hybridVersion.value = String(coconut.env?.hybridVersion || '?')
    // 拷贝 enumerable 字段（lazy getter 在访问时生效）
    env.value = JSON.parse(JSON.stringify(coconut.env || {}))
    // appName / appVersion 是 lazy getter，JSON.stringify 会触发读取
    env.value.appName = coconut.env.appName || ''
    env.value.appVersion = coconut.env.appVersion || ''
    console.log('%c🥥 coconut SDK v' + sdkVersion.value + ' (protocol v' + hybridVersion.value + ')',
      'color: #667eea; font-size: 20px; font-weight: bold;')
  } catch (error) {
    console.error('初始化出错:', error)
  }
})

function showResult(err, data, statusText) {
  errorValue.value = err
  dataValue.value = data
  status.value = {
    type: err ? 'error' : 'success',
    text: statusText || (err ? '失败' : '成功')
  }
}

function withLoading(btnId, fn) {
  loading.value = true
  fn(() => { loading.value = false })
}

// ---- Device ----
function testDeviceInfo() {
  withLoading('device', (done) => {
    window.coconut.device.getInfo((err, data) => {
      done()
      showResult(err, data, err ? '失败' : '成功')
    })
  })
}

// ---- Storage ----
function testSetItem() {
  withLoading('storage-set', (done) => {
    const value = 'test_' + Date.now()
    window.coconut.storage.setItem('demo', value, (err, data) => {
      done()
      showResult(err, { ...data, _written: value }, err ? '失败' : '已存储')
    })
  })
}

function testGetItem() {
  withLoading('storage-get', (done) => {
    window.coconut.storage.getItem('demo', (err, data) => {
      done()
      showResult(err, data, err ? '失败' : '已读取')
    })
  })
}

function testRemoveItem() {
  withLoading('storage-remove', (done) => {
    window.coconut.storage.removeItem('demo', (err, data) => {
      done()
      showResult(err, data, err ? '失败' : '已删除')
    })
  })
}

function testClear() {
  withLoading('storage-clear', (done) => {
    window.coconut.storage.clear((err, data) => {
      done()
      showResult(err, data, err ? '失败' : '已清空')
    })
  })
}

function testGetAllKeys() {
  withLoading('storage-keys', (done) => {
    window.coconut.storage.getAllKeys((err, data) => {
      done()
      showResult(err, data, err ? '失败' : '成功')
    })
  })
}

function testGetLength() {
  withLoading('storage-length', (done) => {
    window.coconut.storage.getLength((err, data) => {
      done()
      showResult(err, data, err ? '失败' : '成功')
    })
  })
}

// ---- Event ----
function logEvent(payload) {
  const time = new Date().toLocaleTimeString()
  eventLogs.value.unshift({ time, payload: JSON.stringify(payload, null, 2) })
  if (eventLogs.value.length > 5) eventLogs.value.pop()
}

function eventOn() {
  if (!window.coconut.handlers['test.echo']) {
    window.coconut.on('test.echo', (data) => {
      logEvent(data)
    })
    showResult(null, { topic: 'test.echo', subscribed: true }, '已订阅')
  } else {
    showResult(null, { topic: 'test.echo', subscribed: true, note: '已订阅过，幂等' }, '已订阅')
  }
}

function eventEcho() {
  const payload = { hello: 'world', ts: Date.now() }
  window.coconut.call('event', 'echo', payload, (err, data) => {
    showResult(err, data, err ? '失败' : '已调度（500ms 后投递）')
  })
}

function eventOff() {
  window.coconut.off('test.echo')
  showResult(null, { topic: 'test.echo', subscribed: false }, '已取消订阅')
}
</script>

<style scoped>
.demo-container { max-width: 800px; margin: 0 auto; padding: 24px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
.header { text-align: center; margin-bottom: 32px; }
.header h1 { color: #667eea; font-size: 32px; margin-bottom: 16px; }
.env-info { display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 13px; color: #718096; background: #f7fafc; padding: 10px; border-radius: 8px; margin-bottom: 12px; flex-wrap: wrap; }
.label { font-weight: 600; }
.value { color: #667eea; }
.divider { color: #cbd5e0; }
.env-details { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 8px; padding: 12px; background: #edf2f7; border-radius: 8px; margin-bottom: 24px; }
.env-detail-item { display: flex; flex-direction: column; align-items: center; padding: 8px; background: white; border-radius: 6px; font-size: 12px; }
.detail-label { font-weight: 600; color: #4a5568; margin-bottom: 4px; }
.detail-value { color: #667eea; font-weight: 700; word-break: break-all; }
.test-sections { display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 20px; margin-bottom: 24px; }
.test-section { background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; }
.test-section h3 { margin: 0 0 16px 0; font-size: 16px; font-weight: 600; color: #2d3748; }
.test-buttons { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.test-btn { padding: 10px 16px; background: white; border: 1px solid #cbd5e0; border-radius: 6px; font-size: 13px; font-weight: 500; color: #4a5568; cursor: pointer; transition: all 0.2s; }
.test-btn:hover:not(:disabled) { background: #667eea; color: white; border-color: #667eea; }
.test-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.event-log { margin-top: 16px; border-top: 1px dashed #cbd5e0; padding-top: 12px; }
.event-log-title { font-size: 12px; font-weight: 600; color: #4a5568; margin-bottom: 8px; }
.event-log-empty { font-size: 12px; color: #a0aec0; }
.event-log-item { background: white; border: 1px solid #e2e8f0; border-radius: 6px; padding: 8px; margin-bottom: 6px; }
.event-log-time { font-size: 11px; color: #718096; font-family: 'Monaco', monospace; }
.event-log-payload { margin: 4px 0 0 0; font-family: 'Monaco', 'Menlo', monospace; font-size: 12px; color: #2d3748; white-space: pre-wrap; }
.result-container { background: white; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; margin-bottom: 24px; }
.result-header { display: flex; justify-content: space-between; align-items: center; padding: 16px 20px; background: #f7fafc; border-bottom: 1px solid #e2e8f0; }
.result-title { font-weight: 600; color: #2d3748; font-size: 16px; }
.status-badge { padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
.status-badge.success { background: #c6f6d5; color: #22543d; }
.status-badge.error { background: #fed7d7; color: #742a2a; }
.result-content { padding: 20px; max-height: 500px; overflow-y: auto; }
.result-cols { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.result-col { background: #f7fafc; border-radius: 8px; padding: 12px; }
.result-col-title { font-size: 12px; font-weight: 600; color: #4a5568; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.05em; }
.result-json { margin: 0; font-family: 'Monaco', 'Menlo', monospace; font-size: 13px; line-height: 1.6; color: #2d3748; white-space: pre-wrap; word-wrap: break-word; }
.result-placeholder { color: #a0aec0; text-align: center; padding: 40px 20px; }
</style>
