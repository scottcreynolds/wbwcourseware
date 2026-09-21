/* global fetch, console */

import { execFile } from 'node:child_process'
import { readFile } from 'node:fs/promises'
import { createInterface } from 'node:readline/promises'
import process, { stdin as input, stdout as output } from 'node:process'
import { promisify } from 'node:util'

const execFileAsync = promisify(execFile)

const defaultLocalRestUrl = 'http://127.0.0.1:55321/rest/v1'
const defaultLocalFunctionUrl = 'http://kong:8000/functions/v1/notify-teacher'

async function readSupabaseStatus() {
  const { stdout } = await execFileAsync('supabase', ['status', '-o', 'json'])
  return JSON.parse(stdout)
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

  let restUrl
  let functionUrl
  let serviceKey

  const status = await readSupabaseStatus().catch(() => null)

  if (isLocal) {
    const statusRestUrl = status?.API_URL ? `${status.API_URL}/rest/v1` : undefined
    restUrl = String(config.LOCAL_REST_URL ?? statusRestUrl ?? defaultLocalRestUrl).trim()
    functionUrl = String(config.LOCAL_NOTIFY_TEACHER_FUNCTION_URL ?? defaultLocalFunctionUrl).trim()
    serviceKey = String(config.SUPABASE_SERVICE_ROLE_KEY ?? status?.SERVICE_ROLE_KEY ?? '').trim()
    if (!serviceKey) throw new Error('Could not read the local service-role key. Run `supabase start` first, or set SUPABASE_SERVICE_ROLE_KEY.')
  } else {
    const projectRef = String(config.SUPABASE_PROJECT_REF ?? status?.linked_project_ref ?? '').trim()
    if (!projectRef) {
      throw new Error('Could not determine the production project ref. Run `supabase link` first, or set SUPABASE_PROJECT_REF explicitly.')
    }
    restUrl = String(config.SUPABASE_REST_URL ?? `https://${projectRef}.supabase.co/rest/v1`).trim()
    functionUrl = String(config.SUPABASE_NOTIFY_TEACHER_FUNCTION_URL ?? `https://${projectRef}.supabase.co/functions/v1/notify-teacher`).trim()
    serviceKey = String(config.PRODUCTION_SERVICE_ROLE_KEY ?? '').trim()
    if (!serviceKey) {
      throw new Error('Set PRODUCTION_SERVICE_ROLE_KEY (from the Supabase dashboard -> Project Settings -> API; never commit this). '
        + `Detected project ref ${projectRef}; REST/function URLs were derived automatically -- only the key needs to be provided.`)
    }
  }

  reader.close()
  console.log(`Target: ${choice}`)
  console.log(`  REST URL:     ${restUrl}`)
  console.log(`  Function URL: ${functionUrl}`)

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
