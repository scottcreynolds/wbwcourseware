import { corsHeaders } from '../_shared/cors.ts'
import { requireFunctionContext } from '../_shared/auth.ts'
import { jsonResponse } from '../_shared/http.ts'

const MAX_BYTES = 10 * 1024 * 1024
const ALLOWED_MIME_EXTENSIONS: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/gif': 'gif',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405)
  const context = await requireFunctionContext(request)
  if (!context) return jsonResponse({ error: 'Authentication required' }, 401)

  let body: Record<string, unknown>
  try { body = await request.json() } catch { return jsonResponse({ error: 'Invalid JSON' }, 400) }

  const mimeType = typeof body.mimeType === 'string' ? body.mimeType : ''
  const byteSize = typeof body.byteSize === 'number' ? body.byteSize : 0
  const extension = ALLOWED_MIME_EXTENSIONS[mimeType]
  if (!extension || byteSize < 1 || byteSize > MAX_BYTES) {
    return jsonResponse({ error: 'Valid image or PDF metadata is required' }, 400)
  }

  const { data: profile } = await context.admin
    .from('profiles')
    .select('role')
    .eq('id', context.user.id)
    .single()
  if (profile?.role !== 'teacher') return jsonResponse({ error: 'Not authorized' }, 403)

  const path = `${crypto.randomUUID()}.${extension}`
  const { data, error } = await context.admin.storage
    .from('curriculum-assets')
    .createSignedUploadUrl(path)
  if (error) return jsonResponse({ error: 'Upload could not be prepared' }, 500)

  return jsonResponse({ path, token: data.token }, 201)
})
