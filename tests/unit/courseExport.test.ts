import { describe, expect, it } from 'vitest'
import { buildCourseExport, courseExportFileName } from '@/features/courses/courseExport'
import type { CourseItem, CourseModule, CourseWorkspace } from '@/types/course'

const timestamps = { created_at: '2026-09-01T00:00:00Z', updated_at: '2026-09-01T00:00:00Z' }

function module(id: string, title: string, position: number): CourseModule {
  return { id, course_id: 'c1', title, description: '', position, release_mode: 'manual', release_at: null, manually_released_at: null, ...timestamps }
}

function item(id: string, kind: CourseItem['kind'], title: string, extra: Partial<CourseItem> = {}): CourseItem {
  return { id, course_id: 'c1', kind, title, slug: id, body_markdown: `Body of ${title}`, publication_status: 'published', due_at: null, ...timestamps, ...extra }
}

const workspace: CourseWorkspace = {
  course: { id: 'c1', teacher_id: 't1', title: 'Fiction: Year One', description: 'A course.', status: 'active', branding_json: {}, start_date: '2026-09-01', end_date: '2026-12-01', timezone: 'America/New_York', intro_markdown: 'Welcome!', ...timestamps },
  modules: [module('m2', 'Character', 2), module('m1', 'Foundations', 1)],
  items: [
    item('i1', 'lecture', 'What a Scene Does'),
    item('i2', 'assignment', 'Scene "Analysis"', { due_at: '2026-09-15T04:00:00Z', publication_status: 'draft' }),
    item('i3', 'lecture', 'Shared Review'),
    item('i4', 'lecture', 'Orphan'),
  ],
  placements: [
    { module_id: 'm1', item_id: 'i2', position: 2, created_at: '' },
    { module_id: 'm1', item_id: 'i1', position: 1, created_at: '' },
    { module_id: 'm1', item_id: 'i3', position: 3, created_at: '' },
    { module_id: 'm2', item_id: 'i3', position: 1, created_at: '' },
  ],
}

const entries = buildCourseExport({
  workspace,
  resources: [
    { item_id: 'i1', title: 'Second [link]', url: 'https://example.com/b', description: '', position: 2 },
    { item_id: 'i1', title: 'First', url: 'https://example.com/a (x)', description: 'Read first', position: 1 },
  ],
  moduleNotes: [{ module_id: 'm1', notes_markdown: 'Start with a warmup.' }, { module_id: 'm2', notes_markdown: '  ' }],
})
const byPath = new Map(entries.map((entry) => [entry.path, entry.content]))

describe('buildCourseExport', () => {
  it('organizes modules and items into ordered, named folders and files', () => {
    expect(entries.map((entry) => entry.path)).toEqual([
      'fiction-year-one/README.md',
      'fiction-year-one/01-foundations/README.md',
      'fiction-year-one/01-foundations/teaching-notes.md',
      'fiction-year-one/01-foundations/01-lecture-what-a-scene-does.md',
      'fiction-year-one/01-foundations/02-assignment-scene-analysis.md',
      'fiction-year-one/01-foundations/03-lecture-shared-review.md',
      'fiction-year-one/02-character/README.md',
      'fiction-year-one/02-character/01-lecture-shared-review.md',
      'fiction-year-one/unplaced/01-lecture-orphan.md',
    ])
  })

  it('writes course metadata, description, and intro', () => {
    expect(byPath.get('fiction-year-one/README.md')).toBe(
      '---\ntitle: "Fiction: Year One"\nstatus: "active"\nstart_date: "2026-09-01"\nend_date: "2026-12-01"\ntimezone: "America/New_York"\n---\n\n# Fiction: Year One\n\nA course.\n\n## Intro\n\nWelcome!\n',
    )
  })

  it('writes item body with quoted front matter, due date, and ordered resources', () => {
    expect(byPath.get('fiction-year-one/01-foundations/02-assignment-scene-analysis.md')).toBe(
      '---\ntitle: "Scene \\"Analysis\\""\nkind: "assignment"\nstatus: "draft"\ndue_at: "2026-09-15T04:00:00Z"\n---\n\n# Scene "Analysis"\n\nBody of Scene "Analysis"\n',
    )
    expect(byPath.get('fiction-year-one/01-foundations/01-lecture-what-a-scene-does.md')).toContain(
      '## Resources\n- [First](<https://example.com/a%20(x)>) — Read first\n- [Second \\[link\\]](<https://example.com/b>)\n',
    )
  })

  it('includes teaching notes only when non-empty', () => {
    expect(byPath.get('fiction-year-one/01-foundations/teaching-notes.md')).toContain('Start with a warmup.')
    expect(byPath.has('fiction-year-one/02-character/teaching-notes.md')).toBe(false)
  })
})

describe('courseExportFileName', () => {
  it('slugifies the course title', () => {
    expect(courseExportFileName('Fiction: Year One')).toBe('fiction-year-one.zip')
  })
})
