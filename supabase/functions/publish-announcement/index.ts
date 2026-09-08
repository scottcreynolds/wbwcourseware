import { corsHeaders } from '../_shared/cors.ts'
import { requireFunctionContext } from '../_shared/auth.ts'
import { jsonResponse } from '../_shared/http.ts'

type Delivery = {
  delivery_id: string
  recipient: string
  announcement_title: string
  announcement_body: string
  course_title: string
  attempts: number
}
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const escapeHtml = (value: string) => value.replace(/[&<>"']/g, (character) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[character] ?? character))

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405)
  const context = await requireFunctionContext(request)
  if (!context) return jsonResponse({ error: 'Authentication required' }, 401)
  let body: Record<string, unknown>
  try { body = await request.json() } catch { return jsonResponse({ error: 'Invalid JSON' }, 400) }
  const announcementId = typeof body.announcementId === 'string' && uuidPattern.test(body.announcementId)
    ? body.announcementId : null
  if (!announcementId) return jsonResponse({ error: 'Announcement is required' }, 400)
  const { data: profile } = await context.admin.from('profiles').select('role').eq('id', context.user.id).single()
  if (profile?.role !== 'teacher') return jsonResponse({ error: 'Not authorized' }, 403)
  const { data, error } = await context.admin.rpc('prepare_announcement_publication', {
    target_announcement_id: announcementId,
    target_teacher_id: context.user.id,
  })
  if (error) return jsonResponse({ error: 'Announcement could not be published' }, 403)
  const deliveries = (data ?? []) as Delivery[]
  const resendKey = Deno.env.get('RESEND_API_KEY')
  const local = Deno.env.get('APP_ENV') === 'local'
  let sent = 0
  let failed = 0
  for (const delivery of deliveries) {
    let status: 'sent' | 'failed' = 'failed'
    let providerMessageId: string | null = null
    let errorCode: string | null = 'email_not_configured'
    if (local && !resendKey) {
      status = 'sent'
      errorCode = null
      providerMessageId = `local-${delivery.delivery_id}`
    } else if (resendKey) {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: Deno.env.get('EMAIL_FROM'),
          to: [delivery.recipient],
          subject: `${delivery.course_title}: ${delivery.announcement_title}`,
          html: `<h1>${escapeHtml(delivery.announcement_title)}</h1><p>${escapeHtml(delivery.announcement_body).replaceAll('\n', '<br>')}</p>`,
        }),
      })
      if (response.ok) {
        const result = await response.json()
        status = 'sent'
        errorCode = null
        providerMessageId = typeof result.id === 'string' ? result.id : null
      } else errorCode = `provider_${response.status}`
    }
    await context.admin.from('announcement_deliveries').update({
      status,
      provider_message_id: providerMessageId,
      last_error_code: errorCode,
      attempt_count: delivery.attempts + 1,
    }).eq('id', delivery.delivery_id)
    if (status === 'sent') sent++
    else failed++
  }
  return jsonResponse({ status: 'published', sent, failed })
})
