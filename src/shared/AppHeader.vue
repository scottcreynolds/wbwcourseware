<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/features/auth/authStore'

const appName = import.meta.env.VITE_APP_NAME ?? 'Writers Be Writing'
const auth = useAuthStore()
const router = useRouter()

async function signOut(): Promise<void> {
  await auth.signOut()
  await router.push('/')
}
</script>

<template>
  <v-app-bar color="surface" flat border>
    <v-app-bar-title>
      <RouterLink class="brand-link" to="/">{{ appName }}</RouterLink>
    </v-app-bar-title>
    <nav aria-label="Account navigation">
      <v-btn v-if="auth.status === 'anonymous'" to="/login" variant="text">Sign in</v-btn>
      <template v-else-if="auth.isAuthenticated && auth.profile">
        <v-btn :to="auth.profile.role === 'teacher' ? '/teacher' : '/student'" variant="text">
          Dashboard
        </v-btn>
        <v-btn variant="text" @click="signOut">Sign out</v-btn>
      </template>
    </nav>
  </v-app-bar>
</template>
