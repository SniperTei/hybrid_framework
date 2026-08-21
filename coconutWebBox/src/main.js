import { createApp } from 'vue'
import './style.css'
import App from './App.vue'

// 离线包构建把入口 script 剥成 classic script 放在 <head>（iife + no-cors，
// 见 build-offline-package.sh），执行时 <body>（含 #app）可能尚未解析。
// 等 DOM 就绪再挂载；常规浏览器/dev server 场景 readyState 已过 loading，立即挂。
const mount = () => createApp(App).mount('#app')
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', mount)
} else {
  mount()
}
