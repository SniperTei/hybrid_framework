import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],

  // 服务器配置
  server: {
    host: '0.0.0.0', // 允许外部访问
    port: 5173,      // 端口号
    strictPort: true, // 端口被占用时直接失败
  },
})
