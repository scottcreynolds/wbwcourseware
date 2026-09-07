<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { courseService } from '@/features/courses/courseService'
import { parseCourseOutline } from '@/features/courses/outlineParser'
import { slugify } from '@/features/courses/slug'
import type { CourseItem, CourseModule, CourseStatus, CourseWorkspace, CurriculumItemKind } from '@/types/course'
import { cohortService } from '@/features/cohorts/cohortService'
import type { Cohort } from '@/types/cohort'

const route = useRoute()
const router = useRouter()
const courseId = String(route.params.courseId)
const workspace = ref<CourseWorkspace | null>(null)
const loading = ref(true)
const saving = ref(false)
const errorMessage = ref<string | null>(null)
const notice = ref<string | null>(null)
const activeTab = ref('modules')
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
const outlineDialog = ref(false)
const outlineSource = ref(`# Module: Foundations
## Lecture: What a Scene Does
## Assignment: Scene Analysis`)
const outlineResult = computed(() => parseCourseOutline(outlineSource.value))
const cohorts=ref<Cohort[]>([])
const cohortDialog=ref(false),cohortTitle=ref(''),cohortStart=ref(''),cohortEnd=ref(''),cohortTimezone=ref('America/New_York')

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

async function refresh(): Promise<void> {
  errorMessage.value = null
  try {
    workspace.value = await courseService.loadWorkspace(courseId)
    cohorts.value = await cohortService.listForCourse(courseId)
  } catch {
    errorMessage.value = 'Course could not be loaded or you do not have access.'
  }
}

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
  await run(() => courseService.updateCourse(courseId, { title: course.title.trim(), description: course.description, status: course.status }), 'Course details saved.')
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
  if (!window.confirm(`Delete module “${module.title}”?`)) return
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

async function createCohort():Promise<void>{if(!cohortTitle.value||!cohortStart.value||!cohortEnd.value)return;let newId='';await run(async()=>{newId=await cohortService.createFromCourse({courseId,title:cohortTitle.value,startDate:cohortStart.value,endDate:cohortEnd.value,timezone:cohortTimezone.value})},'Cohort created.');cohortDialog.value=false;if(newId)await router.push(`/teacher/cohorts/${newId}`)}

onMounted(load)
</script>

