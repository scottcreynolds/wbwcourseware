import { z } from 'zod'

const envSchema = z.object({
  VITE_APP_NAME: z.string().min(1).default('Writers Be Writing'),
  VITE_SUPABASE_URL: z.string().url(),
  VITE_SUPABASE_ANON_KEY: z.string().min(1),
})

export type AppEnv = z.infer<typeof envSchema>

type EnvSource = Pick<ImportMetaEnv, 'VITE_APP_NAME' | 'VITE_SUPABASE_URL' | 'VITE_SUPABASE_ANON_KEY'>

export function readEnv(source: EnvSource = import.meta.env): AppEnv {
  return envSchema.parse(source)
}
