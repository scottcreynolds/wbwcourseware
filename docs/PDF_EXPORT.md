# Page PDF Export

## MVP approach

Use dedicated printable route/layout plus browser print dialog. Avoid server PDF generation until needed.

## Output

- Course branding/header
- Course and cohort name when relevant
- Page type and title
- Rendered sanitized content
- Ordered resource list with visible URLs
- Assignment due date for cohort exports
- Print-friendly typography, margins, and page breaks

## Rules

- Hide navigation, controls, discussion, and submission UI.
- Avoid splitting headings from following content.
- Render backgrounds only when meaningful.
- External images may fail due to remote host/CORS; show useful fallback.
- PDF export uses same content renderer and sanitization as page view.
- Add Playwright visual/smoke coverage for representative long page, table, image, iframe fallback, and resources.

## Fast-follow trigger

Adopt server-generated PDF only if automated download, consistent pagination, or remote media reliability becomes required.

