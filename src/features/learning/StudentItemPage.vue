<script setup lang="ts">
import {computed,ref,watch} from 'vue'
import {useRoute} from 'vue-router'
import {learningService} from '@/features/learning/learningService'
import {formatCourseDate} from '@/features/learning/dateFormat'
import MarkdownContent from '@/shared/MarkdownContent.vue'
import SubmissionPanel from '@/features/submissions/SubmissionPanel.vue'
import type {CourseItemResource} from '@/types/course'
import type {LearningItemDetail,LearningOutline} from '@/types/learning'
const route=useRoute()
const courseId=computed(()=>String(route.params.courseId))
const itemId=computed(()=>String(route.params.itemId))
const item=ref<LearningItemDetail|null>(null),resources=ref<CourseItemResource[]>([]),outline=ref<LearningOutline|null>(null),loading=ref(true),errorMessage=ref<string|null>(null)
const printView=computed(()=>route.name==='student-item-print')
const orderedItems=computed(()=>outline.value?.modules.flatMap(module=>module.items)??[])
const currentIndex=computed(()=>orderedItems.value.findIndex(entry=>entry.id===itemId.value))
const previousItem=computed(()=>currentIndex.value>0?orderedItems.value[currentIndex.value-1]:null)
const nextItem=computed(()=>currentIndex.value>=0&&currentIndex.value<orderedItems.value.length-1?orderedItems.value[currentIndex.value+1]:null)
async function load():Promise<void>{
  loading.value=true
  errorMessage.value=null
  try{const r=await learningService.item(courseId.value,itemId.value);item.value=r.item;resources.value=r.resources;outline.value=r.outline}
  catch{errorMessage.value='This page is locked, unpublished, missing, or outside your course.'}
  finally{loading.value=false}
}
watch(itemId,load,{immediate:true})
function printPage(){window.print()}
</script>
<template>
  <div v-if="!printView" class="screen-only section-heading mb-4"><v-btn :to="`/student/courses/${courseId}`" variant="text" prepend-icon="mdi-arrow-left">Course modules</v-btn><v-btn :to="`/student/courses/${courseId}/items/${itemId}/print`" target="_blank" prepend-icon="mdi-download">Download PDF</v-btn></div>
  <v-alert v-if="errorMessage" type="error">{{ errorMessage }}</v-alert><v-skeleton-loader v-else-if="loading" type="article" />
  <article v-else-if="item&&outline" class="print-document">
    <header class="print-header"><p class="brand-name">Writers Be Writing</p><p>{{ outline.course.title }}</p></header>
    <nav v-if="!printView && (previousItem || nextItem)" class="screen-only item-pager item-pager-top" aria-label="Curriculum navigation">
      <router-link v-if="previousItem" :to="`/student/courses/${courseId}/items/${previousItem.id}`" class="item-pager-link item-pager-previous">
        <span class="item-pager-label"><v-icon icon="mdi-arrow-left" size="small" /> Previous</span>
        <span class="item-pager-title">{{ previousItem.title }}</span>
      </router-link>
      <router-link v-if="nextItem" :to="`/student/courses/${courseId}/items/${nextItem.id}`" class="item-pager-link item-pager-next">
        <span class="item-pager-label">Next <v-icon icon="mdi-arrow-right" size="small" /></span>
        <span class="item-pager-title">{{ nextItem.title }}</span>
      </router-link>
    </nav>
    <p class="eyebrow">{{ item.kind }}</p><h2 class="document-title">{{ item.title }}</h2>
    <p v-if="item.dueAt" class="due-date">Due {{ formatCourseDate(item.dueAt,outline.course.timezone) }}</p>
    <MarkdownContent :source="item.bodyMarkdown" />
    <section v-if="resources.length" class="resource-section" aria-labelledby="resources-title"><h3 id="resources-title">Resources</h3><ol><li v-for="resource in resources" :key="resource.id"><a :href="resource.url" target="_blank" rel="noopener noreferrer">{{ resource.title }}</a><span class="print-url"> — {{ resource.url }}</span><p v-if="resource.description">{{ resource.description }}</p></li></ol></section>
    <SubmissionPanel v-if="item.kind === 'assignment' && !printView" :item-id="item.id" can-submit />
    <div v-if="printView" class="screen-only print-actions"><v-btn color="primary" prepend-icon="mdi-printer" @click="printPage">Open print / save as PDF</v-btn></div>
    <nav v-if="!printView && (previousItem || nextItem)" class="screen-only item-pager item-pager-bottom" aria-label="Curriculum navigation">
      <router-link v-if="previousItem" :to="`/student/courses/${courseId}/items/${previousItem.id}`" class="item-pager-link item-pager-previous">
        <span class="item-pager-label"><v-icon icon="mdi-arrow-left" size="small" /> Previous</span>
        <span class="item-pager-title">{{ previousItem.title }}</span>
      </router-link>
      <router-link v-if="nextItem" :to="`/student/courses/${courseId}/items/${nextItem.id}`" class="item-pager-link item-pager-next">
        <span class="item-pager-label">Next <v-icon icon="mdi-arrow-right" size="small" /></span>
        <span class="item-pager-title">{{ nextItem.title }}</span>
      </router-link>
    </nav>
  </article>
</template>
