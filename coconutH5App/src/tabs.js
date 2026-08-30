// tab 配置（用户要求放 app 内，不下沉 SDK）
// id 即 hash 路由：#/home | #/discover | #/ai | #/mine（默认 home）
// 注意：#/ai/<tool> 前缀被 App.vue 抢占为 AI 工具二级页（全屏无 tab）
import HomeTab from './pages/HomeTab.vue'
import DiscoverTab from './pages/DiscoverTab.vue'
import AiTab from './pages/AiTab.vue'
import MineTab from './pages/MineTab.vue'

export const TABS = [
  { id: 'home', title: '首页', component: HomeTab },
  { id: 'discover', title: '发现', component: DiscoverTab },
  { id: 'ai', title: 'AI', component: AiTab },
  { id: 'mine', title: '我的', component: MineTab },
]

export const DEFAULT_TAB = 'home'

export function tabFromHash(hash) {
  const id = (hash.match(/^#\/([a-z]+)/) || [])[1]
  return TABS.some(t => t.id === id) ? id : DEFAULT_TAB
}
