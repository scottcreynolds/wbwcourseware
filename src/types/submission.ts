export type SubmissionFile = { id: string; name: string; byteSize: number }
export type SubmissionVersion = {
  id: string
  versionNumber: number
  submittedAt: string
  isLate: boolean
  files: SubmissionFile[]
}
export type AssignmentSubmission = {
  id: string
  studentId: string
  studentName: string
  versions: SubmissionVersion[]
}
