<template>
  <div>
    <h1 class="page-title">我的</h1>
    <p class="page-hint">账户与应用信息。</p>

    <div class="profile">
      <div class="avatar">🥥</div>
      <div class="profile-main">
        <div class="profile-name">{{ profileName }}</div>
        <div class="profile-sub">{{ platformText }} · coconut 协议 v{{ hybridVersion }}</div>
      </div>
    </div>

    <div class="menu">
      <div class="menu-row" @click="openSettings">
        <span class="menu-icon">⚙️</span>
        <span class="menu-label">设置</span>
        <span class="menu-desc">存储 / 检查更新 / 偏好</span>
        <span class="menu-arrow">›</span>
      </div>
    </div>

    <div class="card">
      <h3>存储占用（storage）</h3>
      <pre :class="storageText ? 'muted' : ''">{{ storageText || '读取中…' }}</pre>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { pcall } from '../lib/pcall'
import { useConfigTick } from '../lib/configTick'

const configTick = useConfigTick()

const environment = ref('web')
const storageCount = ref(null)

const platformText = computed(() => {
  const envMap = { android: 'Android', ios: 'iOS', harmony: 'HarmonyOS NEXT', web: 'Web' }
  return envMap[environment.value] || environment.value
})

const profileName = computed(() => {
  void configTick.value
  const e = window.coconut?.env || {}
  return e.appName || 'Coconut 用户'
})

const hybridVersion = computed(() => {
  void configTick.value
  return window.coconut?.env?.hybridVersion || '?'
})

const storageText = computed(() =>
  storageCount.value === null ? '' : `${storageCount.value} 项（h5app. 前缀与 demo 模块隔离）`)

// forward 新容器打开设置页（保留「保存并关闭」close 回传语义）
function openSettings() {
  const url = location.origin + location.pathname + '#/settings'
  window.coconut.navigator.forward({ url, header: { title: '设置' } }, () => {})
}

onMounted(async () => {
  const coconut = window.coconut
  if (coconut?.environment) environment.value = String(coconut.environment)
  const r = await pcall('storage', 'getSize', {})
  if (!r.err && r.data) storageCount.value = r.data.count ?? '?'
})
</script>

<style scoped>
.profile {
  display: flex;
  align-items: center;
  gap: 14px;
  background: var(--c-card);
  border-radius: 12px;
  padding: 18px 16px;
  margin-bottom: 16px;
  box-shadow: var(--shadow);
}
.avatar {
  flex: none;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: linear-gradient(135deg, #eef4ff, #f0fdf4);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
}
.profile-name { font-size: 17px; font-weight: 700; }
.profile-sub { font-size: 12px; color: var(--c-muted); margin-top: 4px; }

.menu {
  background: var(--c-card);
  border-radius: 12px;
  box-shadow: var(--shadow);
  margin-bottom: 16px;
  overflow: hidden;
}
.menu-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 15px 16px;
  cursor: pointer;
}
.menu-row:active { background: #f7f8fa; }
.menu-icon { flex: none; font-size: 18px; }
.menu-label { flex: none; font-size: 15px; font-weight: 500; }
.menu-desc { flex: 1; font-size: 12px; color: var(--c-muted); text-align: right; }
.menu-arrow { flex: none; color: var(--c-muted); font-size: 18px; }
</style>
