<script setup lang="ts">
import { ref } from 'vue'
import { authService } from '@/features/auth/authService'
import { toAuthMessage } from '@/features/auth/authMessages'

const email = ref('')
const submitting = ref(false)
const complete = ref(false)
const errorMessage = ref<string | null>(null)

async function submit(): Promise<void> {
  submitting.value = true
  errorMessage.value = null
  try {
    await authService.requestPasswordReset(
      email.value.trim(),
      `${window.location.origin}/update-password`,
    )
    complete.value = true
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
      <v-alert v-if="complete" type="success" role="status">
        If that email belongs to an account, a password-reset link has been sent.
      </v-alert>
      <template v-else>
        <p class="mb-4">Enter your account email. The response will not reveal whether an account exists.</p>
        <v-alert v-if="errorMessage" type="error" class="mb-4" role="alert">
          {{ errorMessage }}
        </v-alert>
        <v-form @submit.prevent="submit">
          <v-text-field v-model="email" label="Email" type="email" autocomplete="email" required />
          <v-btn color="primary" type="submit" :loading="submitting">Send reset link</v-btn>
        </v-form>
      </template>
    </v-card-text>
  </v-card>
</template>

