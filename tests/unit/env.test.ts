import { describe, expect, it } from 'vitest'
import { readEnv } from '@/lib/env'

describe('readEnv', () => {
  it('validates required Supabase configuration', () => {
    expect(
      readEnv({
        VITE_SUPABASE_URL: 'http://127.0.0.1:55321',
        VITE_SUPABASE_ANON_KEY: 'local-anon-key',
      }),
    ).toMatchObject({ VITE_APP_NAME: 'Writers Be Writing' })
  })

  it('rejects an invalid URL', () => {
    expect(() =>
      readEnv({ VITE_SUPABASE_URL: 'not-a-url', VITE_SUPABASE_ANON_KEY: 'key' }),
    ).toThrow()
  })
})
