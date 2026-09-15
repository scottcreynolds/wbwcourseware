import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { jsonResponse } from '../_shared/http.ts'
import { escapeHtml } from '../_shared/html.ts'
import { secretsMatch } from '../_shared/secretCompare.ts'

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

type NotificationRow = {
  id: string
  kind: 'discussion_topic' | 'submission'
  course_id: string
  teacher_id: string
  source_id: string
  attempt_count: number
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) return jsonResponse({ error: 'Server is not configured' }, 500)

  const providedAuth = (request.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (!(await secretsMatch(providedAuth, serviceRoleKey))) return jsonResponse({ error: 'Not authorized' }, 401)

  let body: Record<string, unknown>
  try { body = await request.json() } catch { return jsonResponse({ error: 'Invalid JSON' }, 400) }
  const notificationId = typeof body.notificationId === 'string' && uuidPattern.test(body.notificationId)
    ? body.notificationId : null
  if (!notificationId) return jsonResponse({ error: 'Notification is required' }, 400)

  const admin = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data: notification } = await admin
    .from('teacher_notifications')
    .select('id, kind, course_id, teacher_id, source_id, attempt_count')
    .eq('id', notificationId)
    .eq('status', 'pending')
    .maybeSingle<NotificationRow>()
  if (!notification) return jsonResponse({ error: 'Notification not found' }, 404)

  const [{ data: teacher }, { data: course }] = await Promise.all([
    admin.from('profiles').select('email_normalized').eq('id', notification.teacher_id).single(),
    admin.from('courses').select('title').eq('id', notification.course_id).single(),
  ])
  if (!teacher || !course) return jsonResponse({ error: 'Notification context missing' }, 404)

  const appOrigin = Deno.env.get('APP_ORIGIN') ?? ''
  const courseUrl = `${appOrigin}/teacher/courses/${notification.course_id}`
  let subject: string
  let html: string

  if (notification.kind === 'discussion_topic') {
    const { data: topic } = await admin
      .from('discussion_topics')
      .select('title, author_id')
      .eq('id', notification.source_id)
      .single()
    if (!topic) return jsonResponse({ error: 'Notification context missing' }, 404)
    const { data: author } = await admin.from('profiles').select('display_name').eq('id', topic.author_id).single()
    subject = `New discussion in ${course.title}: ${topic.title}`
    html = `<p><strong>${escapeHtml(author?.display_name ?? 'A student')}</strong> posted a new discussion topic in `
      + `<strong>${escapeHtml(course.title)}</strong>.</p><p><a href="${escapeHtml(courseUrl)}">View in ${escapeHtml(course.title)}</a></p>`
  } else {
    const { data: version } = await admin
      .from('submission_versions')
      .select('submission_id, submissions(student_id, course_item_id)')
      .eq('id', notification.source_id)
      .single<{ submission_id: string; submissions: { student_id: string; course_item_id: string } }>()
    if (!version) return jsonResponse({ error: 'Notification context missing' }, 404)
    const [{ data: student }, { data: item }] = await Promise.all([
      admin.from('profiles').select('display_name').eq('id', version.submissions.student_id).single(),
      admin.from('course_items').select('title').eq('id', version.submissions.course_item_id).single(),
    ])
    subject = `${student?.display_name ?? 'A student'} submitted ${item?.title ?? 'an assignment'}`
    html = `<p><strong>${escapeHtml(student?.display_name ?? 'A student')}</strong> submitted `
      + `<strong>${escapeHtml(item?.title ?? 'an assignment')}</strong> in <strong>${escapeHtml(course.title)}</strong>.</p>`
      + `<p><a href="${escapeHtml(courseUrl)}">View in ${escapeHtml(course.title)}</a></p>`
  }

  const resendKey = Deno.env.get('RESEND_API_KEY')
  const local = Deno.env.get('APP_ENV') === 'local'
  let status: 'sent' | 'failed' = 'failed'
  let providerMessageId: string | null = null
  let errorCode: string | null = 'email_not_configured'

  if (local && !resendKey) {
    status = 'sent'
    errorCode = null
    providerMessageId = `local-${notification.id}`
  } else if (resendKey) {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: Deno.env.get('EMAIL_FROM'), to: [teacher.email_normalized], subject, html }),
    })
    if (response.ok) {
      const result = await response.json()
      status = 'sent'
      errorCode = null
      providerMessageId = typeof result.id === 'string' ? result.id : null
    } else errorCode = `provider_${response.status}`
  }

  await admin.from('teacher_notifications').update({
    status,
    provider_message_id: providerMessageId,
    last_error_code: errorCode,
    attempt_count: notification.attempt_count + 1,
  }).eq('id', notification.id)

  return jsonResponse({ status })
})
