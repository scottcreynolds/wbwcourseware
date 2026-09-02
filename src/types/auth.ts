import type { User } from '@supabase/supabase-js'

export type AppRole = 'teacher' | 'student'

export type Profile = {
  id: string
  email_normalized: string
  display_name: string | null
  role: AppRole
  created_at: string
  updated_at: string
}

export type AuthStatus = 'loading' | 'anonymous' | 'authenticated' | 'error'

export type AuthIdentity = {
  user: User
  profile: Profile
}

