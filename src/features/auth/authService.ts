import type { AuthChangeEvent, Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import type { Profile } from '@/types/auth'

export type AuthService = {
  getSession: () => Promise<Session | null>
  getProfile: (userId: string) => Promise<Profile>
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  requestPasswordReset: (email: string, redirectTo: string) => Promise<void>
  updatePassword: (password: string) => Promise<void>
  onAuthStateChange: (listener: (event: AuthChangeEvent, session: Session | null) => void) => () => void
}

export const authService: AuthService = {
  async getSession() {
    const { data, error } = await supabase.auth.getSession()
    if (error) throw error
    return data.session
  },
  async getProfile(userId) {
    const { data, error } = await supabase.from('profiles').select('*').eq('id', userId).single()
    if (error) throw error
    return data as Profile
  },
  async signIn(email, password) {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
  },
  async signOut() {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
  },
  async requestPasswordReset(email, redirectTo) {
    const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo })
    if (error) throw error
  },
  async updatePassword(password) {
    const { error } = await supabase.auth.updateUser({ password })
    if (error) throw error
  },
  onAuthStateChange(listener) {
    const { data } = supabase.auth.onAuthStateChange(listener)
    return () => data.subscription.unsubscribe()
  },
}

