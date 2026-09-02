<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/shared/AppHeader.vue'

const route = useRoute()
const pageTitle = computed(() =>
  typeof route.meta.title === 'string' ? route.meta.title : 'Writers Be Writing',
)
</script>

<template>
  <v-app>
    <AppHeader />
    <v-main id="main-content" tabindex="-1">
      <v-container class="page-container" fluid>
        <h1 class="page-title">{{ pageTitle }}</h1>
        <RouterView />
      </v-container>
    </v-main>
  </v-app>
</template>
