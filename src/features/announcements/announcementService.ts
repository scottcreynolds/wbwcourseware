import { supabase } from '@/lib/supabase'
import type { Announcement } from '@/types/announcement'

export const announcementService = {
  async list(cohortId: string): Promise<Announcement[]> {
    const { data, error } = await supabase.from('announcements')
      .select('*,announcement_deliveries(status)')
      .eq('cohort_id', cohortId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data as Announcement[]
  },

  async create(cohortId: string, title: string, bodyMarkdown: string): Promise<Announcement> {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) throw new Error('Authentication required')
    const { data, error } = await supabase.from('announcements').insert({
      cohort_id: cohortId,
      author_id: user.id,
      title,
      body_markdown: bodyMarkdown,
    }).select().single()
    if (error) throw error
    return data as Announcement
  },

  async publish(announcementId: string): Promise<void> {
    const { error } = await supabase.functions.invoke('publish-announcement', {
      body: { announcementId },
    })
    if (error) throw error
  },

  async update(announcementId: string, title: string, bodyMarkdown: string): Promise<void> {
    const { error } = await supabase.from('announcements')
      .update({ title, body_markdown: bodyMarkdown })
      .eq('id', announcementId)
    if (error) throw error
  },

  async remove(announcementId: string): Promise<void> {
    const { error } = await supabase.from('announcements').delete().eq('id', announcementId)
    if (error) throw error
  },
}
