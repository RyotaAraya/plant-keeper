import { createApp } from 'vue'
import '@mdi/font/css/materialdesignicons.css'
import mdiWoff2Url from '@mdi/font/fonts/materialdesignicons-webfont.woff2?url'
import '@fontsource/inter/400.css'
import '@fontsource/inter/500.css'
import '@fontsource/inter/600.css'
import '@fontsource/inter/700.css'
import '@/assets/main.css'
import vuetify from '@/plugins/vuetify'
import pinia from '@/plugins/pinia'
import router from '@/router'
import App from '@/App.vue'

// アイコンフォントの取得を早めにブラウザへ指示し、初回表示でアイコンが
// 一瞬表示されない/レイアウトが揺れる問題を軽減する
const iconFontPreload = document.createElement('link')
iconFontPreload.rel = 'preload'
iconFontPreload.as = 'font'
iconFontPreload.type = 'font/woff2'
iconFontPreload.href = mdiWoff2Url
iconFontPreload.crossOrigin = 'anonymous'
document.head.appendChild(iconFontPreload)

const app = createApp(App)

app.use(pinia)
app.use(router)
app.use(vuetify)

app.mount('#app')
