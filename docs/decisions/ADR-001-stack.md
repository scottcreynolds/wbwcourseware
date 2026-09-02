# ADR-001: Application Stack

Status: Accepted

Use Vue 3, Vite, Vuetify, TypeScript, Supabase, Resend, Vercel, `pnpm`, Vitest, Vue Test Utils, and Playwright. Use plain/scoped CSS; no Tailwind. Privileged logic runs in Supabase Edge Functions. Local backend uses Supabase CLI/Docker.

Rationale: Fits owner expertise, keeps operations small, and provides Postgres/RLS/Auth/Storage without a custom backend service.

