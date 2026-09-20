import { corsHeaders } from '../_shared/cors.ts'
import { requireFunctionContext } from '../_shared/auth.ts'
import { jsonResponse } from '../_shared/http.ts'

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405)
  const context = await requireFunctionContext(request)
  if (!context) return jsonResponse({ error: 'Authentication required' }, 401)
  let body: Record<string, unknown>
  try { body = await request.json() } catch { return jsonResponse({ error: 'Invalid JSON' }, 400) }
  const submissionId = typeof body.submissionId === 'string' && uuidPattern.test(body.submissionId) ? body.submissionId : null
  if (!submissionId) return jsonResponse({ error: 'Submission is required' }, 400)

  const { data: submission } = await context.admin
    .from('submissions')
    .select('student_id, course_item_id')
    .eq('id', submissionId)
    .single()
  if (!submission) return jsonResponse({ error: 'Submission not found' }, 404)
  const { data: item } = await context.admin
    .from('course_items')
    .select('course_id')
    .eq('id', submission.course_item_id)
    .single()
  if (!item) return jsonResponse({ error: 'Submission not found' }, 404)
  const isOwner = submission.student_id === context.user.id
  const { data: isTeacher } = isOwner
    ? { data: false }
    : await context.caller.rpc('owns_course', { target_course_id: item.course_id })
  if (!isOwner && !isTeacher) return jsonResponse({ error: 'Not authorized' }, 403)

  const { data: deletedFiles, error } = await context.admin.rpc('delete_submission', {
    target_submission_id: submissionId,
  })
  if (error) return jsonResponse({ error: 'Submission could not be deleted' }, 400)

  const paths = (deletedFiles as { storage_path: string }[] | null ?? []).map((file) => file.storage_path)
  if (paths.length > 0) {
    await context.admin.storage.from('submissions').remove(paths)
  }
  return jsonResponse({ deleted: true })
})
