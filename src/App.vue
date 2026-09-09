<script setup lang="ts">
import { computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/shared/AppHeader.vue'
import { pageTitleOverride } from '@/app/pageTitle'

const route = useRoute()
const pageTitle = computed(() =>
  pageTitleOverride.value !== null
    ? pageTitleOverride.value
    : (typeof route.meta.title === 'string' ? route.meta.title : 'Writers Be Writing'),
)
watch(() => route.path, () => { pageTitleOverride.value = null })
</script>

<template>
  <v-app>
    <AppHeader />
    <v-main id="main-content" tabindex="-1">
      <v-container class="page-container" fluid>
        <h1 v-if="pageTitle" class="page-title">{{ pageTitle }}</h1>
        <RouterView />
      </v-container>
    </v-main>
  </v-app>
</template>
