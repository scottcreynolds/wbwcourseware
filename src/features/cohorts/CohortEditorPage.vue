<script setup lang="ts">
import { computed,onMounted,ref } from 'vue'
import { useRoute } from 'vue-router'
import { cohortService } from '@/features/cohorts/cohortService'
import type { Cohort,CohortItem,CohortModule,CohortStatus,ReleaseMode } from '@/types/cohort'
import {enrollmentService} from '@/features/enrollment/enrollmentService'
import type {CohortEnrollment,CohortInvitation} from '@/types/enrollment'
import SubmissionPanel from '@/features/submissions/SubmissionPanel.vue'
import AnnouncementList from '@/features/announcements/AnnouncementList.vue'
import DiscussionBoard from '@/features/discussions/DiscussionBoard.vue'
import MarkdownContent from '@/shared/MarkdownContent.vue'

const id=String(useRoute().params.cohortId)
const cohort=ref<Cohort|null>(null),modules=ref<CohortModule[]>([]),items=ref<CohortItem[]>([])
const loading=ref(true),saving=ref(false),message=ref<string|null>(null)
const assignments=computed(()=>items.value.filter(i=>i.kind==='assignment'))
const invitations=ref<CohortInvitation[]>([]),enrollments=ref<CohortEnrollment[]>([]),inviteEmail=ref(''),localInviteUrl=ref<string|null>(null)
async function load(){loading.value=true;try{const [r,inv,enr]=await Promise.all([cohortService.load(id),enrollmentService.listInvitations(id),enrollmentService.listEnrollments(id)]);cohort.value=r.cohort;modules.value=r.modules;items.value=r.items;invitations.value=inv;enrollments.value=enr}catch{message.value='Cohort could not be loaded.'}finally{loading.value=false}}
async function run(action:()=>Promise<void>,text:string){saving.value=true;message.value=null;try{await action();message.value=text;await load()}catch(e){message.value=e instanceof Error?e.message:'Change could not be saved.'}finally{saving.value=false}}
async function saveCohort(){if(!cohort.value)return;const c=cohort.value;await run(()=>cohortService.updateCohort(id,{title:c.title,status:c.status,start_date:c.start_date,end_date:c.end_date,timezone:c.timezone,intro_markdown:c.intro_markdown}),'Cohort saved.')}
async function saveModule(module:CohortModule){const releaseAt=module.release_mode==='scheduled'&&module.release_at?new Date(module.release_at).toISOString():null;await run(()=>cohortService.updateModule(module.id,{release_mode:module.release_mode,release_at:releaseAt,manually_released_at:module.release_mode==='manual'?module.manually_released_at:null}),'Module release updated.')}
function toggleManual(module:CohortModule){module.manually_released_at=module.manually_released_at?null:new Date().toISOString();void saveModule(module)}
async function saveDue(item:CohortItem){await run(()=>cohortService.updateDueDate(item.id,item.due_at?new Date(item.due_at).toISOString():null),'Due date saved.')}
async function invite(){if(!inviteEmail.value)return;try{const result=await enrollmentService.invite(id,inviteEmail.value);localInviteUrl.value=result.developmentInviteUrl??null;inviteEmail.value='';message.value=result.emailStatus==='sent'?'Invitation sent.':'Invitation created.';await load()}catch{message.value='Invitation could not be created.'}}
async function revoke(invitationId:string){await run(()=>enrollmentService.revoke(invitationId),'Invitation revoked.')}
async function removeStudent(enrollmentId:string){if(window.confirm('Remove this student from cohort? Their records will remain.'))await run(()=>enrollmentService.remove(enrollmentId),'Student removed.')}
onMounted(load)
</script>
<template>
  <v-alert v-if="message" type="info" class="mb-4">{{ message }}</v-alert><v-skeleton-loader v-if="loading" type="article" />
  <template v-else-if="cohort">
    <v-btn :to="`/teacher/courses/${cohort.course_id}`" variant="text" prepend-icon="mdi-arrow-left" class="mb-4">Back to course</v-btn>
    <v-card border class="mb-6"><v-card-title>Cohort details</v-card-title><v-card-text><v-text-field v-model="cohort.title" label="Title" /><div class="editor-meta-grid"><v-text-field v-model="cohort.start_date" type="date" label="Start date" /><v-text-field v-model="cohort.end_date" type="date" label="End date" /><v-text-field v-model="cohort.timezone" label="IANA timezone" /><v-select v-model="cohort.status" :items="(['draft','active','archived'] satisfies CohortStatus[])" label="Status" /></div><v-textarea v-model="cohort.intro_markdown" label="Intro (Markdown and sanitized HTML)" rows="10" class="monospace-input mt-2" hint="Shown to students at the top of their cohort page. Use it for meeting times, location, and a welcome message." persistent-hint /></v-card-text><v-card-actions><v-btn color="primary" :loading="saving" @click="saveCohort">Save</v-btn></v-card-actions></v-card>
    <v-card v-if="cohort.intro_markdown.trim()" border class="mb-6"><v-card-title>Intro preview</v-card-title><v-card-text><MarkdownContent :source="cohort.intro_markdown" /></v-card-text></v-card>
    <h2 class="mb-3">Module release</h2><v-card v-for="module in modules" :key="module.id" border class="mb-3"><v-card-title>{{ module.title }}</v-card-title><v-card-text><v-select v-model="module.release_mode" :items="(['manual','scheduled'] satisfies ReleaseMode[])" label="Release method" /><v-text-field v-if="module.release_mode==='scheduled'" v-model="module.release_at" type="datetime-local" label="Release date and time" /><v-btn v-else variant="outlined" @click="toggleManual(module)">{{ module.manually_released_at?'Lock module':'Release now' }}</v-btn></v-card-text><v-card-actions v-if="module.release_mode==='scheduled'"><v-btn @click="saveModule(module)">Save schedule</v-btn></v-card-actions></v-card>
    <h2 class="mt-6 mb-3">Assignment due dates</h2><v-card v-for="item in assignments" :key="item.id" border class="mb-3"><v-card-title>{{ item.title }}</v-card-title><v-card-text><v-text-field v-model="item.due_at" type="datetime-local" label="Due date and time" /></v-card-text><v-card-actions><v-btn @click="saveDue(item)">Save due date</v-btn></v-card-actions></v-card>
    <h2 class="mt-6 mb-3">Submission review</h2>
    <v-expansion-panels multiple>
      <v-expansion-panel v-for="item in assignments" :key="item.id">
        <v-expansion-panel-title>{{ item.title }}</v-expansion-panel-title>
        <v-expansion-panel-text><SubmissionPanel :item-id="item.id" /></v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>
    <h2 class="mt-6 mb-3">Students</h2><v-card border class="mb-4"><v-card-title>Invite student</v-card-title><v-card-text><div class="invite-row"><v-text-field v-model="inviteEmail" type="email" label="Student email" /><v-btn color="primary" @click="invite">Send invite</v-btn></div><v-alert v-if="localInviteUrl" type="info">Local invite link: <a :href="localInviteUrl">{{ localInviteUrl }}</a></v-alert></v-card-text></v-card>
    <v-list border rounded><v-list-subheader>Enrolled</v-list-subheader><v-list-item v-for="enrollment in enrollments" :key="enrollment.id" :title="enrollment.profiles?.display_name||enrollment.profiles?.email_normalized||'Student'" :subtitle="enrollment.status"><template #append><v-btn v-if="enrollment.status==='active'" color="error" variant="text" @click="removeStudent(enrollment.id)">Remove</v-btn></template></v-list-item><v-list-subheader>Invitations</v-list-subheader><v-list-item v-for="invitation in invitations" :key="invitation.id" :title="invitation.email_normalized" :subtitle="`${invitation.status} · expires ${new Date(invitation.expires_at).toLocaleDateString()}`"><template #append><v-btn v-if="invitation.status==='pending'" variant="text" @click="revoke(invitation.id)">Revoke</v-btn></template></v-list-item></v-list>
    <AnnouncementList :cohort-id="id" teacher class="mt-6" />
    <DiscussionBoard :cohort-id="id" teacher class="mt-6" />
  </template>
</template>
