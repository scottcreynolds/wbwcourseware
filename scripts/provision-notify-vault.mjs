/* global fetch, console */

import { execFile } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { createInterface } from 'node:readline/promises'
import process, { stdin as input, stdout as output } from 'node:process'
import { promisify } from 'node:util'

const execFileAsync = promisify(execFile)

const defaultLocalRestUrl = 'http://127.0.0.1:55321/rest/v1'
const defaultLocalFunctionUrl = 'http://kong:8000/functions/v1/notify-teacher'

async function readLocalServiceRoleKey() {
  const { stdout } = await execFileAsync('supabase', ['status', '-o', 'json'])
  const status = JSON.parse(stdout)
  return typeof status.SERVICE_ROLE_KEY === 'string' ? status.SERVICE_ROLE_KEY : ''
}

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
  const choice = (await reader.question('Provision Vault secrets for local or production? [local/production]: ')).trim().toLowerCase()
  if (choice !== 'local' && choice !== 'production') throw new Error('Choose exactly "local" or "production".')

  const isLocal = choice === 'local'
  const restUrl = isLocal
    ? String(config.LOCAL_REST_URL ?? defaultLocalRestUrl).trim()
    : String(config.SUPABASE_REST_URL ?? '').trim()
  const functionUrl = isLocal
    ? String(config.LOCAL_NOTIFY_TEACHER_FUNCTION_URL ?? defaultLocalFunctionUrl).trim()
    : String(config.SUPABASE_NOTIFY_TEACHER_FUNCTION_URL ?? '').trim()
  const serviceKey = isLocal
    ? String(config.SUPABASE_SERVICE_ROLE_KEY ?? (await readLocalServiceRoleKey().catch(() => ''))).trim()
    : String(config.PRODUCTION_SERVICE_ROLE_KEY ?? '').trim()

  if (!restUrl) throw new Error(isLocal ? 'Set LOCAL_REST_URL (or run `supabase start` first).' : 'Set SUPABASE_REST_URL for production.')
  if (!functionUrl) throw new Error(isLocal ? 'Set LOCAL_NOTIFY_TEACHER_FUNCTION_URL.' : 'Set SUPABASE_NOTIFY_TEACHER_FUNCTION_URL for production.')
  if (!serviceKey) {
    throw new Error(isLocal
      ? 'Could not read the local service-role key. Run `supabase start` first, or set SUPABASE_SERVICE_ROLE_KEY.'
      : 'Set PRODUCTION_SERVICE_ROLE_KEY (from the Supabase dashboard; never commit this).')
  }

  reader.close()
  const response = await fetch(`${restUrl}/rpc/provision_notify_teacher_vault_secrets`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      apikey: serviceKey,
      authorization: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify({ function_url: functionUrl, service_key: serviceKey }),
  })
  if (!response.ok) {
    const body = await response.json().catch(() => ({}))
    throw new Error(typeof body.message === 'string' ? body.message : `Provisioning failed (${response.status}).`)
  }
  console.log(`Vault secrets provisioned for ${choice}: notify_teacher_function_url, notify_teacher_service_key.`)
} catch (error) {
  reader.close()
  console.error(error instanceof Error ? error.message : 'Vault provisioning failed.')
  process.exitCode = 1
}