<template>
  <v-alert v-if="errorMessage" type="error" class="mb-4" role="alert">{{ errorMessage }}</v-alert>
  <v-skeleton-loader v-if="loading" type="article, list-item-three-line@2" />
  <template v-else-if="workspace">
    <div class="section-heading mb-4"><v-btn to="/teacher" variant="text" prepend-icon="mdi-arrow-left">All courses</v-btn></div>
    <v-card border class="mb-6">
      <v-card-title>Course details</v-card-title>
      <v-card-text>
        <v-text-field v-model="workspace.course.title" label="Title" />
        <v-textarea v-model="workspace.course.description" label="Description" rows="3" />
        <v-select v-model="workspace.course.status" label="Status" :items="(['draft', 'active', 'archived'] satisfies CourseStatus[])" />
      </v-card-text>
      <v-card-actions><v-btn color="primary" :loading="saving" @click="saveCourse">Save course</v-btn></v-card-actions>
    </v-card>
    <v-tabs v-model="activeTab" class="mb-4">
      <v-tab value="modules">Modules</v-tab>
      <v-tab value="cohorts">Cohorts</v-tab>
    </v-tabs>
    <v-window v-model="activeTab">
      <v-window-item value="modules">
        <div class="section-heading mb-4">
          <h2>Modules</h2>
          <div class="actions compact-actions"><v-btn variant="outlined" @click="outlineDialog = true">Import outline</v-btn><v-btn color="primary" @click="moduleDialog = true">Add module</v-btn></div>
        </div>
        <v-empty-state v-if="workspace.modules.length === 0" headline="No modules yet" text="Add one module or import your whole outline." />
        <v-expansion-panels v-else multiple>
          <v-expansion-panel v-for="(module, moduleIndex) in workspace.modules" :key="module.id" :title="module.title">
            <v-expansion-panel-text>
              <div class="row-actions mb-3">
                <v-btn size="small" :disabled="moduleIndex === 0" @click="moveModule(module, -1)">Move up</v-btn>
                <v-btn size="small" :disabled="moduleIndex === workspace.modules.length - 1" @click="moveModule(module, 1)">Move down</v-btn>
                <v-btn size="small" @click="openEditModule(module)">Rename</v-btn>
                <v-btn size="small" @click="openItemDialog(module.id)">Add item</v-btn>
                <v-btn size="small" :disabled="linkableItems(module.id).length === 0" @click="openLinkDialog(module.id)">Link existing</v-btn>
                <v-tooltip :text="moduleOnlyItems(module.id).length ? `Move or delete first: ${moduleOnlyItems(module.id).map(item => item.title).join(', ')}` : 'Delete module'">
                  <template #activator="{ props: tooltipProps }"><v-btn v-bind="tooltipProps" size="small" color="error" variant="text" :disabled="moduleOnlyItems(module.id).length > 0" @click="deleteModule(module)">Delete module</v-btn></template>
                </v-tooltip>
              </div>
              <v-list v-if="itemsFor(module.id).length">
                <v-list-item v-for="(item, itemIndex) in itemsFor(module.id)" :key="item.id" :title="item.title">
                  <template #prepend><v-chip size="small" :color="item.kind === 'assignment' ? 'secondary' : undefined">{{ item.kind }}</v-chip></template>
                  <v-list-item-subtitle>{{ item.publication_status }}</v-list-item-subtitle>
                  <template #append>
                    <div class="row-actions">
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
      <v-window-item value="cohorts">
        <div class="section-heading mb-4">
          <h2>Cohorts</h2>
          <v-btn color="primary" @click="cohortDialog=true">Create cohort</v-btn>
        </div>
        <v-list v-if="cohorts.length" lines="two"><v-list-item v-for="cohort in cohorts" :key="cohort.id" :to="`/teacher/cohorts/${cohort.id}`" :title="cohort.title" :subtitle="`${cohort.start_date}–${cohort.end_date} · ${cohort.status}`" /></v-list>
        <p v-else>No cohorts created from this course.</p>
      </v-window-item>
    </v-window>
  </template>
  <v-dialog v-model="moduleDialog" max-width="32rem"><v-card title="Add module"><v-card-text><v-text-field v-model="moduleTitle" label="Module title" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="moduleDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!moduleTitle.trim()" @click="addModule">Add</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="editModuleDialog" max-width="32rem"><v-card title="Rename module"><v-card-text><v-text-field v-model="editingModuleTitle" label="Module title" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="editModuleDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!editingModuleTitle.trim()" @click="updateModule">Save</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="itemDialog" max-width="32rem"><v-card title="Add curriculum item"><v-card-text><v-select v-model="itemKind" label="Type" :items="['lecture', 'assignment']" /><v-text-field v-model="itemTitle" label="Title" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="itemDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!itemTitle.trim()" @click="addItem">Create and edit</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="linkDialog" max-width="36rem"><v-card title="Link existing item"><v-card-text><v-select v-model="linkItemId" label="Curriculum item" :items="linkableItems(linkModuleId)" item-title="title" item-value="id" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="linkDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!linkItemId" @click="linkItem">Link</v-btn></v-card-actions></v-card></v-dialog>
  <v-dialog v-model="moveDialog" max-width="36rem"><v-card title="Move to module"><v-card-text><v-select v-model="moveTargetModuleId" label="Target module" :items="moveTargetOptions(moveItemId)" item-title="title" item-value="id" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="moveDialog = false">Cancel</v-btn><v-btn color="primary" :disabled="!moveTargetModuleId" :loading="saving" @click="moveItemToModule">Move</v-btn></v-card-actions></v-card></v-dialog>
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
  <v-dialog v-model="cohortDialog" max-width="40rem"><v-card title="Create cohort from course"><v-card-text><v-text-field v-model="cohortTitle" label="Cohort title" /><div class="editor-meta-grid"><v-text-field v-model="cohortStart" type="date" label="Start date" /><v-text-field v-model="cohortEnd" type="date" label="End date" /></div><v-text-field v-model="cohortTimezone" label="IANA timezone" hint="Example: America/New_York" /></v-card-text><v-card-actions><v-spacer /><v-btn @click="cohortDialog=false">Cancel</v-btn><v-btn color="primary" :disabled="!cohortTitle||!cohortStart||!cohortEnd" @click="createCohort">Create snapshot</v-btn></v-card-actions></v-card></v-dialog>
  <v-snackbar :model-value="notice !== null" timeout="2500" @update:model-value="notice = $event ? notice : null">{{ notice }}</v-snackbar>
</template>
