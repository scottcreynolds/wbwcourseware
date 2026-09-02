export type InvitationStatus='pending'|'accepted'|'revoked'|'expired'
export type CohortInvitation={id:string;cohort_id:string;email_normalized:string;status:InvitationStatus;expires_at:string;created_at:string}
export type EnrollmentStatus='active'|'removed'
export type CohortEnrollment={id:string;cohort_id:string;student_id:string;status:EnrollmentStatus;activated_at:string;removed_at:string|null;profiles:{display_name:string|null;email_normalized:string}|null}

