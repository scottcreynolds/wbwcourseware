import { describe, expect, it } from 'vitest'
import { canAccessRole, homeForRole } from '@/features/auth/authRules'

describe('auth rules', () => {
  it('keeps global roles isolated', () => {
    expect(canAccessRole('teacher', 'teacher')).toBe(true)
    expect(canAccessRole('teacher', 'student')).toBe(false)
    expect(canAccessRole('student', 'teacher')).toBe(false)
  })

  it('routes each role to its own dashboard', () => {
    expect(homeForRole('teacher')).toBe('/teacher')
    expect(homeForRole('student')).toBe('/student')
  })
})

