<template>
  <div>
    <h1 class="page-title">首页</h1>
    <p class="page-hint">容器仪表盘：bridge 环境 / 设备 / 网络实时状态。</p>
    <div :class="['platform-chip', { web: environment === 'web' }]">
      <span class="dot"></span>
      <span>{{ platformText }}</span>
    </div>

    <div class="card">
      <h3>应用（coconut.env）</h3>
      <pre class="muted">{{ aboutText }}</pre>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-a" @click="loadAppInfo" :disabled="loading">应用信息（device.getAppInfo）</button>
      </div>
    </div>

    <div class="card">
      <h3>设备（device.getInfo）</h3>
      <pre :class="deviceInfo ? '' : 'muted'">{{ deviceInfo || '（点下方按钮读取）' }}</pre>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-b" @click="loadDeviceInfo" :disabled="loading">读取设备信息</button>
      </div>
    </div>

    <div class="card">
      <h3>网络（实时）</h3>
      <div class="net-live">
        <span :class="['net-dot', netOnline ? 'on' : 'off']"></span>
        <span class="net-type">{{ netType || '…' }}</span>
        <span class="net-extra">{{ netExtra }}</span>
      </div>
      <p class="net-hint">network.getNetworkType 轮询初始化 + coconut.on('network.change') 事件实时刷新</p>
    </div>

    <div class="card">
      <h3>能力矩阵（coconut.supports）</h3>
      <div class="cap-grid">
        <div v-for="c in capabilityChecks" :key="c.label" class="cap-row">
          <span>{{ c.label }}</span>
          <span :class="c.value ? 'cap-ok' : 'cap-no'">{{ c.value ? '✓' : '✗' }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { pcall } from '../lib/pcall'
import { useConfigTick } from '../lib/configTick'
import { onEvent, resubscribeNative } from '../lib/events'

const configTick = useConfigTick()
const loading = ref(false)
const environment = ref('web')
const deviceInfo = ref('')
const appInfo = ref(null)
const netType = ref('')
const netOnline = ref(null)
const netUpdated = ref(0)

const platformText = computed(() => {
  const envMap = { android: 'Android', ios: 'iOS', harmony: 'HarmonyOS NEXT', web: 'Web（未检测到 Bridge）' }
  return envMap[environment.value] || environment.value
})

const aboutText = computed(() => {
  void configTick.value
  const e = window.coconut?.env || {}
  const lines = [
    `应用：${e.appName || '(未知)'} ${e.appVersion || ''}`,
    `SDK：v${e.sdkVersion || '?'} · 协议 v${e.hybridVersion || '?'}`,
  ]
  if (appInfo.value) {
    lines.push(`包名：${appInfo.value.packageName || '?'}`)
    lines.push(`构建号：${appInfo.value.buildNumber || '?'}`)
  }
  return lines.join('\n')
})

const netExtra = computed(() =>
  netUpdated.value ? `在线：${netOnline.value ? '是' : '否'} · 更新于 ${new Date(netUpdated.value).toLocaleTimeString()}` : '')

const capabilityChecks = computed(() => {
  void configTick.value
  const c = window.coconut
  if (!c || !c.supports) return []
  return [
    { label: 'device.getInfo',          value: c.supports('device', 'getInfo') },
    { label: 'storage.setItem',         value: c.supports('storage', 'setItem') },
    { label: 'event.on',                value: c.supports('event', 'on') },
    { label: 'dialog.confirm',          value: c.supports('dialog', 'confirm') },
    { label: 'network.request',         value: c.supports('network', 'request') },
    { label: 'network.getNetworkType',  value: c.supports('network', 'getNetworkType') },
    { label: 'navigator.forward',       value: c.supports('navigator', 'forward') },
    { label: 'update.check',            value: c.supports('update', 'check') },
  ]
})

async function loadAppInfo() {
  loading.value = true
  const r = await pcall('device', 'getAppInfo', {})
  loading.value = false
  if (!r.err && r.data) appInfo.value = r.data
}

async function loadDeviceInfo() {
  loading.value = true
  const r = await pcall('device', 'getInfo', {})
  loading.value = false
  deviceInfo.value = r.err
    ? `读取失败：${r.err.code} ${r.err.message}`
    : JSON.stringify(r.data, null, 2)
}

async function refreshNetwork() {
  const r = await pcall('network', 'getNetworkType', {})
  if (!r.err && r.data) {
    netType.value = r.data.type
    netOnline.value = r.data.online
    netUpdated.value = Date.now()
  }
}

onMounted(() => {
  const coconut = window.coconut
  if (coconut?.environment) environment.value = String(coconut.environment)
  refreshNetwork()
  loadDeviceInfo()
  // 实时刷新：network.change 原生推送（events.js fan-out，与其他页面共存）
  onEvent('network.change', () => refreshNetwork())

  // Harmony 注入竞态自愈：ArkWeb 的 config（含 bridge token）晚于 mount 到位，
  // 首轮调用 300004。config-loaded（coconut.js v3.5.1 轮询补发）到达后重试。
  // Android/iOS 注入早于 mount，此 watch 不触发。
  watch(configTick, (n) => {
    if (n > 0) {
      refreshNetwork()
      loadDeviceInfo()
      resubscribeNative()
    }
  })
})
</script>

<style scoped>
.net-live {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 0;
}
.net-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #dcdfe6;
}
.net-dot.on  { background: #00b42c; }
.net-dot.off { background: #f53f3f; }
.net-type { font-size: 17px; font-weight: 600; text-transform: capitalize; }
.net-extra { font-size: 12px; color: var(--c-muted); margin-left: auto; }
.net-hint { font-size: 11px; color: var(--c-muted); margin-top: 6px; line-height: 1.5; }

.cap-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 4px 16px; }
.cap-row { display: flex; justify-content: space-between; font-size: 12px; padding: 4px 0; }
.cap-ok { color: #00b42c; font-weight: 700; }
.cap-no { color: #f53f3f; font-weight: 700; }
@media (max-width: 400px) { .cap-grid { grid-template-columns: 1fr; } }
</style>
