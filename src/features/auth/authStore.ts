import type { Session } from '@supabase/supabase-js'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { authService } from '@/features/auth/authService'
import type { AuthStatus, Profile } from '@/types/auth'

export const useAuthStore = defineStore('auth', () => {
  const status = ref<AuthStatus>('loading')
  const session = ref<Session | null>(null)
  const profile = ref<Profile | null>(null)
  const error = ref<string | null>(null)
  let initialization: Promise<void> | null = null
  let unsubscribe: (() => void) | null = null

  const isAuthenticated = computed(() => status.value === 'authenticated' && profile.value !== null)

  async function loadIdentity(nextSession: Session | null): Promise<void> {
    session.value = nextSession
    profile.value = null
    error.value = null

    if (!nextSession) {
      status.value = 'anonymous'
      return
    }

    status.value = 'loading'
    try {
      profile.value = await authService.getProfile(nextSession.user.id)
      status.value = 'authenticated'
    } catch {
      status.value = 'error'
      error.value = 'Your account exists, but its application profile could not be loaded.'
    }
  }

  async function initialize(): Promise<void> {
    if (initialization) return initialization
    initialization = new Promise<void>((resolve, reject) => {
      let settled = false
      try {
        unsubscribe ??= authService.onAuthStateChange((_event, nextSession) => {
          void loadIdentity(nextSession).finally(() => {
            if (!settled) {
              settled = true
              resolve()
            }
          })
        })
      } catch (subscribeError) {
        reject(subscribeError)
      }
    }).catch(() => {
      status.value = 'error'
      error.value = 'Authentication could not be initialized.'
    })
    return initialization
  }

  async function signOut(): Promise<void> {
    await authService.signOut()
    await loadIdentity(null)
  }

  async function signIn(email: string, password: string): Promise<void> {
    await authService.signIn(email, password)
    await loadIdentity(await authService.getSession())
  }

  return { status, session, profile, error, isAuthenticated, initialize, signIn, signOut }
})
