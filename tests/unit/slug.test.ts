import { describe, expect, it } from 'vitest'
import { slugify } from '@/features/courses/slug'

describe('slugify', () => {
  it('creates database-safe slugs', () => {
    expect(slugify('  Want & Need!  ')).toBe('want-need')
    expect(slugify('')).toBe('untitled')
  })
})

