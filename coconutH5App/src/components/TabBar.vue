<script setup>
import { TABS } from '../tabs.js'

defineProps({ active: { type: String, required: true } })

// 图标内联（不用外部 icons.svg + <use>：离线 scheme coconut:// origin=null，
// 外部 SVG 引用受同源限制，内联零风险）
const ICONS = {
  home: 'M4 11.5 L12 4.5 L20 11.5 M6 10 V19.5 H18 V10',
  discover: 'M14.5 9.5 L13.2 13.2 L9.5 14.5 L10.8 10.8 Z M12 3.5 A8.5 8.5 0 1 0 12 20.5 A8.5 8.5 0 1 0 12 3.5 Z',
  ai: 'M9.5 3 L10.9 7.1 L15 8.5 L10.9 9.9 L9.5 14 L8.1 9.9 L4 8.5 L8.1 7.1 Z M17 13 L17.9 15.6 L20.5 16.5 L17.9 17.4 L17 20 L16.1 17.4 L13.5 16.5 L16.1 15.6 Z M13.5 17.5 L14 19 L15.5 19.5 L14 20 L13.5 21.5 L13 20 L11.5 19.5 L13 19 Z',
  mine: 'M12 4 A4 4 0 1 0 12 12 A4 4 0 1 0 12 4 Z M4.5 20.5 C4.5 16 8 14 12 14 C16 14 19.5 16 19.5 20.5',
}
</script>

<template>
  <nav class="tab-bar">
    <a
      v-for="t in TABS"
      :key="t.id"
      :class="['tab-item', { active: t.id === active }]"
      :href="'#/' + t.id"
      :aria-current="t.id === active ? 'page' : undefined"
    >
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"
           stroke-linecap="round" stroke-linejoin="round">
        <path :d="ICONS[t.id]" />
      </svg>
      <span>{{ t.title }}</span>
    </a>
  </nav>
</template>
