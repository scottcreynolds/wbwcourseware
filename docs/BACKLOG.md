# Backlog

## MVP

- Course/curriculum authoring and outline scaffolding
- Cohort snapshots and controlled sync
- Module release rules
- Invite-only auth/enrollment
- Student dashboard and curriculum reading
- PDF submissions/version history/peer access
- Teacher submission overview
- Draft/publish-now announcements and email
- One-level cohort discussions
- Page print/PDF export

## Fast follow

- Uploaded images/GIFs in curriculum
- Malware scanning for submissions
- Teacher private feedback and uploaded notes
- Announcement scheduling
- Notification preferences/digests
- Submission download bundle
- Course duplication/import/export
- Better content diff before cohort sync
- Discussion locking/pinning
- Storage usage dashboard

## Later

- Multiple instructors/teaching assistants
- Grades/rubrics/inline annotations
- Progress/completion tracking
- Calendar integrations
- Native mobile apps
- Video hosting
- Student direct messaging
- Rich editor

## Known issues / tech debt

- Student cohort page mounts `AnnouncementList` twice (standalone
  most-recent card + full list in the Announcements tab), each with
  its own 60s poll — duplicate queries against the same table while
  a student is on the page. Harmless but wasteful; consolidate to a
  shared fetch/cache if it becomes a real cost.

## Explicitly avoid until justified

- Generic LMS standards
- Microservices
- Event-sourcing framework
- Complex workflow engine
- Search infrastructure beyond database needs
- AI-generated student writing

