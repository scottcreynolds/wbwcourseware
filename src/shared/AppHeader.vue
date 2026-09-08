<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/features/auth/authStore'
import { useThemePreference, type ThemePreference } from '@/app/themePreference'

const appName = import.meta.env.VITE_APP_NAME ?? 'Writers Be Writing'
const auth = useAuthStore()
const router = useRouter()
const { preference, setPreference } = useThemePreference()

const themeOptions: Array<{ value: ThemePreference; label: string; icon: string }> = [
  { value: 'system', label: 'Use system setting', icon: 'mdi-theme-light-dark' },
  { value: 'light', label: 'Light', icon: 'mdi-white-balance-sunny' },
  { value: 'dark', label: 'Dark', icon: 'mdi-weather-night' },
]
const currentThemeIcon = computed(() => themeOptions.find((option) => option.value === preference.value)?.icon ?? 'mdi-theme-light-dark')

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
      <v-menu>
        <template #activator="{ props: menuProps }">
          <v-btn v-bind="menuProps" :icon="currentThemeIcon" variant="text" aria-label="Choose color theme" />
        </template>
        <v-list density="compact">
          <v-list-item
            v-for="option in themeOptions"
            :key="option.value"
            :active="preference === option.value"
            :prepend-icon="option.icon"
            :title="option.label"
            @click="setPreference(option.value)"
          />
        </v-list>
      </v-menu>
    </nav>
  </v-app-bar>
</template>
