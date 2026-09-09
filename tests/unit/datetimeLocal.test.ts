import { describe, expect, it } from 'vitest'
import { datetimeLocalToIso, defaultDueDatetimeLocal, isoToDatetimeLocal } from '@/features/courses/datetimeLocal'

describe('isoToDatetimeLocal', () => {
  it('converts a server ISO timestamp with an offset into a datetime-local value', () => {
    const value = isoToDatetimeLocal('2026-12-15T19:30:00+00:00')
    expect(value).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/)
  })
  it('returns empty string for null', () => {
    expect(isoToDatetimeLocal(null)).toBe('')
  })
  it('returns empty string for an invalid value', () => {
    expect(isoToDatetimeLocal('not a date')).toBe('')
  })
})

describe('datetimeLocalToIso', () => {
  it('round-trips through isoToDatetimeLocal', () => {
    const original = '2026-12-15T19:30:00.000Z'
    const local = isoToDatetimeLocal(original)
    const iso = datetimeLocalToIso(local)
    expect(new Date(iso!).getTime()).toBe(new Date(original).getTime())
  })
  it('returns null for empty input', () => {
    expect(datetimeLocalToIso('')).toBeNull()
  })
})

describe('defaultDueDatetimeLocal', () => {
  it('defaults the time to 23:59', () => {
    expect(defaultDueDatetimeLocal()).toMatch(/T23:59$/)
  })
  it("uses today's date", () => {
    const today = new Date()
    const pad = (n: number) => String(n).padStart(2, '0')
    const expectedDate = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}`
    expect(defaultDueDatetimeLocal().startsWith(expectedDate)).toBe(true)
  })
})
