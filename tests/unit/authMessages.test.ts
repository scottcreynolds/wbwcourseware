import { describe, expect, it } from 'vitest'
import { toAuthMessage } from '@/features/auth/authMessages'

describe('auth messages', () => {
  it('gives useful messages for known safe cases', () => {
    expect(toAuthMessage(new Error('Invalid login credentials'))).toBe('Email or password is incorrect.')
    expect(toAuthMessage(new Error('Email not confirmed'))).toBe('Confirm your email before signing in.')
  })

  it('does not leak unknown backend errors', () => {
    expect(toAuthMessage(new Error('database connection contained internal details'))).toBe(
      'We could not complete that request. Check your information and try again.',
    )
  })
})

