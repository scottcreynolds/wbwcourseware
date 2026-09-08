export type CourseStatus = 'draft' | 'active' | 'archived'
export type CurriculumItemKind = 'lecture' | 'assignment'
export type PublicationStatus = 'draft' | 'published'
export type ReleaseMode = 'manual' | 'scheduled'

export type Course = {
  id: string
  teacher_id: string
  title: string
  description: string
  status: CourseStatus
  branding_json: Record<string, unknown>
  start_date: string
  end_date: string
  timezone: string
  intro_markdown: string
  created_at: string
  updated_at: string
}

export type CourseModule = {
  id: string
  course_id: string
  title: string
  description: string
  position: number
  release_mode: ReleaseMode
  release_at: string | null
  manually_released_at: string | null
  created_at: string
  updated_at: string
}

export type CourseItem = {
  id: string
  course_id: string
  kind: CurriculumItemKind
  title: string
  slug: string
  body_markdown: string
  publication_status: PublicationStatus
  due_at: string | null
  created_at: string
  updated_at: string
}

export type ModuleItemPlacement = {
  module_id: string
  item_id: string
  position: number
  created_at: string
}

export type CourseItemResource = {
  id: string
  item_id: string
  title: string
  url: string
  description: string
  position: number
  created_at: string
  updated_at: string
}

export type CourseWorkspace = {
  course: Course
  modules: CourseModule[]
  items: CourseItem[]
  placements: ModuleItemPlacement[]
}
