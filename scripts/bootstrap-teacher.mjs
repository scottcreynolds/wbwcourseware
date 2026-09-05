/* global fetch, console */

import { readFile } from 'node:fs/promises'
import { createInterface } from 'node:readline/promises'
import process, { stdin as input, stdout as output } from 'node:process'

const defaultLocalFunctionUrl = 'http://127.0.0.1:55321/functions/v1/bootstrap-teacher'
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

async function readEnvFile(path) {
  try {
    const source = await readFile(path, 'utf8')
    return Object.fromEntries(source.split(/\r?\n/).flatMap((line) => {
      const match = line.match(/^\s*([A-Z][A-Z0-9_]*)\s*=\s*(.*)\s*$/)
      if (!match) return []
      const value = match[2].replace(/^(['"])(.*)\1$/, '$2')
      return [[match[1], value]]
    }))
  } catch {
    return {}
  }
}

async function loadConfig() {
  const files = await Promise.all([
    readEnvFile('.env'),
    readEnvFile('.env.local'),
    readEnvFile('supabase/.env'),
  ])
  return { ...files[0], ...files[1], ...files[2], ...process.env }
}

const config = await loadConfig()
const reader = createInterface({ input, output })

try {
  const choice = (await reader.question('Provision for local staging or production? [local/production]: ')).trim().toLowerCase()
  if (choice !== 'local' && choice !== 'production') throw new Error('Choose exactly "local" or "production".')

  const email = String(config.BOOTSTRAP_TEACHER_EMAIL ?? '').trim().toLowerCase()
  const displayName = String(config.BOOTSTRAP_TEACHER_DISPLAY_NAME ?? '').trim()
  const secret = String(config.BOOTSTRAP_TEACHER_SECRET ?? '')
  const appOrigin = String(config.APP_ORIGIN ?? '').replace(/\/$/, '')
  const functionUrl = choice === 'local'
    ? String(config.LOCAL_FUNCTION_URL ?? defaultLocalFunctionUrl).trim()
    : String(config.SUPABASE_FUNCTION_URL ?? '').trim()

  if (!emailPattern.test(email)) throw new Error('Set a valid BOOTSTRAP_TEACHER_EMAIL in the env file.')
  if (!secret) throw new Error('Set BOOTSTRAP_TEACHER_SECRET in the env file.')
  if (!appOrigin) throw new Error('Set APP_ORIGIN in the env file.')
  if (!functionUrl) throw new Error('Set SUPABASE_FUNCTION_URL for production.')

  reader.close()
  const response = await fetch(functionUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-bootstrap-secret': secret },
    body: JSON.stringify({ email, ...(displayName ? { displayName } : {}), redirectTo: `${appOrigin}/update-password` }),
  })
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(typeof body.error === 'string' ? body.error : `Bootstrap failed (${response.status}).`)
  console.log(`Teacher provisioning succeeded: ${body.status ?? 'complete'}. Check the invitation email to set the password.`)
} catch (error) {
  reader.close()
  console.error(error instanceof Error ? error.message : 'Teacher provisioning failed.')
  process.exitCode = 1
}
