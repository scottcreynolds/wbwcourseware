# Implementation Plan

Execute milestones one at a time. Each milestone must leave repository usable and tested.

| Milestone | Outcome |
| --- | --- |
| M0 | Repository, local services, CI, app shell |
| M1 | Auth, global roles, teacher bootstrap |
| M2 | Courses, modules, items, resources, outline import |
| M3 | Cohort snapshots, scheduling, course sync |
| M4 | Invitations, enrollment, student dashboard |
| M5 | Student curriculum navigation and PDF print views |
| M6 | Private PDF submissions and teacher review dashboard |
| M7 | Announcements and email delivery tracking |
| M8 | Discussion topics/replies and moderation |
| M9 | Security/accessibility hardening and deployment readiness |

## Sequencing rules

- Schema and RLS land with feature, not in one giant initial migration.
- Each vertical slice includes UI, database, permissions, tests, and error handling.
- Use fake/local email before production provider configuration.
- Do not deploy production during local-development milestones unless user authorizes it.
- Record material architecture changes in ADRs.

## Release gate

- All critical E2E flows pass.
- RLS negative tests pass.
- Production environment checklist complete.
- Teacher bootstrap and recovery documented.
- Backup/restore procedure tested.
- Real email/domain configuration verified in staging.

