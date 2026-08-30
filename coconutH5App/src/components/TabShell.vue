<script setup>
import { computed } from 'vue'
import { TABS, tabFromHash } from '../tabs.js'
import TabBar from './TabBar.vue'

const props = defineProps({ hash: { type: String, required: true } })

const activeTab = computed(() => tabFromHash(props.hash))
const activeComponent = computed(() =>
  TABS.find(t => t.id === activeTab.value)?.component)

// KeepAlive：tab 切换保状态（事件流 / 已读标记 / 列表数据不丢）
</script>

<template>
  <div class="tab-shell">
    <div class="tab-content">
      <div class="tab-content-inner">
        <KeepAlive>
          <component :is="activeComponent" />
        </KeepAlive>
      </div>
    </div>
    <TabBar :active="activeTab" />
  </div>
</template>
