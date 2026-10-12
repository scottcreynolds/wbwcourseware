export type SubmissionReviewGroupKey = 'recent' | 'upcoming' | 'earlier' | 'undated'

export type SubmissionReviewGroup<T> = {
  key: SubmissionReviewGroupKey
  label: string
  items: T[]
}

type DatedItem = { title: string; due_at: string | null }

const groupLabels: Record<SubmissionReviewGroupKey, string> = {
  recent: 'Most recently due',
  upcoming: 'Upcoming',
  earlier: 'Earlier',
  undated: 'No due date',
}

function calendarDayIn(timestamp: number, timezone: string): string {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(timestamp)
  } catch {
    return new Date(timestamp).toISOString().slice(0, 10)
  }
}

/**
 * Orders assignments so the set a teacher most likely needs to review comes first:
 * every assignment due on the cohort-local day of the latest past due date, then
 * upcoming work (soonest first), then older past-due work (newest first), then undated.
 */
export function groupAssignmentsForReview<T extends DatedItem>(items: T[], now: Date, timezone: string): SubmissionReviewGroup<T>[] {
  const nowMs = now.getTime()
  const dated: { item: T; dueMs: number }[] = []
  const undated: T[] = []
  for (const item of items) {
    const dueMs = item.due_at ? Date.parse(item.due_at) : Number.NaN
    if (Number.isNaN(dueMs)) undated.push(item)
    else dated.push({ item, dueMs })
  }

  const byTitle = (a: T, b: T) => a.title.localeCompare(b.title)
  const upcoming = dated.filter((entry) => entry.dueMs > nowMs).sort((a, b) => a.dueMs - b.dueMs || byTitle(a.item, b.item))
  const pastDue = dated.filter((entry) => entry.dueMs <= nowMs).sort((a, b) => b.dueMs - a.dueMs || byTitle(a.item, b.item))

  const latestPastDue = pastDue[0]
  const recentDay = latestPastDue ? calendarDayIn(latestPastDue.dueMs, timezone) : null
  const recent = pastDue.filter((entry) => calendarDayIn(entry.dueMs, timezone) === recentDay)
  const earlier = pastDue.filter((entry) => calendarDayIn(entry.dueMs, timezone) !== recentDay)

  const groups: SubmissionReviewGroup<T>[] = [
    { key: 'recent', label: groupLabels.recent, items: recent.map((entry) => entry.item) },
    { key: 'upcoming', label: groupLabels.upcoming, items: upcoming.map((entry) => entry.item) },
    { key: 'earlier', label: groupLabels.earlier, items: earlier.map((entry) => entry.item) },
    { key: 'undated', label: groupLabels.undated, items: [...undated].sort(byTitle) },
  ]
  return groups.filter((group) => group.items.length > 0)
}
