<script setup lang="ts">
import { computed,onMounted,ref } from 'vue'
import { useRoute } from 'vue-router'
import { cohortService } from '@/features/cohorts/cohortService'
import type { Cohort,CohortItem,CohortModule,CohortStatus,ReleaseMode } from '@/types/cohort'

const id=String(useRoute().params.cohortId)
const cohort=ref<Cohort|null>(null),modules=ref<CohortModule[]>([]),items=ref<CohortItem[]>([])
const loading=ref(true),saving=ref(false),message=ref<string|null>(null)
const assignments=computed(()=>items.value.filter(i=>i.kind==='assignment'))
async function load(){loading.value=true;try{const r=await cohortService.load(id);cohort.value=r.cohort;modules.value=r.modules;items.value=r.items}catch{message.value='Cohort could not be loaded.'}finally{loading.value=false}}
async function run(action:()=>Promise<void>,text:string){saving.value=true;message.value=null;try{await action();message.value=text;await load()}catch(e){message.value=e instanceof Error?e.message:'Change could not be saved.'}finally{saving.value=false}}
async function saveCohort(){if(!cohort.value)return;const c=cohort.value;await run(()=>cohortService.updateCohort(id,{title:c.title,status:c.status,start_date:c.start_date,end_date:c.end_date,timezone:c.timezone}),'Cohort saved.')}
async function saveModule(module:CohortModule){const releaseAt=module.release_mode==='scheduled'&&module.release_at?new Date(module.release_at).toISOString():null;await run(()=>cohortService.updateModule(module.id,{release_mode:module.release_mode,release_at:releaseAt,manually_released_at:module.release_mode==='manual'?module.manually_released_at:null}),'Module release updated.')}
function toggleManual(module:CohortModule){module.manually_released_at=module.manually_released_at?null:new Date().toISOString();void saveModule(module)}
async function saveDue(item:CohortItem){await run(()=>cohortService.updateDueDate(item.id,item.due_at?new Date(item.due_at).toISOString():null),'Due date saved.')}
onMounted(load)
</script>
<template>
  <v-alert v-if="message" type="info" class="mb-4">{{ message }}</v-alert><v-skeleton-loader v-if="loading" type="article" />
  <template v-else-if="cohort">
    <v-card border class="mb-6"><v-card-title>Cohort details</v-card-title><v-card-text><v-text-field v-model="cohort.title" label="Title" /><div class="editor-meta-grid"><v-text-field v-model="cohort.start_date" type="date" label="Start date" /><v-text-field v-model="cohort.end_date" type="date" label="End date" /><v-text-field v-model="cohort.timezone" label="IANA timezone" /><v-select v-model="cohort.status" :items="(['draft','active','archived'] satisfies CohortStatus[])" label="Status" /></div></v-card-text><v-card-actions><v-btn color="primary" :loading="saving" @click="saveCohort">Save</v-btn></v-card-actions></v-card>
    <h2 class="mb-3">Module release</h2><v-card v-for="module in modules" :key="module.id" border class="mb-3"><v-card-title>{{ module.title }}</v-card-title><v-card-text><v-select v-model="module.release_mode" :items="(['manual','scheduled'] satisfies ReleaseMode[])" label="Release method" /><v-text-field v-if="module.release_mode==='scheduled'" v-model="module.release_at" type="datetime-local" label="Release date and time" /><v-btn v-else variant="outlined" @click="toggleManual(module)">{{ module.manually_released_at?'Lock module':'Release now' }}</v-btn></v-card-text><v-card-actions v-if="module.release_mode==='scheduled'"><v-btn @click="saveModule(module)">Save schedule</v-btn></v-card-actions></v-card>
    <h2 class="mt-6 mb-3">Assignment due dates</h2><v-card v-for="item in assignments" :key="item.id" border class="mb-3"><v-card-title>{{ item.title }}</v-card-title><v-card-text><v-text-field v-model="item.due_at" type="datetime-local" label="Due date and time" /></v-card-text><v-card-actions><v-btn @click="saveDue(item)">Save due date</v-btn></v-card-actions></v-card>
  </template>
</template>

