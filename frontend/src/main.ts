import { createApp } from 'vue'
import '@mdi/font/css/materialdesignicons.css'
import vuetify from '@/plugins/vuetify'
import pinia from '@/plugins/pinia'
import router from '@/router'
import App from '@/App.vue'
import { useAuthStore } from '@/stores/auth'

const app = createApp(App)

app.use(pinia)
app.use(router)
app.use(vuetify)

const authStore = useAuthStore()
authStore.initialize().then(() => {
  app.mount('#app')
})
