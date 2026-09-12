<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch, type ComponentPublicInstance } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useDraggable, type DraggableEvent } from 'vue-draggable-plus'
import { pageTitleOverride } from '@/app/pageTitle'
import { courseService } from '@/features/courses/courseService'
import { datetimeLocalToIso, defaultDueDatetimeLocal, isoToDatetimeLocal } from '@/features/courses/datetimeLocal'
import { formatCourseDate } from '@/features/learning/dateFormat'
import { parseCourseOutline } from '@/features/courses/outlineParser'
import { slugify } from '@/features/courses/slug'
import { enrollmentService } from '@/features/enrollment/enrollmentService'
import type { CourseEnrollment, CourseInvitation } from '@/types/enrollment'
import type { CourseItem, CourseModule, CourseStatus, CourseWorkspace, CurriculumItemKind } from '@/types/course'
import AnnouncementList from '@/features/announcements/AnnouncementList.vue'
import DiscussionBoard from '@/features/discussions/DiscussionBoard.vue'
import SubmissionPanel from '@/features/submissions/SubmissionPanel.vue'
import MarkdownContent from '@/shared/MarkdownContent.vue'

const route = useRoute()
const router = useRouter()
const courseId = String(route.params.courseId)
const workspace = ref<CourseWorkspace | null>(null)
const loading = ref(true)
const saving = ref(false)
const errorMessage = ref<string | null>(null)
const notice = ref<string | null>(null)
const validTabs = ['details', 'modules', 'release', 'students', 'announcements', 'discussions'] as const
const requestedTab = String(route.query.tab ?? '')
const activeTab = ref(validTabs.includes(requestedTab as (typeof validTabs)[number]) ? requestedTab : 'details')
const announcementListRef = ref<InstanceType<typeof AnnouncementList> | null>(null)
const discussionBoardRef = ref<InstanceType<typeof DiscussionBoard> | null>(null)
const moduleDialog = ref(false)
const moduleTitle = ref('')
const editModuleDialog = ref(false)
const editingModuleId = ref('')
const editingModuleTitle = ref('')
const itemDialog = ref(false)
const itemModuleId = ref('')
const itemTitle = ref('')
const itemKind = ref<CurriculumItemKind>('lecture')
const linkDialog = ref(false)
const linkModuleId = ref('')
const linkItemId = ref<string | null>(null)
const moveDialog = ref(false)
const moveSourceModuleId = ref('')
const moveItemId = ref('')
const moveTargetModuleId = ref<string | null>(null)
const previewDialog = ref(false)
const previewItem = ref<CourseItem | null>(null)
const outlineDialog = ref(false)
const outlineSource = ref(`# Module: Foundations
## Lecture: What a Scene Does
## Assignment: Scene Analysis`)
const outlineResult = computed(() => parseCourseOutline(outlineSource.value))
const duplicateDialog = ref(false)
const duplicateTitle = ref('')

const invitations = ref<CourseInvitation[]>([])
const enrollments = ref<CourseEnrollment[]>([])
const inviteEmail = ref('')
const localInviteUrl = ref<string | null>(null)

const activeEnrollments = computed(() => enrollments.value.filter((enrollment) => enrollment.status === 'active'))
const removedEnrollments = computed(() => enrollments.value.filter((enrollment) => enrollment.status === 'removed'))
const pendingInvitations = computed(() => invitations.value.filter((invitation) => invitation.status === 'pending'))

const expandedModulesKey = `course-editor:${courseId}:expanded-modules`
function readExpandedModules(): string[] {
  try {
    const stored = localStorage.getItem(expandedModulesKey)
    if (!stored) return []
    const parsed: unknown = JSON.parse(stored)
    return Array.isArray(parsed) ? parsed.filter((value): value is string => typeof value === 'string') : []
  } catch {
    return []
  }
}
const expandedModules = ref<string[]>(readExpandedModules())
watch(expandedModules, (ids) => {
  try {
    localStorage.setItem(expandedModulesKey, JSON.stringify(ids))
  } catch {
    // ignore write failures, expansion state still applies for this session
  }
}, { deep: true })

const assignments = computed(() => workspace.value?.items.filter((item) => item.kind === 'assignment') ?? [])

