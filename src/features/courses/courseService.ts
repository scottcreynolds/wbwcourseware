import { supabase } from '@/lib/supabase'
import type {
  Course,
  CourseItem,
  CourseItemResource,
  CourseModule,
  CourseStatus,
  CourseWorkspace,
  CurriculumItemKind,
  ModuleItemPlacement,
  PublicationStatus,
  ReleaseMode,
} from '@/types/course'

async function requireUserId(): Promise<string> {
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) throw error ?? new Error('Authentication required')
  return data.user.id
}

function defaultCourseDates(): { start_date: string; end_date: string; timezone: string } {
  const start = new Date()
  const end = new Date(start.getTime() + 90 * 24 * 60 * 60 * 1000)
  return {
    start_date: start.toISOString().slice(0, 10),
    end_date: end.toISOString().slice(0, 10),
    timezone: 'America/New_York',
  }
}

export const courseService = {
  async listCourses(): Promise<Course[]> {
    const { data, error } = await supabase.from('courses').select('*').order('updated_at', { ascending: false })
    if (error) throw error
    return data as Course[]
  },
  async createCourse(title: string): Promise<Course> {
    const teacherId = await requireUserId()
    const { data, error } = await supabase
      .from('courses')
      .insert({ teacher_id: teacherId, title: title.trim(), ...defaultCourseDates() })
      .select('*')
      .single()
    if (error) throw error
    return data as Course
  },
  async duplicateCourse(courseId: string, newTitle: string): Promise<string> {
    const { data, error } = await supabase.rpc('duplicate_course', {
      target_course_id: courseId,
      new_title: newTitle,
    })
    if (error) throw error
    return data as string
  },
  async loadWorkspace(courseId: string): Promise<CourseWorkspace> {
    const [courseResult, modulesResult, itemsResult, placementsResult] = await Promise.all([
      supabase.from('courses').select('*').eq('id', courseId).single(),
      supabase.from('course_modules').select('*').eq('course_id', courseId).order('position'),
      supabase.from('course_items').select('*').eq('course_id', courseId).order('created_at'),
      supabase.from('course_module_items').select('*').order('position'),
    ])
    const error = courseResult.error ?? modulesResult.error ?? itemsResult.error ?? placementsResult.error
    if (error) throw error
    const moduleIds = new Set((modulesResult.data as CourseModule[]).map((module) => module.id))
    return {
      course: courseResult.data as Course,
      modules: modulesResult.data as CourseModule[],
      items: itemsResult.data as CourseItem[],
      placements: (placementsResult.data as ModuleItemPlacement[]).filter((placement) =>
        moduleIds.has(placement.module_id),
      ),
    }
  },
  async updateCourse(
    courseId: string,
    values: {
      title: string
      description: string
      status: CourseStatus
      start_date: string
      end_date: string
      timezone: string
      intro_markdown: string
    },
  ): Promise<void> {
    const { error } = await supabase.from('courses').update(values).eq('id', courseId)
    if (error) throw error
  },
  async addModule(courseId: string, title: string): Promise<void> {
    const { data: position, error: positionError } = await supabase.rpc('next_course_module_position', {
      target_course_id: courseId,
    })
    if (positionError) throw positionError
    const { error } = await supabase
      .from('course_modules')
      .insert({ course_id: courseId, title: title.trim(), position })
    if (error) throw error
  },
  async updateModule(moduleId: string, title: string): Promise<void> {
    const { error } = await supabase.from('course_modules').update({ title: title.trim() }).eq('id', moduleId)
    if (error) throw error
  },
  async updateModuleRelease(
    moduleId: string,
    values: { release_mode: ReleaseMode; release_at: string | null; manually_released_at: string | null },
  ): Promise<void> {
    const { error } = await supabase.from('course_modules').update(values).eq('id', moduleId)
    if (error) throw error
  },
  async deleteModule(moduleId: string): Promise<void> {
    const { error } = await supabase.rpc('delete_course_module', { target_module_id: moduleId })
    if (error) throw error
  },
  async reorderModules(courseId: string, orderedIds: string[]): Promise<void> {
    const { error } = await supabase.rpc('reorder_course_modules', {
      target_course_id: courseId,
      ordered_ids: orderedIds,
    })
    if (error) throw error
  },
  async addItem(
    courseId: string,
    moduleId: string,
    kind: CurriculumItemKind,
    title: string,
    slug: string,
  ): Promise<string> {
    const { data, error } = await supabase.rpc('create_course_item', {
      target_course_id: courseId,
      target_module_id: moduleId,
      item_kind: kind,
      item_title: title,
      item_slug: slug,
    })
    if (error) throw error
    return data as string
  },
  async addExistingItem(moduleId: string, itemId: string): Promise<void> {
    const { data: position, error: positionError } = await supabase.rpc('next_module_item_position', {
      target_module_id: moduleId,
    })
    if (positionError) throw positionError
    const { error } = await supabase
      .from('course_module_items')
      .insert({ module_id: moduleId, item_id: itemId, position })
    if (error) throw error
  },
  async removePlacement(moduleId: string, itemId: string): Promise<void> {
    const { error } = await supabase.rpc('remove_course_item_placement', {
      target_module_id: moduleId,
      target_item_id: itemId,
    })
    if (error) throw error
  },
  async reorderModuleItems(moduleId: string, orderedIds: string[]): Promise<void> {
    const { error } = await supabase.rpc('reorder_module_items', {
      target_module_id: moduleId,
      ordered_ids: orderedIds,
    })
    if (error) throw error
  },
  async loadItem(itemId: string): Promise<{ item: CourseItem; resources: CourseItemResource[] }> {
    const [itemResult, resourcesResult] = await Promise.all([
      supabase.from('course_items').select('*').eq('id', itemId).single(),
      supabase.from('course_item_resources').select('*').eq('item_id', itemId).order('position'),
    ])
    if (itemResult.error) throw itemResult.error
    if (resourcesResult.error) throw resourcesResult.error
    return { item: itemResult.data as CourseItem, resources: resourcesResult.data as CourseItemResource[] }
  },
  async updateItem(
    itemId: string,
    values: {
      title: string
      body_markdown: string
      publication_status: PublicationStatus
      kind: CurriculumItemKind
    },
  ): Promise<void> {
    const { error } = await supabase.from('course_items').update(values).eq('id', itemId)
    if (error) throw error
  },
  async publishItem(itemId: string): Promise<void> {
    const { error } = await supabase.from('course_items').update({ publication_status: 'published' }).eq('id', itemId)
    if (error) throw error
  },
  async updateDueDate(itemId: string, dueAt: string | null): Promise<void> {
    const { error } = await supabase.from('course_items').update({ due_at: dueAt }).eq('id', itemId)
    if (error) throw error
  },
  async deleteItem(itemId: string): Promise<void> {
    const { error } = await supabase.from('course_items').delete().eq('id', itemId)
    if (error) throw error
  },
  async addResource(itemId: string, title: string, url: string, position: number): Promise<void> {
    const { error } = await supabase
      .from('course_item_resources')
      .insert({ item_id: itemId, title: title.trim(), url: url.trim(), position })
    if (error) throw error
  },
  async deleteResource(resourceId: string): Promise<void> {
    const { error } = await supabase.from('course_item_resources').delete().eq('id', resourceId)
    if (error) throw error
  },
  async reorderResources(itemId: string, orderedIds: string[]): Promise<void> {
    const { error } = await supabase.rpc('reorder_item_resources', {
      target_item_id: itemId,
      ordered_ids: orderedIds,
    })
    if (error) throw error
  },
  async importOutline(courseId: string, modules: Array<{ title: string; items: Array<{ title: string; kind: CurriculumItemKind }> }>): Promise<void> {
    const { error } = await supabase.rpc('import_course_outline', {
      target_course_id: courseId,
      outline: modules,
    })
    if (error) throw error
  },
  async uploadCurriculumAsset(file: File): Promise<{ publicUrl: string }> {
    const { data, error: invokeError } = await supabase.functions.invoke<{ path: string; token: string }>(
      'curriculum-asset-upload-intent',
      { body: { mimeType: file.type, byteSize: file.size } },
    )
    if (invokeError || !data) throw invokeError ?? new Error('Upload could not be prepared')
    const { error: uploadError } = await supabase.storage
      .from('curriculum-assets')
      .uploadToSignedUrl(data.path, data.token, file, { contentType: file.type })
    if (uploadError) throw uploadError
    const { data: publicUrlData } = supabase.storage.from('curriculum-assets').getPublicUrl(data.path)
    return { publicUrl: publicUrlData.publicUrl }
  },
}
