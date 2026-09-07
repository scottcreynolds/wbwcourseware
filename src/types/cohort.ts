import type { CurriculumItemKind, PublicationStatus } from '@/types/course'

export type CohortStatus = 'draft' | 'active' | 'archived'
export type ReleaseMode = 'manual' | 'scheduled'
export type Cohort = { id:string; course_id:string; teacher_id:string; title:string; start_date:string; end_date:string; timezone:string; status:CohortStatus; intro_markdown:string; created_at:string; updated_at:string }
export type CohortModule = { id:string; cohort_id:string; source_module_id:string|null; title:string; description:string; position:number; release_mode:ReleaseMode; release_at:string|null; manually_released_at:string|null }
export type CohortItem = { id:string; cohort_id:string; source_item_id:string|null; kind:CurriculumItemKind; title:string; slug:string; body_markdown:string; publication_status:PublicationStatus; due_at:string|null }

