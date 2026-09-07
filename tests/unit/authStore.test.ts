import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const { getSession, getProfile, onAuthStateChange } = vi.hoisted(() => ({
  getSession: vi.fn(),
  getProfile: vi.fn(),
  onAuthStateChange: vi.fn(),
}))

vi.mock('@/features/auth/authService', () => ({
  authService: {
    getSession,
    getProfile,
    signIn: vi.fn(),
    signOut: vi.fn(),
    requestPasswordReset: vi.fn(),
    updatePassword: vi.fn(),
    onAuthStateChange,
  },
}))

describe('authStore initialize', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.resetAllMocks()
  })

  it('waits for the first auth state change instead of a possibly-premature getSession result', async () => {
    // getSession() itself is never called by initialize() any more -- if a
    // restored session hasn't finished loading from storage yet, calling it
    // directly on cold load can race and return null before the real
    // session is detected, which previously sent an already-logged-in user
    // to the login screen on every page refresh.
    getSession.mockResolvedValue(null)
    getProfile.mockResolvedValue({ id: 'user-1', role: 'teacher', display_name: 'T', email_normalized: 't@example.com' })

    let emit: (event: string, session: unknown) => void = () => {}
    onAuthStateChange.mockImplementation((listener: (event: string, session: unknown) => void) => {
      emit = listener
      return { data: { subscription: { unsubscribe: vi.fn() } } }
    })

    const { useAuthStore } = await import('@/features/auth/authStore')
    const auth = useAuthStore()

    const initializePromise = auth.initialize()
    expect(auth.status).toBe('loading')

    emit('INITIAL_SESSION', { user: { id: 'user-1' } })
    await initializePromise

    expect(getSession).not.toHaveBeenCalled()
    expect(auth.isAuthenticated).toBe(true)
    expect(auth.profile?.role).toBe('teacher')
  })

  it('resolves to anonymous when the restored session is genuinely absent', async () => {
    onAuthStateChange.mockImplementation((listener: (event: string, session: unknown) => void) => {
      queueMicrotask(() => listener('INITIAL_SESSION', null))
      return { data: { subscription: { unsubscribe: vi.fn() } } }
    })

    const { useAuthStore } = await import('@/features/auth/authStore')
    const auth = useAuthStore()

    await auth.initialize()

    expect(auth.status).toBe('anonymous')
    expect(auth.isAuthenticated).toBe(false)
  })
})
