import { createClient, type SupabaseClient, type User } from 'npm:@supabase/supabase-js@2'

export type FunctionContext = { user: User; caller: SupabaseClient; admin: SupabaseClient }

export async function requireFunctionContext(request: Request): Promise<FunctionContext | null> {
  const url = Deno.env.get('SUPABASE_URL')
  const anon = Deno.env.get('SUPABASE_ANON_KEY')
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !anon || !service) return null
  const authorization = request.headers.get('authorization') ?? ''
  const caller = createClient(url, anon, { global: { headers: { Authorization: authorization } } })
  const { data: { user } } = await caller.auth.getUser()
  if (!user) return null
  return {
    user,
    caller,
    admin: createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } }),
  }
}
