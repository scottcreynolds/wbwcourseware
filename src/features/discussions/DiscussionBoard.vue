<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import { useAuthStore } from '@/features/auth/authStore'
import { discussionService } from '@/features/discussions/discussionService'
import MarkdownContent from '@/shared/MarkdownContent.vue'
import type { DiscussionReply, DiscussionTopic } from '@/types/discussion'

const REFRESH_INTERVAL_MS = 60_000

const props = defineProps<{ cohortId: string; teacher?: boolean }>()
const auth = useAuthStore()
const topics = ref<DiscussionTopic[]>([])
const title = ref('')
const body = ref('')
const replyDrafts = ref<Record<string, string>>({})
const message = ref<string | null>(null)
const loading = ref(true)
const refreshing = ref(false)
const newTopicDialog = ref(false)
let refreshTimer: ReturnType<typeof setInterval> | undefined

function canManage(entry: DiscussionReply): boolean { return Boolean(props.teacher || entry.authorId === auth.profile?.id) }
async function refresh(): Promise<void> {
  try { topics.value = await discussionService.list(props.cohortId) }
  catch { message.value = 'Discussions could not be loaded.' }
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
async function createTopic(): Promise<void> {
  if (!title.value.trim() || !body.value.trim()) { message.value = 'Title and message are required.'; return }
  try {
    await discussionService.createTopic(props.cohortId, title.value.trim(), body.value)
    title.value = ''
    body.value = ''
    newTopicDialog.value = false
    await refresh()
  } catch { message.value = 'Topic could not be created.' }
}
async function reply(topicId: string): Promise<void> {
  const value = replyDrafts.value[topicId]?.trim()
  if (!value) return
  try { await discussionService.createReply(topicId, value); replyDrafts.value[topicId] = ''; await refresh() }
  catch { message.value = 'Reply could not be posted.' }
}
async function editTopic(topic: DiscussionTopic): Promise<void> {
  const next = window.prompt('Edit topic message', topic.bodyMarkdown)
  if (next === null || !next.trim()) return
  await discussionService.updateTopic(topic.id, topic.title, next); await refresh()
}
async function editReply(reply: DiscussionReply): Promise<void> {
  const next = window.prompt('Edit reply', reply.bodyMarkdown)
  if (next === null || !next.trim()) return
  await discussionService.updateReply(reply.id, next); await refresh()
}
async function remove(kind: 'topic' | 'reply', id: string): Promise<void> {
  if (!window.confirm('Delete this discussion content?')) return
  if (kind === 'topic') await discussionService.deleteTopic(id)
  else await discussionService.deleteReply(id)
  await refresh()
}
onMounted(() => {
  void load()
  refreshTimer = setInterval(() => { void refresh() }, REFRESH_INTERVAL_MS)
})
onUnmounted(() => { if (refreshTimer) clearInterval(refreshTimer) })
</script>

<template>
  <section aria-labelledby="discussion-heading">
    <div class="section-heading mb-3">
      <h2 id="discussion-heading">Discussion</h2>
      <div class="row-actions">
        <v-btn
          variant="text"
          size="small"
          prepend-icon="mdi-refresh"
          :loading="refreshing"
          aria-label="Refresh discussion"
          @click="manualRefresh"
        >
          Refresh
        </v-btn>
        <v-btn color="primary" size="small" prepend-icon="mdi-plus" @click="newTopicDialog = true">Start a discussion</v-btn>
      </div>
    </div>
    <v-alert v-if="message" type="info" class="mb-3">{{ message }}</v-alert>
    <v-skeleton-loader v-if="loading" type="article@2" />
    <v-empty-state v-else-if="!topics.length" headline="No discussion topics" />
    <v-expansion-panels v-else variant="accordion">
      <v-expansion-panel v-for="topic in topics" :key="topic.id">
        <v-expansion-panel-title>
          <div class="topic-summary">
            <span class="topic-summary-title">{{ topic.deletedAt ? 'Topic deleted' : topic.title }}</span>
            <span class="topic-summary-meta text-medium-emphasis">
              {{ topic.authorName }} · {{ new Date(topic.createdAt).toLocaleString() }}
              <template v-if="!topic.deletedAt"> · {{ topic.replies.filter(r => !r.deletedAt).length }} {{ topic.replies.filter(r => !r.deletedAt).length === 1 ? 'reply' : 'replies' }}</template>
            </span>
          </div>
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <template v-if="!topic.deletedAt">
            <MarkdownContent :source="topic.bodyMarkdown" />
            <div v-if="canManage(topic)" class="row-actions mt-2 mb-2"><v-btn size="small" variant="text" @click="editTopic(topic)">Edit</v-btn><v-btn size="small" color="error" variant="text" @click="remove('topic', topic.id)">Delete</v-btn></div>
            <v-divider class="my-3" />
            <v-list><template v-for="replyItem in topic.replies" :key="replyItem.id"><v-list-item v-if="!replyItem.deletedAt"><v-list-item-title>{{ replyItem.authorName }}</v-list-item-title><MarkdownContent :source="replyItem.bodyMarkdown" /><template v-if="canManage(replyItem)" #append><v-btn icon="mdi-pencil" aria-label="Edit reply" variant="text" @click="editReply(replyItem)" /><v-btn icon="mdi-delete" aria-label="Delete reply" color="error" variant="text" @click="remove('reply', replyItem.id)" /></template></v-list-item></template></v-list>
            <v-textarea v-model="replyDrafts[topic.id]" label="Reply" rows="2" class="mt-3" />
            <v-btn color="primary" @click="reply(topic.id)">Post reply</v-btn>
          </template>
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>
    <v-dialog v-model="newTopicDialog" max-width="36rem">
      <v-card title="Start a discussion">
        <v-card-text>
          <v-text-field v-model="title" label="Topic title" maxlength="200" autofocus />
          <v-textarea v-model="body" label="Message (Markdown)" rows="6" />
          <MarkdownContent :source="body" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="newTopicDialog = false">Cancel</v-btn>
          <v-btn color="primary" :disabled="!title.trim() || !body.trim()" @click="createTopic">Post topic</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </section>
</template>
