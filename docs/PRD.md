# Product Requirements

## Goal

Replace Google Classroom/Canvas for small workshop-style writing cohorts with simpler navigation and administration.

## Users

### Teacher

One bootstrapped global teacher account. Creates and manages courses, cohorts, curriculum, invitations, announcements, submissions, and discussions.

### Student

Invite-only global student account. Sees only cohorts tied to accepted, active enrollments.

Accounts have one global role and cannot be both teacher and student.

## MVP

### Courses and cohorts

- One course has many cohorts.
- Course is reusable curriculum source.
- New cohort receives curriculum snapshot.
- Teacher may apply a course item change to selected cohorts, overwriting matching content while preserving cohort scheduling and visibility overrides.
- One teacher owns each course and cohort.

### Modules

- Ordered within course and cohort.
- Teacher can reorder modules.
- Each module is manually released or scheduled for release.
- Draft items remain hidden even when module is visible.
- Students retain access after cohort end unless removed.

### Curriculum items

- Types: lecture and assignment.
- Every item belongs to at least one module.
- Same canonical item may appear in multiple modules without duplication.
- Item has ordered placement within each module.
- Body stored as Markdown with broad sanitized HTML.
- Teacher edits in textarea with rendered preview below.
- Teacher may import `.md` body.
- Ordered resources contain title and URL.
- Remote Markdown images supported; uploads are later work.
- Item states: draft and published.

### Course scaffolding

- Single-page outline import creates ordered modules and titled lecture/assignment placeholders.
- Teacher can edit titles/types before confirming import.
- Import does not require page bodies, dates, or resources.

### Assignments and submissions

- Due dates set separately per cohort assignment.
- Students upload one or more PDFs, maximum 25 MB each.
- Resubmission creates another immutable, visible version.
- Late submissions allowed and labeled.
- Submitted versions become readable immediately by all active students in cohort.
- No in-platform teacher feedback in MVP.
- Teacher dashboard lists submission state by assignment/student.

### Enrollment

- Teacher invites email to cohort.
- Signup using invited email activates enrollment automatically.
- Teacher can revoke pending invite or remove active student.
- Removal ends access but retains records.
- Student dashboard lists active accessible cohorts only.

### Announcements

- Belong to cohort.
- Draft or publish now.
- Publishing displays announcement and triggers email to active students.
- Email delivery status is recorded; page publication does not roll back because one email fails.

### Discussions

- Cohort topics with one-level replies.
- Active students and teacher can post.
- Authors edit/delete own content.
- Teacher moderates all content.
- Deleted content remains as moderation/audit record but is hidden from ordinary views.

### PDF export

- Lecture and assignment pages have printable/downloadable PDF view.
- Includes course branding/header, title, rendered body, and ordered resources.

## Explicit non-goals for MVP

- Payments and registration sales flow
- Grades, rubrics, teacher feedback, inline annotations
- Progress tracking beyond submissions
- Nested discussion replies
- Student direct messages or group chat
- Calendar integrations
- SCORM/LTI integrations
- Native video hosting
- Mobile apps
- Multiple teachers or teaching assistants
- Student-selected submission privacy

## Success criteria

- Teacher can scaffold, publish, and reuse a course without repetitive page creation.
- Invited student can sign up and reach only invited cohort.
- Student can read material, submit PDFs, and read cohort work.
- Teacher can see missing/on-time/late submissions at a glance.
- Access control holds under direct API requests.

