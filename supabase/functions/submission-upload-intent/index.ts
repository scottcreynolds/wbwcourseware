import { corsHeaders } from '../_shared/cors.ts'
import { requireFunctionContext } from '../_shared/auth.ts'
import { jsonResponse } from '../_shared/http.ts'

const MAX_BYTES = 25 * 1024 * 1024
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405)
  const context = await requireFunctionContext(request)
  if (!context) return jsonResponse({ error: 'Authentication required' }, 401)
  let body: Record<string, unknown>
  try { body = await request.json() } catch { return jsonResponse({ error: 'Invalid JSON' }, 400) }
  const itemId = typeof body.itemId === 'string' && uuidPattern.test(body.itemId) ? body.itemId : null
  const fileName = typeof body.fileName === 'string' ? body.fileName.trim() : ''
  const byteSize = typeof body.byteSize === 'number' ? body.byteSize : 0
  if (!itemId || !fileName.toLowerCase().endsWith('.pdf') || body.mimeType !== 'application/pdf' || byteSize < 1 || byteSize > MAX_BYTES) {
    return jsonResponse({ error: 'Valid PDF metadata is required' }, 400)
  }
  const [{ data: profile }, { data: readable }, { data: item }] = await Promise.all([
    context.admin.from('profiles').select('role').eq('id', context.user.id).single(),
    context.caller.rpc('student_can_read_item', { target_item_id: itemId }),
    context.admin.from('course_items').select('kind').eq('id', itemId).single(),
  ])
  if (profile?.role !== 'student' || !readable || item?.kind !== 'assignment') {
    return jsonResponse({ error: 'Not authorized' }, 403)
  }
  const path = `${context.user.id}/${itemId}/${crypto.randomUUID()}.pdf`
  const { data, error } = await context.admin.storage.from('submissions').createSignedUploadUrl(path)
  if (error) return jsonResponse({ error: 'Upload could not be prepared' }, 500)
  return jsonResponse({ path, token: data.token }, 201)
})
