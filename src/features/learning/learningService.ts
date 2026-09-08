import { supabase } from '@/lib/supabase'
import type { CohortItem } from '@/types/cohort'
import type { CourseItemResource } from '@/types/course'
import type { LearningOutline } from '@/types/learning'

async function loadOutline(cohortId: string): Promise<LearningOutline> {
  const { data, error } = await supabase.rpc('get_student_cohort_outline', {
    target_cohort_id: cohortId,
  })
  if (error) throw error
  return data as LearningOutline
}

export const learningService = {
  outline: loadOutline,

  async item(
    cohortId: string,
    itemId: string,
  ): Promise<{
    item: CohortItem
    resources: CourseItemResource[]
    outline: LearningOutline
  }> {
    const [itemResult, resourcesResult, outline] = await Promise.all([
      supabase.from('cohort_items').select('*').eq('id', itemId).eq('cohort_id', cohortId).single(),
      supabase.from('cohort_item_resources').select('*').eq('item_id', itemId).order('position'),
      loadOutline(cohortId),
    ])

    if (itemResult.error) throw itemResult.error
    if (resourcesResult.error) throw resourcesResult.error
    return {
      item: itemResult.data as CohortItem,
      resources: resourcesResult.data as CourseItemResource[],
      outline,
    }
  },
}
