import { supabase } from '@/lib/supabase'
import type { Cohort, CohortItem, CohortModule, CohortStatus, ReleaseMode } from '@/types/cohort'

export const cohortService = {
  async listForCourse(courseId:string):Promise<Cohort[]> { const {data,error}=await supabase.from('cohorts').select('*').eq('course_id',courseId).order('start_date',{ascending:false}); if(error)throw error; return data as Cohort[] },
  async listAll():Promise<Cohort[]> { const {data,error}=await supabase.from('cohorts').select('*').order('start_date',{ascending:false}); if(error)throw error; return data as Cohort[] },
  async createFromCourse(values:{courseId:string;title:string;startDate:string;endDate:string;timezone:string}):Promise<string> { const {data,error}=await supabase.rpc('create_cohort_from_course',{target_course_id:values.courseId,cohort_title:values.title,cohort_start:values.startDate,cohort_end:values.endDate,cohort_timezone:values.timezone}); if(error)throw error; return data as string },
  async load(cohortId:string):Promise<{cohort:Cohort;modules:CohortModule[];items:CohortItem[]}> {
    const [c,m,i,effective]=await Promise.all([
      supabase.from('cohorts').select('*').eq('id',cohortId).single(),
      supabase.from('cohort_modules').select('*').eq('cohort_id',cohortId).order('position'),
      supabase.from('cohort_items').select('*').eq('cohort_id',cohortId),
      supabase.rpc('get_teacher_cohort_content',{target_cohort_id:cohortId}),
    ])
    const error=c.error??m.error??i.error??effective.error
    if(error)throw error
    const effectiveModuleTitles=new Map<string,string>((effective.data?.modules??[]).map((entry:{id:string;title:string})=>[entry.id,entry.title]))
    const effectiveItems=new Map<string,{title:string;publicationStatus:string}>((effective.data?.items??[]).map((entry:{id:string;title:string;publicationStatus:string})=>[entry.id,entry]))
    const modules=(m.data as CohortModule[]).map(module=>({...module,title:effectiveModuleTitles.get(module.id)??module.title}))
    const items=(i.data as CohortItem[]).map(item=>{
      const effectiveItem=effectiveItems.get(item.id)
      return effectiveItem?{...item,title:effectiveItem.title,publication_status:effectiveItem.publicationStatus as CohortItem['publication_status']}:item
    })
    return {cohort:c.data as Cohort,modules,items}
  },
  async updateCohort(id:string,values:{title:string;status:CohortStatus;start_date:string;end_date:string;timezone:string;intro_markdown:string}):Promise<void>{const {error}=await supabase.from('cohorts').update(values).eq('id',id);if(error)throw error},
  async updateModule(id:string,values:{release_mode:ReleaseMode;release_at:string|null;manually_released_at:string|null}):Promise<void>{const {error}=await supabase.from('cohort_modules').update(values).eq('id',id);if(error)throw error},
  async updateDueDate(id:string,dueAt:string|null):Promise<void>{const {error}=await supabase.from('cohort_items').update({due_at:dueAt}).eq('id',id);if(error)throw error},
  async syncItem(sourceItemId:string,cohortIds:string[]):Promise<number>{const {data,error}=await supabase.rpc('sync_course_item_to_cohorts',{target_source_item_id:sourceItemId,target_cohort_ids:cohortIds});if(error)throw error;return data as number},
  async syncNewContent(courseId:string,cohortIds:string[]):Promise<number>{const {data,error}=await supabase.rpc('sync_new_course_content_to_cohorts',{target_course_id:courseId,target_cohort_ids:cohortIds});if(error)throw error;return data as number},
}

