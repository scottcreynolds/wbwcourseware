export type InvitationStatus='pending'|'accepted'|'revoked'|'expired'
export type CourseInvitation={id:string;course_id:string;email_normalized:string;status:InvitationStatus;expires_at:string;created_at:string}
export type EnrollmentStatus='active'|'removed'
export type CourseEnrollment={id:string;course_id:string;student_id:string;status:EnrollmentStatus;activated_at:string;removed_at:string|null;profiles:{display_name:string|null;email_normalized:string}|null}
