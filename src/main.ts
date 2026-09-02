import '@mdi/font/css/materialdesignicons.css'
import 'vuetify/styles'
import '@/styles/main.css'

import { createPinia } from 'pinia'
import { createApp } from 'vue'
import App from '@/App.vue'
import { router } from '@/app/router'
import { vuetify } from '@/app/vuetify'
import { useAuthStore } from '@/features/auth/authStore'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
void useAuthStore(pinia).initialize()
app.use(router).use(vuetify).mount('#app')