function itemById(id: string): CourseItem | undefined {
  return workspace.value?.items.find((item) => item.id === id)
}

function itemsFor(moduleId: string): CourseItem[] {
  if (!workspace.value) return []
  return workspace.value.placements
    .filter((placement) => placement.module_id === moduleId)
    .sort((a, b) => a.position - b.position)
    .map((placement) => itemById(placement.item_id))
    .filter((item): item is CourseItem => item !== undefined)
}

function linkableItems(moduleId: string): CourseItem[] {
  const present = new Set(itemsFor(moduleId).map((item) => item.id))
  return workspace.value?.items.filter((item) => !present.has(item.id)) ?? []
}

function placementCount(itemId: string): number {
  return workspace.value?.placements.filter((placement) => placement.item_id === itemId).length ?? 0
}

function moduleOnlyItems(moduleId: string): CourseItem[] {
  return itemsFor(moduleId).filter((item) => placementCount(item.id) <= 1)
}

function moveTargetOptions(itemId: string): CourseModule[] {
  const present = new Set(workspace.value?.placements.filter((placement) => placement.item_id === itemId).map((placement) => placement.module_id))
  return workspace.value?.modules.filter((module) => !present.has(module.id)) ?? []
}

async function fetchCourseState(): Promise<void> {
  const [ws, inv, enr] = await Promise.all([
    courseService.loadWorkspace(courseId),
    enrollmentService.listInvitations(courseId),
    enrollmentService.listEnrollments(courseId),
  ])
  workspace.value = ws
  invitations.value = inv
  enrollments.value = enr
}

async function refresh(): Promise<void> {
  errorMessage.value = null
  try {
    await fetchCourseState()
  } catch {
    errorMessage.value = 'Course could not be loaded or you do not have access.'
  }
}

async function refreshQuietly(): Promise<void> {
  try {
    await fetchCourseState()
  } catch {
    // Background tab-switch refresh: keep the last-good cached data visible and stay silent on failure.
  }
}

const tabsWithSharedRefresh = new Set(['details', 'modules', 'release', 'students'])
watch(activeTab, (tab) => {
  if (tabsWithSharedRefresh.has(tab)) void refreshQuietly()
  else if (tab === 'announcements') void announcementListRef.value?.refresh()
  else if (tab === 'discussions') void discussionBoardRef.value?.refresh()
})

async function load(): Promise<void> {
  loading.value = true
  await refresh()
  loading.value = false
}

async function run(action: () => Promise<void>, success: string): Promise<void> {
  saving.value = true
  errorMessage.value = null
  try {
    await action()
    await refresh()
    notice.value = success
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'Change could not be saved.'
  } finally {
    saving.value = false
  }
}

async function saveCourse(): Promise<void> {
  if (!workspace.value) return
  const course = workspace.value.course
  await run(
    () =>
      courseService.updateCourse(courseId, {
        title: course.title.trim(),
        description: course.description,
        status: course.status,
        start_date: course.start_date,
        end_date: course.end_date,
        timezone: course.timezone,
        intro_markdown: course.intro_markdown,
      }),
    'Course details saved.',
  )
}

async function addModule(): Promise<void> {
  if (!moduleTitle.value.trim()) return
  await run(() => courseService.addModule(courseId, moduleTitle.value), 'Module added.')
  moduleTitle.value = ''
  moduleDialog.value = false
}

function openEditModule(module: CourseModule): void {
  editingModuleId.value = module.id
  editingModuleTitle.value = module.title
  editModuleDialog.value = true
}

async function updateModule(): Promise<void> {
  if (!editingModuleTitle.value.trim()) return
  await run(() => courseService.updateModule(editingModuleId.value, editingModuleTitle.value), 'Module updated.')
  editModuleDialog.value = false
}

async function deleteModule(module: CourseModule): Promise<void> {
  if (!window.confirm(`Delete module "${module.title}"?`)) return
  await run(() => courseService.deleteModule(module.id), 'Module deleted.')
}

