// @vitest-environment node

import { describe, expect, test } from 'vitest'

const functionsUrl = process.env.FUNCTIONS_URL ?? 'http://127.0.0.1:55321/functions/v1'

async function invoke(name: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${functionsUrl}/${name}`, {
    ...init,
    signal: AbortSignal.timeout(5_000),
  })
}

describe('Edge Function HTTP boundaries', () => {
  test.each([
    'accept-invite',
    'bootstrap-teacher',
  ])('%s rejects unsupported methods', async (name) => {
    const response = await invoke(name)

    expect(response.status).toBe(405)
    await expect(response.json()).resolves.toEqual({ error: 'Method not allowed' })
  })

  test.each([
    'finalize-submission',
    'invite-student',
    'publish-announcement',
    'submission-download',
    'submission-upload-intent',
  ])('%s rejects unauthenticated requests at the gateway', async (name) => {
    const response = await invoke(name, { method: 'POST' })

    expect(response.status).toBe(401)
    expect(response.headers.get('content-type')).toContain('application/json')
  })

  test('bootstrap rejects an invalid secret', async () => {
    const response = await invoke('bootstrap-teacher', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-bootstrap-secret': 'incorrect' },
      body: JSON.stringify({ email: 'teacher@example.com' }),
    })

    expect(response.status).toBe(401)
    await expect(response.json()).resolves.toEqual({ error: 'Not authorized' })
  })

  test('accept-invite validates malformed input', async () => {
    const response = await invoke('accept-invite', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token: 'short' }),
    })

    expect(response.status).toBe(400)
    await expect(response.json()).resolves.toEqual({ error: 'Invitation is invalid or expired' })
  })
})
