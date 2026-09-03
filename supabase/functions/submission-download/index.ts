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
  const fileId = typeof body.fileId === 'string' && uuidPattern.test(body.fileId) ? body.fileId : null
  if (!fileId) return jsonResponse({ error: 'File is required' }, 400)
  const [{ data: readable }, { data: file }] = await Promise.all([
    context.caller.rpc('can_read_submission_file', { target_file_id: fileId }),
    context.admin.from('submission_files').select('storage_path,original_name').eq('id', fileId).single(),
  ])
  if (!readable || !file) return jsonResponse({ error: 'Not authorized' }, 403)
  const { data, error } = await context.admin.storage.from('submissions').createSignedUrl(file.storage_path, 60, {
    download: file.original_name,
  })
  if (error) return jsonResponse({ error: 'Download could not be prepared' }, 500)
  return jsonResponse({ url: data.signedUrl })
})
