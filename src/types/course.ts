export type CourseStatus = 'draft' | 'active' | 'archived'
export type CurriculumItemKind = 'lecture' | 'assignment'
export type PublicationStatus = 'draft' | 'published'

export type Course = {
  id: string
  teacher_id: string
  title: string
  description: string
  status: CourseStatus
  branding_json: Record<string, unknown>
  created_at: string
  updated_at: string
}

export type CourseModule = {
  id: string
  course_id: string
  title: string
  description: string
  position: number
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

