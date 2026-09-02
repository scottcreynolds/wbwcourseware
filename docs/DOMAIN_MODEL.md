# Domain Model

## Core hierarchy

```text
Profile
Course
  Module
    ModuleItemPlacement -> CurriculumItem
  Cohort
    CohortModule
      CohortItemPlacement -> CohortCurriculumItem
    Invitation -> Enrollment -> Student Profile
    Submission -> SubmissionVersion -> SubmissionFile
    Announcement -> EmailDelivery
    DiscussionTopic -> DiscussionReply
```

## Identity and snapshot rules

- Course curriculum rows are templates.
- Cohort curriculum rows are snapshots with `source_*_id` links.
- Snapshot creation copies modules, items, placements, resources, and ordering atomically.
- A canonical item can have multiple placements. Content is not duplicated per placement.
- Applying a course edit targets one source item and selected cohorts.
- Sync overwrites shared content fields and resources.
- Sync preserves cohort-specific due date, release schedule, publication/visibility choices, submission data, and discussions.

## Aggregate rules

### Course

- Owned by teacher.
- May be draft or active.
- Cannot be accessed by students directly.

### Cohort

- Owned by same teacher.
- Has title, start/end dates, timezone, status.
- End date does not revoke access.

### Module visibility

Module is visible when published and either no release time exists or release time has passed. Manual release clears or overrides scheduled lock. Draft items remain hidden.

### Enrollment

States: `invited`, `active`, `removed`.

- Email is normalized before comparison.
- Active enrollment required for student access.
- Removed enrollment retains history.

### Submission

One logical submission per student/cohort-assignment, with one or more immutable versions. Each version contains one or more PDF file records. Late state is computed against cohort due date using server receipt timestamp.

## Invariants

- Every curriculum item has at least one module placement.
- Placements are unique per module/item pair.
- Ordering values are unique or transactionally normalized within parent.
- Assignment due date exists only on cohort assignment snapshot.
- Student cannot access course templates.
- Student can access submissions only within active enrolled cohort.
- Role cannot be changed by client.

