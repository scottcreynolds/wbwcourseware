import {supabase} from '@/lib/supabase'
import type {Cohort} from '@/types/cohort'
import type {CohortEnrollment,CohortInvitation} from '@/types/enrollment'
type InviteResult={status:string;invitationId:string;emailStatus:string;developmentInviteUrl?:string}
export const enrollmentService={
 async listInvitations(cohortId:string):Promise<CohortInvitation[]>{const {data,error}=await supabase.from('cohort_invitations').select('id,cohort_id,email_normalized,status,expires_at,created_at').eq('cohort_id',cohortId).order('created_at',{ascending:false});if(error)throw error;return data as CohortInvitation[]},
 async listEnrollments(cohortId:string):Promise<CohortEnrollment[]>{const {data,error}=await supabase.from('cohort_enrollments').select('id,cohort_id,student_id,status,activated_at,removed_at,profiles(display_name,email_normalized)').eq('cohort_id',cohortId).order('activated_at');if(error)throw error;return data as unknown as CohortEnrollment[]},
 async invite(cohortId:string,email:string):Promise<InviteResult>{const {data,error}=await supabase.functions.invoke<InviteResult>('invite-student',{body:{cohortId,email}});if(error)throw error;return data!},
 async revoke(invitationId:string):Promise<void>{const {error}=await supabase.from('cohort_invitations').update({status:'revoked'}).eq('id',invitationId).eq('status','pending');if(error)throw error},
 async remove(enrollmentId:string):Promise<void>{const {error}=await supabase.from('cohort_enrollments').update({status:'removed',removed_at:new Date().toISOString()}).eq('id',enrollmentId);if(error)throw error},
 async accept(token:string,password:string,displayName:string):Promise<void>{const {error}=await supabase.functions.invoke('accept-invite',{body:{token,password,displayName}});if(error)throw error},
 async studentCohorts():Promise<Cohort[]>{const {data,error}=await supabase.from('cohorts').select('*').order('start_date',{ascending:false});if(error)throw error;return data as Cohort[]},
}

