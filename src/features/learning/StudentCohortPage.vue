<script setup lang="ts">
import {computed,onMounted,ref} from 'vue'
import {useRoute} from 'vue-router'
import {learningService} from '@/features/learning/learningService'
import {formatCourseDate} from '@/features/learning/dateFormat'
import type {LearningOutline} from '@/types/learning'
import AnnouncementList from '@/features/announcements/AnnouncementList.vue'
import DiscussionBoard from '@/features/discussions/DiscussionBoard.vue'
import MarkdownContent from '@/shared/MarkdownContent.vue'
const id=String(useRoute().params.cohortId),outline=ref<LearningOutline|null>(null),loading=ref(true),errorMessage=ref<string|null>(null)
const availableCount=computed(()=>outline.value?.modules.filter(module=>module.isVisible).length??0)
onMounted(async()=>{try{outline.value=await learningService.outline(id)}catch{errorMessage.value='This cohort is unavailable or you no longer have access.'}finally{loading.value=false}})
</script>
<template>
  <v-btn to="/student" variant="text" prepend-icon="mdi-arrow-left" class="mb-4">My courses</v-btn>
  <v-alert v-if="errorMessage" type="error">{{ errorMessage }}</v-alert><v-skeleton-loader v-else-if="loading" type="article,list-item-three-line@3" />
  <template v-else-if="outline">
    <header class="course-header"><p class="eyebrow">{{ outline.course.title }}</p><h2>{{ outline.cohort.title }}</h2><p>{{ outline.cohort.startDate }}–{{ outline.cohort.endDate }}</p></header>
    <v-card v-if="outline.cohort.introMarkdown.trim()" border class="mb-6"><v-card-text><MarkdownContent :source="outline.cohort.introMarkdown" /></v-card-text></v-card>
    <AnnouncementList :cohort-id="id" class="mb-6" />
    <v-empty-state v-if="availableCount===0" headline="Nothing released yet" text="Your teacher will release modules when they are ready." />
    <v-card v-for="module in outline.modules" :key="module.id" border class="mb-4" :class="{'locked-module':!module.isVisible}">
      <v-card-title><v-icon :icon="module.isVisible?'mdi-book-open-page-variant':'mdi-lock-outline'" class="mr-2" />{{ module.title }}</v-card-title>
      <v-card-text><p v-if="module.description">{{ module.description }}</p><p v-if="!module.isVisible" class="text-medium-emphasis">{{ module.releaseAt?`Available ${formatCourseDate(module.releaseAt,outline.cohort.timezone)}`:'Not released yet.' }}</p><v-list v-else-if="module.items.length"><v-list-item v-for="item in module.items" :key="item.id" :to="`/student/cohorts/${id}/items/${item.id}`" :title="item.title"><template #prepend><v-icon :icon="item.kind==='assignment'?'mdi-file-upload-outline':'mdi-text-box-outline'" /></template><v-list-item-subtitle v-if="item.dueAt">Due {{ formatCourseDate(item.dueAt,outline.cohort.timezone) }}</v-list-item-subtitle></v-list-item></v-list><p v-else class="text-medium-emphasis">No published items in this module.</p></v-card-text>
    </v-card>
    <DiscussionBoard :cohort-id="id" class="mt-6" />
  </template>
</template>
