<script setup lang="ts">
import { ref } from 'vue'
import { authService } from '@/features/auth/authService'
import { toAuthMessage } from '@/features/auth/authMessages'

const password = ref('')
const confirmation = ref('')
const submitting = ref(false)
const complete = ref(false)
const errorMessage = ref<string | null>(null)

async function submit(): Promise<void> {
  errorMessage.value = null
  if (password.value.length < 12) {
    errorMessage.value = 'Use at least 12 characters.'
    return
  }
  if (password.value !== confirmation.value) {
    errorMessage.value = 'Passwords do not match.'
    return
  }

  submitting.value = true
  try {
    await authService.updatePassword(password.value)
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
        Password updated. You can continue to your dashboard.
      </v-alert>
      <v-form v-else @submit.prevent="submit">
        <v-alert v-if="errorMessage" type="error" class="mb-4" role="alert">
          {{ errorMessage }}
        </v-alert>
        <v-text-field
          v-model="password"
          label="New password"
          type="password"
          autocomplete="new-password"
          hint="At least 12 characters"
          required
        />
        <v-text-field
          v-model="confirmation"
          label="Confirm new password"
          type="password"
          autocomplete="new-password"
          required
        />
        <v-btn color="primary" type="submit" :loading="submitting">Update password</v-btn>
      </v-form>
    </v-card-text>
    <v-card-actions v-if="complete">
      <v-btn color="primary" to="/">Continue</v-btn>
    </v-card-actions>
  </v-card>
</template>

