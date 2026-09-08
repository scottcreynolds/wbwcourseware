import {supabase} from '@/lib/supabase'
import type {Course} from '@/types/course'
import type {CourseEnrollment,CourseInvitation} from '@/types/enrollment'
type InviteResult={status:string;invitationId:string;emailStatus:string;developmentInviteUrl?:string}
export const enrollmentService={
 async listInvitations(courseId:string):Promise<CourseInvitation[]>{const {data,error}=await supabase.from('course_invitations').select('id,course_id,email_normalized,status,expires_at,created_at').eq('course_id',courseId).order('created_at',{ascending:false});if(error)throw error;return data as CourseInvitation[]},
 async listEnrollments(courseId:string):Promise<CourseEnrollment[]>{const {data,error}=await supabase.from('course_enrollments').select('id,course_id,student_id,status,activated_at,removed_at,profiles(display_name,email_normalized)').eq('course_id',courseId).order('activated_at');if(error)throw error;return data as unknown as CourseEnrollment[]},
 async invite(courseId:string,email:string):Promise<InviteResult>{const {data,error}=await supabase.functions.invoke<InviteResult>('invite-student',{body:{courseId,email}});if(error)throw error;return data!},
 async revoke(invitationId:string):Promise<void>{const {error}=await supabase.from('course_invitations').update({status:'revoked'}).eq('id',invitationId).eq('status','pending');if(error)throw error},
 async remove(enrollmentId:string):Promise<void>{const {error}=await supabase.from('course_enrollments').update({status:'removed',removed_at:new Date().toISOString()}).eq('id',enrollmentId);if(error)throw error},
 async accept(token:string,password:string,displayName:string):Promise<void>{const {error}=await supabase.functions.invoke('accept-invite',{body:{token,password,displayName}});if(error)throw error},
 async studentCourses():Promise<Course[]>{const {data,error}=await supabase.from('courses').select('*').order('start_date',{ascending:false});if(error)throw error;return data as Course[]},
}