async function moveModule(module: CourseModule, direction: -1 | 1): Promise<void> {
  if (!workspace.value) return
  const ordered = [...workspace.value.modules].sort((a, b) => a.position - b.position)
  const index = ordered.findIndex((candidate) => candidate.id === module.id)
  const target = index + direction
  if (target < 0 || target >= ordered.length) return
  ;[ordered[index], ordered[target]] = [ordered[target]!, ordered[index]!]
  await run(() => courseService.reorderModules(courseId, ordered.map((entry) => entry.id)), 'Modules reordered.')
}

let modulesDraggableReady = false
function registerModulesList(el: Element | ComponentPublicInstance | null): void {
  if (modulesDraggableReady) return
  const domEl = el instanceof HTMLElement ? el : (el as ComponentPublicInstance | null)?.$el
  if (!(domEl instanceof HTMLElement)) return
  modulesDraggableReady = true
  useDraggable(domEl, {
    handle: '.drag-handle',
    animation: 150,
    immediate: false,
    onEnd: (event: DraggableEvent) => onModulesDragEnd(event.oldIndex, event.newIndex),
  }).start()
}

async function onModulesDragEnd(oldIndex: number | undefined, newIndex: number | undefined): Promise<void> {
  if (!workspace.value || oldIndex === undefined || newIndex === undefined || oldIndex === newIndex) return
  const ordered = [...workspace.value.modules].sort((a, b) => a.position - b.position)
  const [moved] = ordered.splice(oldIndex, 1)
  if (!moved) return
  ordered.splice(newIndex, 0, moved)
  await run(() => courseService.reorderModules(courseId, ordered.map((entry) => entry.id)), 'Modules reordered.')
}

const draggableItemModules = new Set<string>()
function registerItemsList(moduleId: string, el: Element | ComponentPublicInstance | null): void {
  if (draggableItemModules.has(moduleId)) return
  const domEl = el instanceof HTMLElement ? el : (el as ComponentPublicInstance | null)?.$el
  if (!(domEl instanceof HTMLElement)) return
  draggableItemModules.add(moduleId)
  useDraggable(domEl, {
    handle: '.drag-handle',
    animation: 150,
    immediate: false,
    onEnd: (event: DraggableEvent) => onItemsDragEnd(moduleId, event.oldIndex, event.newIndex),
  }).start()
}

async function onItemsDragEnd(moduleId: string, oldIndex: number | undefined, newIndex: number | undefined): Promise<void> {
  if (oldIndex === undefined || newIndex === undefined || oldIndex === newIndex) return
  const ordered = itemsFor(moduleId)
  const [moved] = ordered.splice(oldIndex, 1)
  if (!moved) return
  ordered.splice(newIndex, 0, moved)
  await run(() => courseService.reorderModuleItems(moduleId, ordered.map((item) => item.id)), 'Items reordered.')
}

function isModuleReleased(module: CourseModule): boolean {
  return module.release_mode === 'scheduled'
    ? Boolean(module.release_at && new Date(module.release_at) <= new Date())
    : Boolean(module.manually_released_at)
}

async function toggleModuleRelease(module: CourseModule): Promise<void> {
  const released = isModuleReleased(module)
  module.release_mode = 'manual'
  module.release_at = null
  module.manually_released_at = released ? null : new Date().toISOString()
  await run(
    () =>
      courseService.updateModuleRelease(module.id, {
        release_mode: 'manual',
        release_at: null,
        manually_released_at: module.manually_released_at,
      }),
    released ? `"${module.title}" locked.` : `"${module.title}" released.`,
  )
}

function setDueAtLocal(item: CourseItem, value: string): void {
  item.due_at = datetimeLocalToIso(value)
}

async function saveDueDate(item: CourseItem): Promise<void> {
  await run(() => courseService.updateDueDate(item.id, item.due_at), 'Due date saved.')
}

function openItemDialog(moduleId: string): void {
  itemModuleId.value = moduleId
  itemTitle.value = ''
  itemKind.value = 'lecture'
  itemDialog.value = true
}

async function addItem(): Promise<void> {
  if (!itemTitle.value.trim()) return
  let newId = ''
  await run(async () => {
    newId = await courseService.addItem(courseId, itemModuleId.value, itemKind.value, itemTitle.value, slugify(itemTitle.value))
  }, 'Curriculum item created.')
  itemDialog.value = false
  if (newId) await router.push(`/teacher/courses/${courseId}/items/${newId}`)
}

