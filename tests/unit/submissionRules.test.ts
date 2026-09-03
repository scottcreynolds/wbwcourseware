import { describe, expect, it } from 'vitest'
import { MAX_SUBMISSION_BYTES, validateSubmissionFile } from '@/features/submissions/submissionRules'

describe('submission file validation', () => {
  it('accepts PDFs within the limit', () => {
    expect(validateSubmissionFile({ name: 'draft.pdf', type: 'application/pdf', size: 100 })).toBeNull()
  })

  it('rejects wrong types and oversized files', () => {
    expect(validateSubmissionFile({ name: 'draft.docx', type: 'application/pdf', size: 100 })).toMatch(/PDF/)
    expect(validateSubmissionFile({ name: 'draft.pdf', type: 'application/pdf', size: MAX_SUBMISSION_BYTES + 1 })).toMatch(/25 MB/)
  })
})
