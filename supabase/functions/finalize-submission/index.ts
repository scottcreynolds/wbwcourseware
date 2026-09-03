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
  const itemId = typeof body.itemId === 'string' && uuidPattern.test(body.itemId) ? body.itemId : null
  const files = Array.isArray(body.files) ? body.files : []
  const validFiles = files.length > 0 && files.every((file) => {
    if (!file || typeof file !== 'object') return false
    const value = file as Record<string, unknown>
    return typeof value.path === 'string' && value.path.startsWith(`${context.user.id}/${itemId}/`)
      && typeof value.name === 'string' && value.name.toLowerCase().endsWith('.pdf')
  })
  const [{ data: profile }, { data: readable }, { data: item }] = await Promise.all([
    context.admin.from('profiles').select('role').eq('id', context.user.id).single(),
    itemId ? context.caller.rpc('student_can_read_item', { target_item_id: itemId }) : Promise.resolve({ data: false }),
    itemId ? context.admin.from('cohort_items').select('kind').eq('id', itemId).single() : Promise.resolve({ data: null }),
  ])
  if (!itemId || !validFiles) return jsonResponse({ error: 'Assignment and uploaded files are required' }, 400)
  if (profile?.role !== 'student' || !readable || item?.kind !== 'assignment') return jsonResponse({ error: 'Not authorized' }, 403)
  const { data, error } = await context.admin.rpc('finalize_submission', {
    target_item_id: itemId,
    target_student_id: context.user.id,
    uploaded_files: files,
  })
  if (error) return jsonResponse({ error: 'Submission could not be finalized' }, 400)
  return jsonResponse({ versionId: data }, 201)
})
