<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from '@/features/auth/authStore'
import { validateSubmissionFile } from '@/features/submissions/submissionRules'
import { submissionService } from '@/features/submissions/submissionService'
import type { AssignmentSubmission } from '@/types/submission'

const props = defineProps<{ itemId: string; canSubmit?: boolean; preloadedSubmissions?: AssignmentSubmission[] }>()
const auth = useAuthStore()
const ownFetchedSubmissions = ref<AssignmentSubmission[]>([])
const submissions = computed(() => props.preloadedSubmissions ?? ownFetchedSubmissions.value)
const files = ref<File[]>([])
const loading = ref(!props.preloadedSubmissions)
const saving = ref(false)
const message = ref<string | null>(null)
const own = computed(() => submissions.value.find((entry) => entry.studentId === auth.profile?.id))

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

onMounted(load)
</script>

<template>
  <section class="submission-panel" aria-labelledby="submissions-heading">
    <h3 id="submissions-heading">Submitted assignments</h3>
    <v-alert v-if="message" type="info" class="mb-3">{{ message }}</v-alert>
    <v-skeleton-loader v-if="loading" type="list-item-three-line@2" />
    <v-empty-state v-else-if="!submissions.length" headline="No submissions yet" />
    <v-expansion-panels v-else multiple>
      <v-expansion-panel v-for="submission in submissions" :key="submission.studentId">
        <v-expansion-panel-title>{{ submission.studentName }} · {{ submission.versions.length ? `${submission.versions.length} version${submission.versions.length === 1 ? '' : 's'}` : 'Missing' }}</v-expansion-panel-title>
        <v-expansion-panel-text>
          <p v-if="!submission.versions.length" class="text-medium-emphasis">No submission received.</p>
          <div v-for="version in submission.versions" :key="version.id" class="mb-4">
            <strong>Version {{ version.versionNumber }}</strong>
            <v-chip v-if="version.isLate" color="warning" variant="flat" size="small" class="ml-2">Late</v-chip>
            <p class="text-medium-emphasis">{{ new Date(version.submittedAt).toLocaleString() }}</p>
            <div v-for="file in version.files" :key="file.id" class="submission-file-row">
              <v-icon icon="mdi-file-pdf-box" aria-hidden="true" />
              <span class="submission-file-name">{{ file.name }}</span>
              <v-tooltip text="Preview">
                <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-eye-outline" size="small" variant="text" :aria-label="`Preview ${file.name}`" @click="submissionService.preview(file.id)" /></template>
              </v-tooltip>
              <v-tooltip text="Download">
                <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-download" size="small" variant="text" :aria-label="`Download ${file.name}`" @click="submissionService.download(file.id)" /></template>
              </v-tooltip>
            </div>
          </div>
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>
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
