<script setup lang="ts">
import {ref} from 'vue'
import {useRoute} from 'vue-router'
import {enrollmentService} from '@/features/enrollment/enrollmentService'
import {useAuthStore} from '@/features/auth/authStore'
const token=String(useRoute().query.token??''),auth=useAuthStore()
const displayName=ref(''),password=ref(''),confirmation=ref(''),loading=ref(false),complete=ref(false),message=ref<string|null>(token?'':'Invitation link is missing.')
async function accept(){message.value=null;if(!auth.isAuthenticated&&(password.value.length<12||password.value!==confirmation.value)){message.value=password.value.length<12?'Use at least 12 characters.':'Passwords do not match.';return}loading.value=true;try{await enrollmentService.accept(token,password.value,displayName.value);complete.value=true}catch(e){message.value=e instanceof Error?e.message:'Invitation could not be accepted.'}finally{loading.value=false}}
</script>
<template><v-card class="auth-card" border><v-card-text><v-alert v-if="message" type="error" class="mb-4">{{ message }}</v-alert><v-alert v-if="complete" type="success">Invitation accepted. Sign in to open your course.</v-alert><v-form v-else @submit.prevent="accept"><template v-if="!auth.isAuthenticated"><v-text-field v-model="displayName" label="Name" autocomplete="name" /><v-text-field v-model="password" label="Password" type="password" autocomplete="new-password" hint="At least 12 characters" /><v-text-field v-model="confirmation" label="Confirm password" type="password" autocomplete="new-password" /></template><p v-else class="mb-4">Connect this invitation to your signed-in account.</p><v-btn type="submit" color="primary" :loading="loading" :disabled="!token">Accept invitation</v-btn></v-form></v-card-text><v-card-actions v-if="complete"><v-btn to="/login">Continue to sign in</v-btn></v-card-actions></v-card></template>