function openLinkDialog(moduleId: string): void {
  linkModuleId.value = moduleId
  linkItemId.value = null
  linkDialog.value = true
}

async function linkItem(): Promise<void> {
  if (!linkItemId.value) return
  await run(() => courseService.addExistingItem(linkModuleId.value, linkItemId.value!), 'Item linked to module.')
  linkDialog.value = false
}

function openMoveDialog(moduleId: string, itemId: string): void {
  moveSourceModuleId.value = moduleId
  moveItemId.value = itemId
  moveTargetModuleId.value = null
  moveDialog.value = true
}

async function moveItemToModule(): Promise<void> {
  if (!moveTargetModuleId.value) return
  await run(async () => {
    await courseService.addExistingItem(moveTargetModuleId.value!, moveItemId.value)
    await courseService.removePlacement(moveSourceModuleId.value, moveItemId.value)
  }, 'Item moved to module.')
  moveDialog.value = false
}

async function publishItem(item: CourseItem): Promise<void> {
  await run(() => courseService.publishItem(item.id), `"${item.title}" published.`)
}

async function publishAllInModule(module: CourseModule): Promise<void> {
  const drafts = itemsFor(module.id).filter((item) => item.publication_status === 'draft')
  if (drafts.length === 0) return
  await run(
    () => Promise.all(drafts.map((item) => courseService.publishItem(item.id))).then(() => undefined),
    `Published ${drafts.length} item${drafts.length === 1 ? '' : 's'} in "${module.title}".`,
  )
}

function openPreview(item: CourseItem): void {
  previewItem.value = item
  previewDialog.value = true
}

async function moveItem(moduleId: string, itemId: string, direction: -1 | 1): Promise<void> {
  const ordered = itemsFor(moduleId)
  const index = ordered.findIndex((item) => item.id === itemId)
  const target = index + direction
  if (target < 0 || target >= ordered.length) return
  ;[ordered[index], ordered[target]] = [ordered[target]!, ordered[index]!]
  await run(() => courseService.reorderModuleItems(moduleId, ordered.map((item) => item.id)), 'Items reordered.')
}

async function removePlacement(moduleId: string, itemId: string): Promise<void> {
  saving.value = true
  errorMessage.value = null
  try {
    await courseService.removePlacement(moduleId, itemId)
    await refresh()
    notice.value = 'Item removed from module.'
  } catch {
    errorMessage.value = 'Item must remain in at least one module. Add it elsewhere before removing this placement.'
  } finally {
    saving.value = false
  }
}

async function importOutline(): Promise<void> {
  if (outlineResult.value.errors.length > 0) return
  await run(() => courseService.importOutline(courseId, outlineResult.value.modules), 'Course outline imported.')
  outlineDialog.value = false
}

async function duplicateCourse(): Promise<void> {
  if (!duplicateTitle.value.trim()) return
  let newId = ''
  await run(async () => {
    newId = await courseService.duplicateCourse(courseId, duplicateTitle.value.trim())
  }, 'Course duplicated.')
  duplicateDialog.value = false
  if (newId) await router.push(`/teacher/courses/${newId}`)
}

async function sendInvite(email: string): Promise<void> {
  try {
    const result = await enrollmentService.invite(courseId, email)
    localInviteUrl.value = result.developmentInviteUrl ?? null
    notice.value = result.emailStatus === 'sent' ? 'Invitation sent.' : 'Invitation created.'
    await refresh()
  } catch {
    errorMessage.value = 'Invitation could not be created.'
  }
}

async function invite(): Promise<void> {
  if (!inviteEmail.value) return
  const email = inviteEmail.value
  inviteEmail.value = ''
  await sendInvite(email)
}

const resendingInvitationId = ref<string | null>(null)
async function resend(invitation: CourseInvitation): Promise<void> {
  resendingInvitationId.value = invitation.id
  await sendInvite(invitation.email_normalized)
  resendingInvitationId.value = null
}

async function revoke(invitationId: string): Promise<void> {
  await run(() => enrollmentService.revoke(invitationId), 'Invitation revoked.')
}

