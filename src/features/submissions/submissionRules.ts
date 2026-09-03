export const MAX_SUBMISSION_BYTES = 25 * 1024 * 1024

export function validateSubmissionFile(file: Pick<File, 'name' | 'type' | 'size'>): string | null {
  if (!file.name.toLowerCase().endsWith('.pdf') || file.type !== 'application/pdf') {
    return 'Only PDF files are accepted.'
  }
  if (file.size < 1 || file.size > MAX_SUBMISSION_BYTES) {
    return 'Each PDF must be between 1 byte and 25 MB.'
  }
  return null
}
