# Content Model

## Curriculum item

Shared fields:

- `id`
- `kind`: `lecture | assignment`
- `title`
- `slug`
- `body_markdown`
- `publication_status`: `draft | published`
- `source_item_id` on cohort snapshots
- timestamps

Assignment-only cohort fields:

- `due_at`

## Resources

Resource fields:

- title
- URL
- optional description
- position

Resources are data rows, not Markdown parsing artifacts. Reordering resources does not rewrite body.

## Multiple modules

Use placement join tables. Do not copy item content merely to display it in a review module. Each placement owns only module ID, item ID, and position.

## Markdown and HTML

- Preserve author source exactly in `body_markdown`.
- Render on client through one shared renderer.
- Allow broad formatting HTML, classes, inline styles, images, tables, and allowlisted video iframes.
- Remove scripts, event handlers, forms, active embeds, dangerous protocols, and unapproved iframe hosts.
- Initial iframe allowlist: YouTube and Vimeo; configure centrally.
- External links use safe `rel` values.
- Renderer output never becomes trusted because author is teacher.

## Outline import

Recommended syntax:

```markdown
# Module: Foundations
## Lecture: What a Scene Does
## Assignment: Scene Analysis

# Module: Character
## Lecture: Want and Need
## Assignment: Character Map
```

Parser produces preview model. Teacher may reorder, rename, change item type, remove rows, then confirm. Import is atomic and rejects malformed or empty outlines without partial creation.

## Markdown file import

- Accept UTF-8 `.md` only.
- File name may seed title but never silently overwrite existing title.
- Show preview before saving.
- Set size limit appropriate to text content.

