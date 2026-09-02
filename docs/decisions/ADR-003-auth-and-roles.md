# ADR-003: Invite-Only Auth and Global Roles

Status: Accepted

Accounts have one immutable global role: teacher or student. Bootstrap one teacher. Teachers invite students only. A verified signup using invited email activates cohort enrollment automatically through trusted server/database logic.

Rationale: Small single-teacher product does not need staff-role complexity. Database enforcement prevents role escalation and uninvited access.

