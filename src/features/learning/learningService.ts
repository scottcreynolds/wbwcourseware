import { supabase } from '@/lib/supabase'
import type { CourseItemResource } from '@/types/course'
import type { LearningItemDetail, LearningOutline } from '@/types/learning'

async function loadOutline(courseId: string): Promise<LearningOutline> {
  const { data, error } = await supabase.rpc('get_student_course_outline', {
    target_course_id: courseId,
  })
  if (error) throw error
  return data as LearningOutline
}

export const learningService = {
  outline: loadOutline,

  async item(
    courseId: string,
    itemId: string,
  ): Promise<{
    item: LearningItemDetail
    resources: CourseItemResource[]
    outline: LearningOutline
  }> {
    const [itemResult, resourcesResult, outline] = await Promise.all([
      supabase.rpc('get_student_course_item', { target_course_id: courseId, target_item_id: itemId }),
      supabase.from('course_item_resources').select('*').eq('item_id', itemId).order('position'),
      loadOutline(courseId),
    ])

    if (itemResult.error) throw itemResult.error
    if (resourcesResult.error) throw resourcesResult.error
    return {
      item: itemResult.data as LearningItemDetail,
      resources: resourcesResult.data as CourseItemResource[],
      outline,
    }
  },
}
