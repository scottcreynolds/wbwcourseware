function formatDatetimeLocal(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

export function isoToDatetimeLocal(value: string | null): string {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  return formatDatetimeLocal(date)
}

export function defaultDueDatetimeLocal(): string {
  const date = new Date()
  date.setHours(23, 59, 0, 0)
  return formatDatetimeLocal(date)
}

export function datetimeLocalToIso(value: string): string | null {
  return value ? new Date(value).toISOString() : null
}