async function removeStudent(enrollmentId: string): Promise<void> {
  if (window.confirm('Remove this student from the course? Their records will remain.')) {
    await run(() => enrollmentService.remove(enrollmentId), 'Student removed.')
  }
}

watch(
  () => workspace.value?.course.title,
  (title) => {
    pageTitleOverride.value = title?.trim() || null
  },
)
onBeforeUnmount(() => {
  pageTitleOverride.value = null
})

onMounted(load)
</script>

<template>
  <v-alert v-if="errorMessage" type="error" class="mb-4" role="alert">{{ errorMessage }}</v-alert>
  <v-skeleton-loader v-if="loading" type="article, list-item-three-line@2" />
  <template v-else-if="workspace">
    <v-btn to="/teacher" variant="text" icon="mdi-arrow-left" aria-label="All courses" class="mb-4" />
    <v-tabs v-model="activeTab" class="mb-4">
      <v-tab value="details">Details</v-tab>
      <v-tab value="modules">Modules</v-tab>
      <v-tab value="release">Due dates</v-tab>
      <v-tab value="students">Students</v-tab>
      <v-tab value="announcements">Announcements</v-tab>
      <v-tab value="discussions">Discussions</v-tab>
    </v-tabs>
    <v-window v-model="activeTab">
      <v-window-item value="details">
        <v-card border class="mb-6">
          <v-card-title>Course details</v-card-title>
          <v-card-text>
            <v-text-field v-model="workspace.course.title" label="Title" />
            <v-textarea v-model="workspace.course.description" label="Description" rows="3" />
            <div class="editor-meta-grid">
              <v-text-field v-model="workspace.course.start_date" type="date" label="Start date" />
              <v-text-field v-model="workspace.course.end_date" type="date" label="End date" />
              <v-text-field v-model="workspace.course.timezone" label="IANA timezone" hint="Example: America/New_York" />
              <v-select v-model="workspace.course.status" label="Status" :items="(['draft', 'active', 'archived'] satisfies CourseStatus[])" />
            </div>
            <v-textarea
              v-model="workspace.course.intro_markdown"
              label="Intro (Markdown)"
              rows="8"
              class="monospace-input mt-2"
              hint="Shown to students at the top of their course page. Use it for meeting times, location, and a welcome message."
              persistent-hint
            />
          </v-card-text>
          <v-card-actions>
            <v-btn color="primary" :loading="saving" @click="saveCourse">Save course</v-btn>
            <v-spacer />
            <v-btn variant="outlined" prepend-icon="mdi-content-copy" @click="duplicateDialog = true">Duplicate course</v-btn>
          </v-card-actions>
        </v-card>
        <v-card v-if="workspace.course.intro_markdown.trim()" border class="mb-6">
          <v-card-title>Intro preview</v-card-title>
          <v-card-text><MarkdownContent :source="workspace.course.intro_markdown" /></v-card-text>
        </v-card>
      </v-window-item>
      <v-window-item value="modules">
        <div class="section-heading mb-4">
          <h2>Modules</h2>
          <div class="actions compact-actions"><v-btn variant="outlined" @click="outlineDialog = true">Import outline</v-btn><v-btn color="primary" @click="moduleDialog = true">Add module</v-btn></div>
        </div>
        <v-empty-state v-if="workspace.modules.length === 0" headline="No modules yet" text="Add one module or import your whole outline." />
        <v-expansion-panels v-else :ref="(el: Element | ComponentPublicInstance | null) => registerModulesList(el)" v-model="expandedModules" multiple>
          <v-expansion-panel v-for="(module, moduleIndex) in workspace.modules" :key="module.id" :value="module.id">
            <v-expansion-panel-title>
              <v-icon icon="mdi-drag" class="drag-handle mr-1" aria-hidden="true" @click.stop />
              {{ module.title }}
              <v-chip size="x-small" class="ml-2" :color="isModuleReleased(module) ? 'success' : 'neutral'" variant="flat">{{ isModuleReleased(module) ? 'Released' : 'Locked' }}</v-chip>
            </v-expansion-panel-title>
            <v-expansion-panel-text>
              <div class="row-actions mb-3">
                <v-btn size="small" :disabled="moduleIndex === 0" @click="moveModule(module, -1)">Move up</v-btn>
                <v-btn size="small" :disabled="moduleIndex === workspace.modules.length - 1" @click="moveModule(module, 1)">Move down</v-btn>
                <v-btn size="small" @click="openEditModule(module)">Rename</v-btn>
                <v-btn size="small" @click="openItemDialog(module.id)">Add item</v-btn>
                <v-btn size="small" :disabled="linkableItems(module.id).length === 0" @click="openLinkDialog(module.id)">Link existing</v-btn>
                <v-tooltip :text="itemsFor(module.id).some(item => item.publication_status === 'draft') ? 'Publish every draft item in this module' : 'All items already published'">
                  <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" size="small" color="primary" variant="tonal" :loading="saving" :disabled="!itemsFor(module.id).some(item => item.publication_status === 'draft')" @click="publishAllInModule(module)">Publish all</v-btn></template>
                </v-tooltip>
                <v-tooltip :text="isModuleReleased(module) ? 'Lock this module from students' : 'Release this module to students now'">
                  <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" size="small" color="secondary" variant="tonal" :loading="saving" @click="toggleModuleRelease(module)">{{ isModuleReleased(module) ? 'Lock module' : 'Release module' }}</v-btn></template>
                </v-tooltip>
                <v-tooltip :text="moduleOnlyItems(module.id).length ? `Move or delete first: ${moduleOnlyItems(module.id).map(item => item.title).join(', ')}` : 'Delete module'">
                  <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" size="small" color="error" variant="text" :disabled="moduleOnlyItems(module.id).length > 0" @click="deleteModule(module)">Delete module</v-btn></template>
                </v-tooltip>
              </div>
              <v-list v-if="itemsFor(module.id).length" :ref="(el: Element | ComponentPublicInstance | null) => registerItemsList(module.id, el)">
                <v-list-item v-for="(item, itemIndex) in itemsFor(module.id)" :key="item.id" :title="item.title">
                  <template #prepend><v-icon icon="mdi-drag" class="drag-handle mr-2" aria-hidden="true" /><v-chip size="small" :color="item.kind === 'assignment' ? 'secondary' : undefined">{{ item.kind }}</v-chip></template>
                  <v-list-item-subtitle>
                    <v-chip size="x-small" :color="item.publication_status === 'published' ? 'success' : 'neutral'" variant="flat">{{ item.publication_status }}</v-chip>
                    <v-chip v-if="item.kind === 'assignment' && item.due_at" size="x-small" variant="tonal" class="ml-1">Due {{ formatCourseDate(item.due_at, workspace.course.timezone) }}</v-chip>
                  </v-list-item-subtitle>
                  <template #append>
                    <div class="row-actions">
                      <v-btn v-if="item.publication_status === 'draft'" size="small" color="primary" variant="tonal" :loading="saving" @click="publishItem(item)">Publish</v-btn>
                      <v-tooltip text="Preview">
                        <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-eye-outline" size="small" variant="text" aria-label="Preview" @click="openPreview(item)" /></template>
                      </v-tooltip>
                      <v-tooltip text="Move up">
                        <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-arrow-up" size="small" variant="text" :disabled="itemIndex === 0" aria-label="Move up" @click="moveItem(module.id, item.id, -1)" /></template>
                      </v-tooltip>
                      <v-tooltip text="Move down">
                        <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-arrow-down" size="small" variant="text" :disabled="itemIndex === itemsFor(module.id).length - 1" aria-label="Move down" @click="moveItem(module.id, item.id, 1)" /></template>
                      </v-tooltip>
                      <v-tooltip text="Edit">
                        <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-pencil-outline" size="small" variant="text" :to="`/teacher/courses/${courseId}/items/${item.id}`" aria-label="Edit" /></template>
                      </v-tooltip>
                      <v-tooltip :text="moveTargetOptions(item.id).length ? 'Move to module' : 'No other module to move to'">
                        <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-folder-move-outline" size="small" variant="text" :disabled="moveTargetOptions(item.id).length === 0" aria-label="Move to module" @click="openMoveDialog(module.id, item.id)" /></template>
                      </v-tooltip>
                      <v-tooltip :text="placementCount(item.id) > 1 ? 'Remove from module' : 'Item must remain in at least one module'">
                        <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" icon="mdi-link-off" size="small" variant="text" :disabled="placementCount(item.id) <= 1" aria-label="Remove from module" @click="removePlacement(module.id, item.id)" /></template>
                      </v-tooltip>
                    </div>
                  </template>
                </v-list-item>
              </v-list>
              <p v-else class="text-medium-emphasis">No curriculum items in this module.</p>
            </v-expansion-panel-text>
          </v-expansion-panel>
        </v-expansion-panels>
      </v-window-item>
      <v-window-item value="release">
        <h2 class="mb-3">Assignment due dates</h2>
        <v-card v-for="item in assignments" :key="item.id" border class="mb-3">
          <v-card-title>{{ item.title }}</v-card-title>
          <v-card-text><v-text-field :model-value="item.due_at ? isoToDatetimeLocal(item.due_at) : defaultDueDatetimeLocal()" type="datetime-local" label="Due date and time" @update:model-value="(value: string) => setDueAtLocal(item, value)" /></v-card-text>
          <v-card-actions><v-btn color="primary" @click="saveDueDate(item)">Save due date</v-btn></v-card-actions>
        </v-card>
        <h2 class="mt-6 mb-3">Submission review</h2>
        <v-expansion-panels multiple>
          <v-expansion-panel v-for="item in assignments" :key="item.id">
            <v-expansion-panel-title>{{ item.title }}</v-expansion-panel-title>
            <v-expansion-panel-text><SubmissionPanel :item-id="item.id" /></v-expansion-panel-text>
          </v-expansion-panel>
        </v-expansion-panels>
      </v-window-item>
      <v-window-item value="students">
        <v-card border class="mb-4">
          <v-card-title>Invite student</v-card-title>
          <v-card-text>
            <div class="invite-row"><v-text-field v-model="inviteEmail" type="email" label="Student email" /><v-btn color="primary" @click="invite">Send invite</v-btn></div>
            <v-alert v-if="localInviteUrl" type="info">Local invite link: <a :href="localInviteUrl">{{ localInviteUrl }}</a></v-alert>
          </v-card-text>
        </v-card>
        <v-list border rounded>
          <v-list-subheader>Active</v-list-subheader>
          <v-list-item
            v-for="enrollment in activeEnrollments"
            :key="enrollment.id"
            :title="enrollment.profiles?.display_name || enrollment.profiles?.email_normalized || 'Student'"
            subtitle="active"
          >
            <template #append><v-btn color="error" variant="text" @click="removeStudent(enrollment.id)">Remove</v-btn></template>
          </v-list-item>
          <v-list-item v-if="!activeEnrollments.length" title="No active students" />
          <v-list-subheader>Pending</v-list-subheader>
          <v-list-item
            v-for="invitation in pendingInvitations"
            :key="invitation.id"
            :title="invitation.email_normalized"
            :subtitle="`pending · expires ${new Date(invitation.expires_at).toLocaleDateString()}`"
          >
            <template #append>
              <div class="row-actions">
                <v-btn variant="text" :loading="resendingInvitationId === invitation.id" @click="resend(invitation)">Resend</v-btn>
                <v-btn variant="text" @click="revoke(invitation.id)">Revoke</v-btn>
              </div>
            </template>
          </v-list-item>
          <v-list-item v-if="!pendingInvitations.length" title="No pending invitations" />
        </v-list>
        <v-expansion-panels v-if="removedEnrollments.length" class="mt-4">
          <v-expansion-panel title="Removed">
            <v-expansion-panel-text>
              <v-list>
                <v-list-item
                  v-for="enrollment in removedEnrollments"
                  :key="enrollment.id"
                  :title="enrollment.profiles?.display_name || enrollment.profiles?.email_normalized || 'Student'"
                  subtitle="removed"
                />
              </v-list>
            </v-expansion-panel-text>
          </v-expansion-panel>
        </v-expansion-panels>
      </v-window-item>
      <v-window-item value="announcements">
        <AnnouncementList ref="announcementListRef" :course-id="courseId" teacher />
      </v-window-item>
      <v-window-item value="discussions">
        <DiscussionBoard ref="discussionBoardRef" :course-id="courseId" teacher />
      </v-window-item>
    </v-window>
  </template>
  <v-dialog v-model="moduleDialog" max-width="32rem"><v-card title="Add module"><v-card-text><v-text-field v-model="moduleTitle" label="Module title" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="moduleDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!moduleTitle.trim()" @click="addModule">Add</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="editModuleDialog" max-width="32rem"><v-card title="Rename module"><v-card-text><v-text-field v-model="editingModuleTitle" label="Module title" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="editModuleDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!editingModuleTitle.trim()" @click="updateModule">Save</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="itemDialog" max-width="32rem"><v-card title="Add curriculum item"><v-card-text><v-select v-model="itemKind" label="Type" :items="['lecture', 'assignment']" /><v-text-field v-model="itemTitle" label="Title" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="itemDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!itemTitle.trim()" @click="addItem">Create and edit</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="linkDialog" max-width="36rem"><v-card title="Link existing item"><v-card-text><v-select v-model="linkItemId" label="Curriculum item" :items="linkableItems(linkModuleId)" item-title="title" item-value="id" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="linkDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!linkItemId" @click="linkItem">Link</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="moveDialog" max-width="36rem"><v-card title="Move to module"><v-card-text><v-select v-model="moveTargetModuleId" label="Target module" :items="moveTargetOptions(moveItemId)" item-title="title" item-value="id" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="moveDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!moveTargetModuleId" :loading="saving" @click="moveItemToModule">Move</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="previewDialog" max-width="64rem" height="90vh" scrollable>
    <v-card v-if="previewItem" :title="previewItem.title">
      <v-card-text>
        <MarkdownContent :source="previewItem.body_markdown" />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="previewDialog = false">Close</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
  <v-dialog v-model="outlineDialog" max-width="64rem">
    <v-card title="Import course outline">
      <v-card-text>
        <p class="mb-3">Use <code># Module:</code>, then <code>## Lecture:</code> or <code>## Assignment:</code>.</p>
        <v-textarea v-model="outlineSource" label="Markdown outline" rows="10" class="monospace-input" />
        <v-alert v-if="outlineResult.errors.length" type="error" variant="tonal"><ul><li v-for="error in outlineResult.errors" :key="error">{{ error }}</li></ul></v-alert>
        <div v-else>
          <h3 class="mb-2">Preview and edit</h3>
          <v-card v-for="(module, moduleIndex) in outlineResult.modules" :key="moduleIndex" border class="mb-2">
            <v-card-text>
              <v-text-field v-model="module.title" label="Module title" density="compact" />
              <div v-for="(item, itemIndex) in module.items" :key="itemIndex" class="outline-item-row">
                <v-select v-model="item.kind" label="Type" :items="['lecture', 'assignment']" density="compact" />
                <v-text-field v-model="item.title" label="Item title" density="compact" />
              </div>
            </v-card-text>
          </v-card>
        </div>
      </v-card-text>
      <v-card-actions><v-spacer /><v-btn @click="outlineDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="outlineResult.errors.length > 0" :loading="saving" @click="importOutline">Import</v-btn></v-card-actions>
    </v-card>
  </v-dialog>
  <v-dialog v-model="duplicateDialog" max-width="32rem">
    <v-card title="Duplicate course">
      <v-card-text>
        <p class="mb-3 text-medium-emphasis">Creates a new draft course with a copy of this course's modules, items, and resources. Release schedule and due dates reset; enrollment is not copied.</p>
        <v-text-field v-model="duplicateTitle" label="New course title" autofocus @keyup.enter="duplicateCourse" />
      </v-card-text>
      <v-card-actions><v-spacer /><v-btn @click="duplicateDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!duplicateTitle.trim()" :loading="saving" @click="duplicateCourse">Duplicate</v-btn></v-card-actions>
    </v-card>
  </v-dialog>
  <v-snackbar :model-value="notice !== null" timeout="2500" @update:model-value="notice = $event ? notice : null">{{ notice }}</v-snackbar>
</template>
