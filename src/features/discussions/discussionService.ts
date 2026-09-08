import { supabase } from '@/lib/supabase'
import type { DiscussionTopic } from '@/types/discussion'

async function currentUserId(): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Authentication required')
  return user.id
}

export const discussionService = {
  async list(courseId: string): Promise<DiscussionTopic[]> {
    const { data, error } = await supabase.rpc('get_course_discussions', { target_course_id: courseId })
    if (error) throw error
    return data as DiscussionTopic[]
  },
  async createTopic(courseId: string, title: string, bodyMarkdown: string): Promise<void> {
    const { error } = await supabase.from('discussion_topics').insert({
      course_id: courseId, author_id: await currentUserId(), title, body_markdown: bodyMarkdown,
    })
    if (error) throw error
  },
  async updateTopic(id: string, title: string, bodyMarkdown: string): Promise<void> {
    const { error } = await supabase.from('discussion_topics').update({ title, body_markdown: bodyMarkdown }).eq('id', id)
    if (error) throw error
  },
  async deleteTopic(id: string): Promise<void> {
    const { error } = await supabase.from('discussion_topics').update({ deleted_at: new Date().toISOString() }).eq('id', id)
    if (error) throw error
  },
  async createReply(topicId: string, bodyMarkdown: string): Promise<void> {
    const { error } = await supabase.from('discussion_replies').insert({
      topic_id: topicId, author_id: await currentUserId(), body_markdown: bodyMarkdown,
    })
    if (error) throw error
  },
  async updateReply(id: string, bodyMarkdown: string): Promise<void> {
    const { error } = await supabase.from('discussion_replies').update({ body_markdown: bodyMarkdown }).eq('id', id)
    if (error) throw error
  },
  async deleteReply(id: string): Promise<void> {
    const { error } = await supabase.from('discussion_replies').update({ deleted_at: new Date().toISOString() }).eq('id', id)
    if (error) throw error
  },
}
