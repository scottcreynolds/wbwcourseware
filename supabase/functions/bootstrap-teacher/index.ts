import { createClient } from 'npm:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { jsonResponse } from '../_shared/http.ts'

type BootstrapRequest = {
  email?: unknown
  displayName?: unknown
  redirectTo?: unknown
}

function normalizeEmail(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const email = value.trim().toLowerCase()
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null
}

async function secretsMatch(provided: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder()
  const [providedHash, expectedHash] = await Promise.all([
    crypto.subtle.digest('SHA-256', encoder.encode(provided)),
    crypto.subtle.digest('SHA-256', encoder.encode(expected)),
  ])
  const a = new Uint8Array(providedHash)
  const b = new Uint8Array(expectedHash)
  return a.length === b.length && a.every((value, index) => value === b[index])
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405)

  const expectedSecret = Deno.env.get('BOOTSTRAP_TEACHER_SECRET') ?? ''
  const providedSecret = request.headers.get('x-bootstrap-secret') ?? ''

  if (!expectedSecret || !(await secretsMatch(providedSecret, expectedSecret))) {
    return jsonResponse({ error: 'Not authorized' }, 401)
  }

  let body: BootstrapRequest
  try {
    body = (await request.json()) as BootstrapRequest
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400)
  }

  const email = normalizeEmail(body.email)
  if (!email) return jsonResponse({ error: 'Valid email is required' }, 400)

  const displayName = typeof body.displayName === 'string' ? body.displayName.trim() || null : null
  const redirectTo = typeof body.redirectTo === 'string' ? body.redirectTo : undefined
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) return jsonResponse({ error: 'Server is not configured' }, 500)

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: existingTeacher, error: teacherLookupError } = await admin
    .from('profiles')
    .select('id,email_normalized')
    .eq('role', 'teacher')
    .maybeSingle()

  if (teacherLookupError) return jsonResponse({ error: 'Bootstrap lookup failed' }, 500)
  if (existingTeacher) {
    if (existingTeacher.email_normalized === email) {
      return jsonResponse({ status: 'already_bootstrapped', userId: existingTeacher.id })
    }
    return jsonResponse({ error: 'Teacher account already exists' }, 409)
  }

  const { data: existingProfile, error: profileLookupError } = await admin
    .from('profiles')
    .select('id')
    .eq('email_normalized', email)
    .maybeSingle()

  if (profileLookupError) return jsonResponse({ error: 'Bootstrap lookup failed' }, 500)

  let userId = existingProfile?.id
  if (!userId) {
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
      data: displayName ? { display_name: displayName } : {},
      redirectTo,
    })
    if (error || !data.user) return jsonResponse({ error: 'Could not create teacher invitation' }, 500)
    userId = data.user.id
  }

  const { error: updateError } = await admin
    .from('profiles')
    .update({ role: 'teacher', display_name: displayName })
    .eq('id', userId)

  if (updateError) return jsonResponse({ error: 'Could not assign teacher role' }, 500)
  return jsonResponse({ status: 'bootstrapped', userId }, 201)
})

