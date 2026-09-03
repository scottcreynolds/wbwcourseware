<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { announcementService } from '@/features/announcements/announcementService'
import MarkdownContent from '@/shared/MarkdownContent.vue'
import type { Announcement } from '@/types/announcement'

const props = defineProps<{ cohortId: string; teacher?: boolean }>()
const announcements = ref<Announcement[]>([])
const title = ref('')
const body = ref('')
const loading = ref(true)
const saving = ref(false)
const message = ref<string | null>(null)

async function load(): Promise<void> {
  loading.value = true
  try { announcements.value = await announcementService.list(props.cohortId) }
  catch { message.value = 'Announcements could not be loaded.' }
  finally { loading.value = false }
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
    await load()
  } catch { message.value = 'Announcement could not be saved.' }
  finally { saving.value = false }
}

async function publish(id: string): Promise<void> {
  saving.value = true
  try { await announcementService.publish(id); message.value = 'Announcement published.'; await load() }
  catch { message.value = 'Announcement could not be published.' }
  finally { saving.value = false }
}

function deliverySummary(announcement: Announcement): string {
  const deliveries = announcement.announcement_deliveries ?? []
  const sent = deliveries.filter((entry) => entry.status === 'sent').length
  const failed = deliveries.filter((entry) => entry.status === 'failed').length
  return `${sent} sent${failed ? ` · ${failed} failed` : ''}`
}

onMounted(load)
</script>

<template>
  <section aria-labelledby="announcements-heading">
    <h2 id="announcements-heading" class="mb-3">Announcements</h2>
    <v-alert v-if="message" type="info" class="mb-3">{{ message }}</v-alert>
    <v-card v-if="teacher" border class="mb-4">
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
    <v-skeleton-loader v-if="loading" type="article@2" />
    <v-empty-state v-else-if="!announcements.length" headline="No announcements" />
    <v-card v-for="announcement in announcements" v-else :key="announcement.id" border class="mb-3">
      <v-card-title>{{ announcement.title }}</v-card-title>
      <v-card-subtitle>{{ announcement.status }} · {{ new Date(announcement.published_at ?? announcement.created_at).toLocaleString() }}</v-card-subtitle>
      <v-card-text><MarkdownContent :source="announcement.body_markdown" /></v-card-text>
      <v-card-actions v-if="teacher">
        <span v-if="announcement.status === 'published'" class="text-medium-emphasis">{{ deliverySummary(announcement) }}</span>
        <v-btn v-else color="primary" :loading="saving" @click="publish(announcement.id)">Publish now</v-btn>
      </v-card-actions>
    </v-card>
  </section>
</template>
