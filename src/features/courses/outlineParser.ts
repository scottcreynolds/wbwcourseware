import type { CurriculumItemKind } from '@/types/course'

export type OutlineItem = { title: string; kind: CurriculumItemKind }
export type OutlineModule = { title: string; items: OutlineItem[] }
export type OutlineResult = { modules: OutlineModule[]; errors: string[] }

const modulePattern = /^#\s+Module:\s*(.+)$/i
const itemPattern = /^##\s+(Lecture|Assignment):\s*(.+)$/i

export function parseCourseOutline(source: string): OutlineResult {
  const modules: OutlineModule[] = []
  const errors: string[] = []
  let currentModule: OutlineModule | null = null

  source.split(/\r?\n/).forEach((rawLine, index) => {
    const line = rawLine.trim()
    if (!line) return

    const moduleMatch = modulePattern.exec(line)
    if (moduleMatch) {
      const title = moduleMatch[1]?.trim() ?? ''
      if (!title) errors.push(`Line ${index + 1}: module title is required.`)
      else {
        currentModule = { title, items: [] }
        modules.push(currentModule)
      }
      return
    }

    const itemMatch = itemPattern.exec(line)
    if (itemMatch) {
      if (!currentModule) {
        errors.push(`Line ${index + 1}: item must follow a module.`)
        return
      }
      const title = itemMatch[2]?.trim() ?? ''
      if (!title) errors.push(`Line ${index + 1}: item title is required.`)
      else {
        currentModule.items.push({
          kind: itemMatch[1]?.toLowerCase() as CurriculumItemKind,
          title,
        })
      }
      return
    }

    errors.push(`Line ${index + 1}: use “# Module:” or “## Lecture/Assignment:”.`)
  })

  if (modules.length === 0 && errors.length === 0) errors.push('Add at least one module.')
  return { modules, errors }
}

