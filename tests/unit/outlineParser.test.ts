import { describe, expect, it } from 'vitest'
import { parseCourseOutline } from '@/features/courses/outlineParser'

describe('parseCourseOutline', () => {
  it('parses ordered modules and placeholders', () => {
    const result = parseCourseOutline(`# Module: Foundations
## Lecture: What a Scene Does
## Assignment: Scene Analysis
# Module: Character
## Lecture: Want and Need`)
    expect(result.errors).toEqual([])
    expect(result.modules).toEqual([
      {
        title: 'Foundations',
        items: [
          { kind: 'lecture', title: 'What a Scene Does' },
          { kind: 'assignment', title: 'Scene Analysis' },
        ],
      },
      { title: 'Character', items: [{ kind: 'lecture', title: 'Want and Need' }] },
    ])
  })

  it('rejects items before a module and unknown lines', () => {
    const result = parseCourseOutline('## Lecture: Lost\nordinary text')
    expect(result.errors).toHaveLength(2)
  })
})

