<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { courseService } from '@/features/courses/courseService'
import MarkdownContent from '@/shared/MarkdownContent.vue'
import type { CourseItem, CourseItemResource, CurriculumItemKind, PublicationStatus } from '@/types/course'

const route = useRoute()
const router = useRouter()
const courseId = String(route.params.courseId)
const itemId = String(route.params.itemId)
const item = ref<CourseItem | null>(null)
const resources = ref<CourseItemResource[]>([])
const loading = ref(true)
const saving = ref(false)
const errorMessage = ref<string | null>(null)
const notice = ref<string | null>(null)
const resourceTitle = ref('')
const resourceUrl = ref('')
const resourceDialog = ref(false)
const maxResourcePosition = computed(() => Math.max(-1, ...resources.value.map((resource) => resource.position)))

async function load(): Promise<void> {
  loading.value = true
  errorMessage.value = null
  try {
    const result = await courseService.loadItem(itemId)
    item.value = result.item
    resources.value = result.resources
  } catch {
    errorMessage.value = 'Curriculum item could not be loaded or you do not have access.'
  } finally {
    loading.value = false
  }
}

async function save(): Promise<void> {
  if (!item.value) return
  saving.value = true
  errorMessage.value = null
  try {
    await courseService.updateItem(itemId, { title: item.value.title.trim(), kind: item.value.kind, body_markdown: item.value.body_markdown, publication_status: item.value.publication_status })
    if (item.value.kind === 'assignment') {
      await courseService.updateDueDate(itemId, item.value.due_at ? new Date(item.value.due_at).toISOString() : null)
    }
    notice.value = 'Curriculum item saved.'
  } catch {
    errorMessage.value = 'Curriculum item could not be saved.'
  } finally {
    saving.value = false
  }
}

async function deleteItem(): Promise<void> {
  if (!item.value || !window.confirm(`Delete “${item.value.title}” from every module?`)) return
  try {
    await courseService.deleteItem(itemId)
    await router.push(`/teacher/courses/${courseId}`)
  } catch {
    errorMessage.value = 'Curriculum item could not be deleted.'
  }
}

async function importMarkdown(event: Event): Promise<void> {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file || !item.value) return
  if (!file.name.toLowerCase().endsWith('.md') || file.size > 1_000_000) {
    errorMessage.value = 'Choose a UTF-8 Markdown file no larger than 1 MB.'
    input.value = ''
    return
  }
  item.value.body_markdown = await file.text()
  input.value = ''
}

async function addResource(): Promise<void> {
  if (!resourceTitle.value.trim() || !resourceUrl.value.trim()) return
  saving.value = true
  try {
    await courseService.addResource(itemId, resourceTitle.value, resourceUrl.value, maxResourcePosition.value + 1)
    resourceTitle.value = ''
    resourceUrl.value = ''
    resourceDialog.value = false
    await load()
  } catch {
    errorMessage.value = 'Resource could not be added. Use a complete http or https URL.'
  } finally {
    saving.value = false
  }
}

async function deleteResource(resourceId: string): Promise<void> {
  try { await courseService.deleteResource(resourceId); await load() } catch { errorMessage.value = 'Resource could not be deleted.' }
}

async function moveResource(resourceId: string, direction: -1 | 1): Promise<void> {
  const ordered = [...resources.value]
  const index = ordered.findIndex((resource) => resource.id === resourceId)
  const target = index + direction
  if (target < 0 || target >= ordered.length) return
  ;[ordered[index], ordered[target]] = [ordered[target]!, ordered[index]!]
  try { await courseService.reorderResources(itemId, ordered.map((resource) => resource.id)); await load() } catch { errorMessage.value = 'Resources could not be reordered.' }
}

onMounted(load)
</script>

<template>
  <v-btn :to="`/teacher/courses/${courseId}`" variant="text" prepend-icon="mdi-arrow-left" class="mb-4">Back to course</v-btn>
  <v-alert v-if="errorMessage" type="error" class="mb-4" role="alert">{{ errorMessage }}</v-alert>
  <v-skeleton-loader v-if="loading" type="article" />
  <template v-else-if="item">
    <v-card border class="mb-6">
      <v-card-text>
        <div class="editor-meta-grid"><v-text-field v-model="item.title" label="Title" /><v-select v-model="item.kind" label="Type" :items="(['lecture', 'assignment'] satisfies CurriculumItemKind[])" /><v-select v-model="item.publication_status" label="Status" :items="(['draft', 'published'] satisfies PublicationStatus[])" /></div>
        <v-text-field v-if="item.kind === 'assignment'" v-model="item.due_at" type="datetime-local" label="Due date and time" class="mb-2" />
        <label class="file-button"><span>Import Markdown</span><input type="file" accept=".md,text/markdown,text/plain" @change="importMarkdown"></label>
        <v-textarea v-model="item.body_markdown" label="Markdown and sanitized HTML" rows="18" class="monospace-input" />
      </v-card-text>
      <v-card-actions><v-btn color="primary" :loading="saving" @click="save">Save</v-btn><v-spacer /><v-btn color="error" variant="text" @click="deleteItem">Delete item</v-btn></v-card-actions>
    </v-card>
    <v-card border class="mb-6"><v-card-title>Preview</v-card-title><v-card-text><MarkdownContent :source="item.body_markdown" /></v-card-text></v-card>
    <v-card border><v-card-title class="section-heading">Resources <v-btn size="small" @click="resourceDialog = true">Add resource</v-btn></v-card-title><v-list v-if="resources.length"><v-list-item v-for="(resource, index) in resources" :key="resource.id" :title="resource.title" :subtitle="resource.url"><template #append><div class="row-actions"><v-btn icon="mdi-arrow-up" size="small" variant="text" :disabled="index === 0" @click="moveResource(resource.id, -1)" /><v-btn icon="mdi-arrow-down" size="small" variant="text" :disabled="index === resources.length - 1" @click="moveResource(resource.id, 1)" /><v-btn icon="mdi-delete-outline" size="small" variant="text" aria-label="Delete resource" @click="deleteResource(resource.id)" /></div></template></v-list-item></v-list><v-card-text v-else>No supplemental resources yet.</v-card-text></v-card>
  </template>
  <v-dialog v-model="resourceDialog" max-width="36rem"><v-card title="Add resource"><v-card-text><v-text-field v-model="resourceTitle" label="Title" /><v-text-field v-model="resourceUrl" label="URL" type="url" placeholder="https://" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="resourceDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!resourceTitle.trim() || !resourceUrl.trim()" @click="addResource">Add</v-btn></v-card-actions></v-card></v-dialog>
  <v-snackbar :model-value="notice !== null" timeout="2500" @update:model-value="notice = $event ? notice : null">{{ notice }}</v-snackbar>
</template>
