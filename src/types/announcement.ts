export type AnnouncementStatus = 'draft' | 'published'
export type Announcement = {
  id: string
  course_id: string
  author_id: string
  title: string
  body_markdown: string
  status: AnnouncementStatus
  published_at: string | null
  created_at: string
  announcement_deliveries?: { status: 'pending' | 'sent' | 'failed' }[]
}
