<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { homeForRole } from '@/features/auth/authRules'
import { toAuthMessage } from '@/features/auth/authMessages'
import { useAuthStore } from '@/features/auth/authStore'

const router = useRouter()
const auth = useAuthStore()
const email = ref('')
const password = ref('')
const submitting = ref(false)
const errorMessage = ref<string | null>(null)

async function submit(): Promise<void> {
  submitting.value = true
  errorMessage.value = null
  try {
    await auth.signIn(email.value.trim(), password.value)
    if (!auth.profile) throw new Error('Profile unavailable')
    await router.replace(homeForRole(auth.profile.role))
  } catch (error) {
    errorMessage.value = toAuthMessage(error)
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <v-card class="auth-card" border>
    <v-card-text>
      <v-alert v-if="errorMessage" type="error" class="mb-4" role="alert">
        {{ errorMessage }}
      </v-alert>
      <v-form @submit.prevent="submit">
        <v-text-field
          v-model="email"
          label="Email"
          type="email"
          autocomplete="email"
          required
        />
        <v-text-field
          v-model="password"
          label="Password"
          type="password"
          autocomplete="current-password"
          required
        />
        <v-btn color="primary" type="submit" :loading="submitting" block>Sign in</v-btn>
      </v-form>
    </v-card-text>
    <v-card-actions>
      <v-btn to="/forgot-password" variant="text">Forgot password?</v-btn>
    </v-card-actions>
  </v-card>
</template>
