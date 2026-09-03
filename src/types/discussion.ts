export type DiscussionReply = {
  id: string
  authorId: string
  authorName: string
  bodyMarkdown: string
  createdAt: string
  deletedAt: string | null
}
export type DiscussionTopic = DiscussionReply & {
  title: string
  replies: DiscussionReply[]
}
