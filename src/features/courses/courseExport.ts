import { slugify } from '@/features/courses/slug'
import type { ZipEntry } from '@/lib/zip'
import type { CourseItem, CourseItemResource, CourseModule, CourseWorkspace } from '@/types/course'

export type CourseExportResource = Pick<CourseItemResource, 'item_id' | 'title' | 'url' | 'description' | 'position'>
export type CourseExportModuleNotes = { module_id: string; notes_markdown: string }

export type CourseExportSource = {
  workspace: CourseWorkspace
  resources: CourseExportResource[]
  moduleNotes: CourseExportModuleNotes[]
}

type FrontMatterValue = string | null | undefined

// JSON string literals are valid YAML scalars, so this quotes titles safely.
function frontMatter(fields: Record<string, FrontMatterValue>): string {
  const lines = Object.entries(fields)
    .filter((entry): entry is [string, string] => typeof entry[1] === 'string' && entry[1] !== '')
    .map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
  return ['---', ...lines, '---'].join('\n')
}

function document(...sections: Array<string | null>): string {
  return `${sections.filter((section): section is string => Boolean(section?.trim())).join('\n\n')}\n`
}

function numbered(index: number, total: number, name: string): string {
  const width = Math.max(2, String(total).length)
  return `${String(index + 1).padStart(width, '0')}-${name}`
}

function escapeLinkText(text: string): string {
  return text.replace(/([\\[\]])/g, '\\$1')
}

function resourcesSection(resources: CourseExportResource[]): string | null {
  if (resources.length === 0) return null
  const lines = resources.map((resource) => {
    const link = `[${escapeLinkText(resource.title)}](<${resource.url.replace(/[<>\s]/g, encodeURIComponent)}>)`
    const description = resource.description.trim()
    return description ? `- ${link} — ${description}` : `- ${link}`
  })
  return ['## Resources', ...lines].join('\n')
}

function itemDocument(item: CourseItem, resources: CourseExportResource[]): string {
  return document(
    frontMatter({
      title: item.title,
      kind: item.kind,
      status: item.publication_status,
      due_at: item.kind === 'assignment' ? item.due_at : null,
    }),
    `# ${item.title}`,
    item.body_markdown,
    resourcesSection(resources),
  )
}

function moduleDocument(module: CourseModule): string {
  return document(
    frontMatter({
      title: module.title,
      release_mode: module.release_mode,
      release_at: module.release_at,
      released_at: module.manually_released_at,
    }),
    `# ${module.title}`,
    module.description,
  )
}

function courseDocument(workspace: CourseWorkspace): string {
  const { course } = workspace
  return document(
    frontMatter({
      title: course.title,
      status: course.status,
      start_date: course.start_date,
      end_date: course.end_date,
      timezone: course.timezone,
    }),
    `# ${course.title}`,
    course.description,
    course.intro_markdown.trim() ? `## Intro\n\n${course.intro_markdown}` : null,
  )
}

function itemEntries(folder: string, items: CourseItem[], resourcesByItem: Map<string, CourseExportResource[]>): ZipEntry[] {
  return items.map((item, index) => ({
    path: `${folder}/${numbered(index, items.length, `${item.kind}-${slugify(item.title)}`)}.md`,
    content: itemDocument(item, resourcesByItem.get(item.id) ?? []),
  }))
}

/**
 * Lays a course out as Markdown files: one folder per module (in course order),
 * one file per item (in module order). An item linked into several modules is
 * written into each, so every folder reads as a complete module.
 */
export function buildCourseExport({ workspace, resources, moduleNotes }: CourseExportSource): ZipEntry[] {
  const root = slugify(workspace.course.title)
  const itemsById = new Map(workspace.items.map((item) => [item.id, item]))
  const notesByModule = new Map(moduleNotes.map((note) => [note.module_id, note.notes_markdown]))
  const resourcesByItem = new Map<string, CourseExportResource[]>()
  for (const resource of [...resources].sort((a, b) => a.position - b.position)) {
    resourcesByItem.set(resource.item_id, [...(resourcesByItem.get(resource.item_id) ?? []), resource])
  }

  const modules = [...workspace.modules].sort((a, b) => a.position - b.position)
  const entries: ZipEntry[] = [{ path: `${root}/README.md`, content: courseDocument(workspace) }]

  modules.forEach((module, moduleIndex) => {
    const folder = `${root}/${numbered(moduleIndex, modules.length, slugify(module.title))}`
    const items = workspace.placements
      .filter((placement) => placement.module_id === module.id)
      .sort((a, b) => a.position - b.position)
      .map((placement) => itemsById.get(placement.item_id))
      .filter((item): item is CourseItem => item !== undefined)
    const notes = notesByModule.get(module.id)?.trim()

    entries.push({ path: `${folder}/README.md`, content: moduleDocument(module) })
    if (notes) {
      entries.push({
        path: `${folder}/teaching-notes.md`,
        content: document(`# ${module.title} — Teaching notes`, '_Instructor only._', notes),
      })
    }
    entries.push(...itemEntries(folder, items, resourcesByItem))
  })

  const placedItemIds = new Set(workspace.placements.map((placement) => placement.item_id))
  const unplacedItems = workspace.items
    .filter((item) => !placedItemIds.has(item.id))
    .sort((a, b) => a.title.localeCompare(b.title))
  entries.push(...itemEntries(`${root}/unplaced`, unplacedItems, resourcesByItem))

  return entries
}

export function courseExportFileName(courseTitle: string): string {
  return `${slugify(courseTitle)}.zip`
}
