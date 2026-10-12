import { describe, expect, it } from 'vitest'
import { groupAssignmentsForReview } from '@/features/submissions/submissionReviewGroups'

const now = new Date('2026-10-12T16:00:00Z')
const timezone = 'America/New_York'

function shape(items: { title: string; due_at: string | null }[]) {
  return groupAssignmentsForReview(items, now, timezone).map((group) => [group.key, group.items.map((item) => item.title)])
}

describe('submission review grouping', () => {
  it('puts the latest due day first, then upcoming soonest-first, then older past-due newest-first, then undated', () => {
    expect(
      shape([
        { title: 'Old', due_at: '2026-09-01T03:59:00Z' },
        { title: 'Undated B', due_at: null },
        { title: 'Next week', due_at: '2026-10-19T03:59:00Z' },
        { title: 'Last week', due_at: '2026-10-05T03:59:00Z' },
        { title: 'Tomorrow', due_at: '2026-10-13T03:59:00Z' },
        { title: 'Yesterday', due_at: '2026-10-11T03:59:00Z' },
        { title: 'Undated A', due_at: null },
      ]),
    ).toEqual([
      ['recent', ['Yesterday']],
      ['upcoming', ['Tomorrow', 'Next week']],
      ['earlier', ['Last week', 'Old']],
      ['undated', ['Undated A', 'Undated B']],
    ])
  })

  it('treats assignments due on the same cohort-local day as one recent set', () => {
    // 2026-10-11 09:00 and 23:59 New York are the same local day; 2026-10-11T03:59Z is Oct 10 locally.
    expect(
      shape([
        { title: 'Morning', due_at: '2026-10-11T13:00:00Z' },
        { title: 'Midnight', due_at: '2026-10-12T03:59:00Z' },
        { title: 'Prior local day', due_at: '2026-10-11T03:59:00Z' },
      ]),
    ).toEqual([
      ['recent', ['Midnight', 'Morning']],
      ['earlier', ['Prior local day']],
    ])
  })

  it('omits empty groups and treats unparseable or invalid-timezone input safely', () => {
    expect(shape([{ title: 'Future', due_at: '2026-11-01T00:00:00Z' }])).toEqual([['upcoming', ['Future']]])
    expect(shape([{ title: 'Garbage', due_at: 'not a date' }])).toEqual([['undated', ['Garbage']]])
    expect(groupAssignmentsForReview([{ title: 'Past', due_at: '2026-10-01T00:00:00Z' }], now, 'Not/AZone')[0]?.key).toBe('recent')
    expect(shape([])).toEqual([])
  })
})
