<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from '@/features/auth/authStore'
import { validateSubmissionFile } from '@/features/submissions/submissionRules'
import { submissionService } from '@/features/submissions/submissionService'
import type { AssignmentSubmission, SubmissionVersion } from '@/types/submission'

const props = defineProps<{ itemId: string; canSubmit?: boolean; teacher?: boolean; preloadedSubmissions?: AssignmentSubmission[] }>()
const emit = defineEmits<{ deleted: [] }>()
const auth = useAuthStore()
const ownFetchedSubmissions = ref<AssignmentSubmission[]>([])
const submissions = computed(() => props.preloadedSubmissions ?? ownFetchedSubmissions.value)
const files = ref<File[]>([])
const loading = ref(!props.preloadedSubmissions)
const saving = ref(false)
const deletingId = ref<string | null>(null)
const message = ref<string | null>(null)
const own = computed(() => submissions.value.find((entry) => entry.studentId === auth.profile?.id))
function canDelete(submission: AssignmentSubmission): boolean {
  return Boolean(props.teacher || submission.studentId === auth.profile?.id)
}
const submittedEntries = computed(() => submissions.value.filter((entry) => entry.versions.length > 0))
const unsubmittedEntries = computed(() => submissions.value.filter((entry) => entry.versions.length === 0))
function latestVersion(submission: AssignmentSubmission): SubmissionVersion {
  const [version] = submission.versions
  if (!version) throw new Error('latestVersion called on a submission with no versions')
  return version
}

async function load(): Promise<void> {
  if (props.preloadedSubmissions) return
  loading.value = true
  try {
    ownFetchedSubmissions.value = await submissionService.list(props.itemId)
  } catch {
    message.value = 'Submissions could not be loaded.'
  } finally {
    loading.value = false
  }
}

async function submit(): Promise<void> {
  const issue = files.value.map(validateSubmissionFile).find(Boolean)
  if (!files.value.length || issue) {
    message.value = issue ?? 'Choose at least one PDF.'
    return
  }
  saving.value = true
  message.value = null
  try {
    await submissionService.submit(props.itemId, files.value)
    files.value = []
    message.value = 'Submission version added.'
    await load()
  } catch {
    message.value = 'Submission failed. No version was created.'
  } finally {
    saving.value = false
  }
}

async function remove(submission: AssignmentSubmission): Promise<void> {
  if (!submission.id) return
  if (!window.confirm(`Delete ${submission.studentName}'s submission? This removes every version and file.`)) return
  deletingId.value = submission.id
  message.value = null
  try {
    await submissionService.remove(submission.id)
    message.value = 'Submission deleted.'
    await load()
    emit('deleted')
  } catch {
    message.value = 'Submission could not be deleted.'
  } finally {
    deletingId.value = null
  }
}

onMounted(load)
</script>

<template>
  <section class="submission-panel" aria-labelledby="submissions-heading">
    <h3 id="submissions-heading">Submissions</h3>
    <v-alert v-if="message" type="info" class="mb-3">{{ message }}</v-alert>
    <v-skeleton-loader v-if="loading" type="list-item-three-line@2" />
    <v-empty-state v-else-if="!submissions.length" headline="No submissions yet" />
    <template v-else>
      <h4 class="submission-section-heading">Submitted ({{ submittedEntries.length }})</h4>
      <p v-if="!submittedEntries.length" class="text-medium-emphasis">No submissions received yet.</p>
      <div v-for="submission in submittedEntries" :key="submission.studentId" class="submission-row">
        <span class="submission-row-student">{{ submission.studentName }}</span>
        <span class="submission-row-files">
          <span v-for="file in latestVersion(submission).files" :key="file.id" class="submission-file-row">
            <v-icon icon="mdi-file-pdf-box" aria-hidden="true" />
            <span class="submission-file-name">{{ file.name }}</span>
            <v-tooltip text="Preview">
              <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-eye-outline" size="small" variant="text" :aria-label="`Preview ${file.name}`" @click="submissionService.preview(file.id)" /></template>
            </v-tooltip>
            <v-tooltip text="Download">
              <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-download" size="small" variant="text" :aria-label="`Download ${file.name}`" @click="submissionService.download(file.id)" /></template>
            </v-tooltip>
          </span>
        </span>
        <span class="submission-row-date">
          {{ new Date(latestVersion(submission).submittedAt).toLocaleString() }}
          <v-chip v-if="latestVersion(submission).isLate" color="warning" variant="flat" size="small" class="ml-2">Late</v-chip>
        </span>
        <span class="submission-row-actions">
          <v-tooltip v-if="submission.id && canDelete(submission)" text="Delete submission">
            <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-delete-outline" size="small" variant="text" color="error" :loading="deletingId === submission.id" :aria-label="`Delete ${submission.studentName}'s submission`" @click="remove(submission)" /></template>
          </v-tooltip>
        </span>
      </div>

      <template v-if="teacher">
        <h4 class="submission-section-heading">Not submitted ({{ unsubmittedEntries.length }})</h4>
        <p v-if="!unsubmittedEntries.length" class="text-medium-emphasis">Every student has submitted.</p>
        <div v-for="submission in unsubmittedEntries" :key="submission.studentId" class="submission-row">
          <span class="submission-row-student">{{ submission.studentName }}</span>
        </div>
      </template>
    </template>
    <template v-if="canSubmit">
      <v-divider class="my-6" />
      <h3 id="submit-heading">Submit your assignment</h3>
      <v-card border class="mt-3">
        <v-card-title>{{ own ? 'Add another version' : 'Submit assignment' }}</v-card-title>
        <v-card-text>
          <v-file-input
            v-model="files" label="PDF files" accept="application/pdf,.pdf" multiple
            hint="PDF only; 25 MB maximum per file" persistent-hint
          />
        </v-card-text>
        <v-card-actions><v-btn color="primary" :disabled="!files.length" :loading="saving" @click="submit">Submit files</v-btn></v-card-actions>
      </v-card>
    </template>
  </section>
</template>
