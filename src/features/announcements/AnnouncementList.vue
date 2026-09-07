<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { announcementService } from '@/features/announcements/announcementService'
import MarkdownContent from '@/shared/MarkdownContent.vue'
import type { Announcement } from '@/types/announcement'

const REFRESH_INTERVAL_MS = 60_000

const props = defineProps<{ cohortId: string; teacher?: boolean; mostRecentOnly?: boolean }>()
const announcements = ref<Announcement[]>([])
const visibleAnnouncements = computed(() =>
  props.mostRecentOnly ? announcements.value.slice(0, 1) : announcements.value,
)
const title = ref('')
const body = ref('')
const loading = ref(true)
const refreshing = ref(false)
const saving = ref(false)
const message = ref<string | null>(null)
const editDialog = ref(false)
const editingId = ref('')
const editingTitle = ref('')
const editingBody = ref('')
let refreshTimer: ReturnType<typeof setInterval> | undefined

async function refresh(): Promise<void> {
  try { announcements.value = await announcementService.list(props.cohortId) }
  catch { message.value = 'Announcements could not be loaded.' }
}

async function load(): Promise<void> {
  loading.value = true
  await refresh()
  loading.value = false
}

async function manualRefresh(): Promise<void> {
  refreshing.value = true
  await refresh()
  refreshing.value = false
}

async function create(publish: boolean): Promise<void> {
  if (!title.value.trim()) { message.value = 'Title is required.'; return }
  saving.value = true
  try {
    const announcement = await announcementService.create(props.cohortId, title.value.trim(), body.value)
    if (publish) await announcementService.publish(announcement.id)
    title.value = ''
    body.value = ''
    message.value = publish ? 'Announcement published.' : 'Draft saved.'
    await refresh()
  } catch { message.value = 'Announcement could not be saved.' }
  finally { saving.value = false }
}

async function publish(id: string): Promise<void> {
  saving.value = true
  try { await announcementService.publish(id); message.value = 'Announcement published.'; await refresh() }
  catch { message.value = 'Announcement could not be published.' }
  finally { saving.value = false }
}

function openEdit(announcement: Announcement): void {
  editingId.value = announcement.id
  editingTitle.value = announcement.title
  editingBody.value = announcement.body_markdown
  editDialog.value = true
}

async function saveEdit(): Promise<void> {
  if (!editingTitle.value.trim()) { message.value = 'Title is required.'; return }
  saving.value = true
  try {
    await announcementService.update(editingId.value, editingTitle.value.trim(), editingBody.value)
    editDialog.value = false
    message.value = 'Announcement updated.'
    await refresh()
  } catch { message.value = 'Announcement could not be updated.' }
  finally { saving.value = false }
}

async function remove(id: string): Promise<void> {
  if (!window.confirm('Delete this announcement? This cannot be undone.')) return
  saving.value = true
  try { await announcementService.remove(id); message.value = 'Announcement deleted.'; await refresh() }
  catch { message.value = 'Announcement could not be deleted.' }
  finally { saving.value = false }
}

function deliverySummary(announcement: Announcement): string {
  const deliveries = announcement.announcement_deliveries ?? []
  const sent = deliveries.filter((entry) => entry.status === 'sent').length
  const failed = deliveries.filter((entry) => entry.status === 'failed').length
  return `${sent} sent${failed ? ` · ${failed} failed` : ''}`
}

onMounted(() => {
  void load()
  refreshTimer = setInterval(() => { void refresh() }, REFRESH_INTERVAL_MS)
})
onUnmounted(() => { if (refreshTimer) clearInterval(refreshTimer) })
</script>

<template>
  <section aria-labelledby="announcements-heading">
    <div v-if="!mostRecentOnly" class="section-heading mb-3">
      <h2 id="announcements-heading">Announcements</h2>
      <v-btn
        variant="text"
        size="small"
        prepend-icon="mdi-refresh"
        :loading="refreshing"
        aria-label="Refresh announcements"
        @click="manualRefresh"
      >
        Refresh
      </v-btn>
    </div>
    <v-alert v-if="message" type="info" class="mb-3">{{ message }}</v-alert>
    <v-card v-if="teacher && !mostRecentOnly" border class="mb-4">
      <v-card-title>New announcement</v-card-title>
      <v-card-text>
        <v-text-field v-model="title" label="Title" maxlength="200" />
        <v-textarea v-model="body" label="Message (Markdown)" rows="5" />
        <MarkdownContent :source="body" />
      </v-card-text>
      <v-card-actions>
        <v-btn :loading="saving" @click="create(false)">Save draft</v-btn>
        <v-btn color="primary" :loading="saving" @click="create(true)">Publish now</v-btn>
      </v-card-actions>
    </v-card>
    <v-skeleton-loader v-if="loading" :type="mostRecentOnly ? 'article' : 'article@2'" />
    <v-empty-state v-else-if="!visibleAnnouncements.length && !mostRecentOnly" headline="No announcements" />
    <v-card v-for="announcement in visibleAnnouncements" :key="announcement.id" border class="mb-3">
      <v-card-title>{{ announcement.title }}</v-card-title>
      <v-card-subtitle>{{ announcement.status }} · {{ new Date(announcement.published_at ?? announcement.created_at).toLocaleString() }}</v-card-subtitle>
      <v-card-text><MarkdownContent :source="announcement.body_markdown" /></v-card-text>
      <v-card-actions v-if="teacher">
        <span v-if="announcement.status === 'published'" class="text-medium-emphasis">{{ deliverySummary(announcement) }}</span>
        <v-btn v-else color="primary" :loading="saving" @click="publish(announcement.id)">Publish now</v-btn>
        <v-spacer />
        <v-btn variant="text" @click="openEdit(announcement)">Edit</v-btn>
        <v-btn color="error" variant="text" @click="remove(announcement.id)">Delete</v-btn>
      </v-card-actions>
    </v-card>
    <v-dialog v-model="editDialog" max-width="36rem">
      <v-card title="Edit announcement">
        <v-card-text>
          <v-text-field v-model="editingTitle" label="Title" maxlength="200" autofocus />
          <v-textarea v-model="editingBody" label="Message (Markdown)" rows="6" />
          <MarkdownContent :source="editingBody" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="editDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="saving" :disabled="!editingTitle.trim()" @click="saveEdit">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </section>
</template>
