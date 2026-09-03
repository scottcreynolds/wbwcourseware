import { supabase } from '@/lib/supabase'
import type { AssignmentSubmission } from '@/types/submission'

type UploadIntent = { path: string; token: string }

async function invoke<T>(name: string, body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke(name, { body })
  if (error) throw error
  return data as T
}

export const submissionService = {
  async list(itemId: string): Promise<AssignmentSubmission[]> {
    const { data, error } = await supabase.rpc('get_assignment_submissions', {
      target_item_id: itemId,
    })
    if (error) throw error
    return data as AssignmentSubmission[]
  },

  async submit(itemId: string, files: File[]): Promise<void> {
    const uploaded: { path: string; name: string }[] = []
    for (const file of files) {
      const intent = await invoke<UploadIntent>('submission-upload-intent', {
        itemId,
        fileName: file.name,
        mimeType: file.type,
        byteSize: file.size,
      })
      const { error } = await supabase.storage.from('submissions').uploadToSignedUrl(
        intent.path,
        intent.token,
        file,
        { contentType: 'application/pdf' },
      )
      if (error) throw error
      uploaded.push({ path: intent.path, name: file.name })
    }
    await invoke('finalize-submission', { itemId, files: uploaded })
  },

  async download(fileId: string): Promise<void> {
    const { url } = await invoke<{ url: string }>('submission-download', { fileId })
    window.location.assign(url)
  },
}
