# Accessibility

Target WCAG 2.2 AA for core teacher and student flows.

## Requirements

- Semantic landmarks, headings, lists, tables, and form labels.
- Full keyboard operation including reorder controls; drag-and-drop requires buttons/alternative.
- Visible focus and logical focus movement.
- Errors tied to fields and summarized where useful.
- Status messages announced without stealing focus.
- Do not use color alone for draft, late, missing, released, or failed states.
- Dialogs have names, focus trap, escape behavior, and focus return.
- File uploader supports keyboard, clear constraints, progress, cancellation/error recovery.
- Markdown preview has accurate heading structure.
- Sanitizer preserves safe accessibility attributes and removes unsafe misuse.
- Discussion authorship, timestamps, edited/deleted state readable to assistive tech.
- Print/PDF layout keeps readable contrast and link destinations.

## Testing

- Automated axe checks on major routes.
- Keyboard pass for each critical E2E flow.
- Screen-reader spot checks for auth, module navigation, submission, announcement, and discussions.
- Zoom/reflow at 200% and 400% for primary pages.

