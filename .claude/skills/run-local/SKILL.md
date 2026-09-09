---
name: run-local
description: Launch and drive wbwcourseware locally end-to-end (Vite frontend + local Supabase + Edge Functions + Mailpit), including how to get an authenticated teacher session in a real browser. Use this whenever asked to run, start, screenshot, or visually verify the app, or to confirm a change works via Playwright/browser automation rather than just typecheck/lint/tests.
---

# Running wbwcourseware locally

This app has no seeded test users. Getting an authenticated session
requires standing up the local Supabase stack, the Edge Functions
runtime, and the Vite dev server together, then bootstrapping a
teacher account through Mailpit. This skill is the exact sequence
verified working on 2026-09-09 — follow it in order.

## Known gotchas (read before you start)

1. **Vite binds IPv6 (`::1`) by default on this machine.** Plain
   `pnpm dev` makes the app reachable at `http://localhost:5173` but
   `http://127.0.0.1:5173` gets `ERR_CONNECTION_REFUSED` (including
   from Playwright, and from `curl`). Everything else in the stack
   (Supabase, Kong, Mailpit) is on `127.0.0.1`, and the Edge
   Functions' CORS `APP_ORIGIN` and the invite/reset-password
   redirect links are also hardcoded to `127.0.0.1:5173`. **Always
   launch Vite with `--host 127.0.0.1 --port 5173`** so every part of
   the stack agrees on the same origin.

2. **`supabase/.env` cannot override `SUPABASE_URL` /
   `SUPABASE_SERVICE_ROLE_KEY`.** The Supabase CLI silently skips any
   env var in that file starting with `SUPABASE_` (you'll see `Env
   name cannot start with SUPABASE_, skipping: ...` in the functions
   log) — this is expected, not a bug to fix. Those two are injected
   automatically by `supabase functions serve`.

3. **If `bootstrap-teacher` returns `{"error":"Bootstrap lookup
   failed"}`**, the local Postgres `service_role` role is missing
   table grants (seen once this session — cause unclear, possibly a
   stale local stack from a previous CLI version). Fix: `pnpm
   supabase:reset` (reapplies migrations and reseeds roles cleanly),
   then retry. Confirm the grant directly if you want to verify
   before/after:
   ```bash
   docker exec -i supabase_db_writers-be-writing-courseware psql -U postgres -d postgres \
     -c "select has_table_privilege('service_role','public.profiles','select');"
   ```
   Resetting wipes local data — fine for a throwaway dev DB, but
   check `git status`-equivalent local data first if you care about
   it (ask the user).

4. **Invite/reset tokens expire fast and are single-use.** If more
   than a couple minutes pass between bootstrapping and clicking the
   Mailpit link, or if you reset the DB after bootstrapping, the old
   token 404s with `otp_expired`. Just delete the user and
   re-bootstrap immediately before use — don't try to reuse a link
   from earlier in a session.

5. **Kill background processes by pattern, not by the one PID your
   shell printed.** `pnpm dev` / `pnpm exec supabase functions serve`
   spawn a chain of child processes; `kill <printed-pid>` only kills
   the top of the chain and leaves orphans holding the port. Use
   `pkill -f "vite --host 127.0.0.1"` and `pkill -f "supabase
   functions serve"` to actually free the ports.

6. **The Chrome extension (`mcp__claude-in-chrome__*`) may not be
   connected in this environment.** If `tabs_context_mcp` errors with
   "Browser extension is not connected", fall back to Playwright
   directly (already a devDependency: `@playwright/test`). Make sure
   the browser binary is installed first — `npx playwright install
   chromium` (silent output on success). Run any driver script from
   inside the project directory (or point Node at it via a path
   inside the repo) so `node_modules` resolves; a script under
   `/tmp` won't find `@playwright/test`.

## Setup (one-time per machine, or after a stack wipe)

```bash
cd /Users/scottcreynolds/code/wbwcourseware

# 1. Local Supabase stack (DB, Auth, Storage, Kong, Mailpit, Studio)
pnpm supabase:start
supabase status   # confirms it's up; prints keys (also see "Known keys" below)

# 2. Frontend env (gitignored, not tracked — create if missing)
cat > .env.local << 'EOF'
VITE_APP_NAME=Writers Be Writing
VITE_SUPABASE_URL=http://127.0.0.1:55321
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
EOF

# 3. Functions env (gitignored, not tracked — create if missing)
cp supabase/.env.example supabase/.env
# then set a real secret in place of the placeholder:
SECRET=$(openssl rand -hex 24)
sed -i '' "s/BOOTSTRAP_TEACHER_SECRET=.*/BOOTSTRAP_TEACHER_SECRET=$SECRET/" supabase/.env
```

`.env.local` and `supabase/.env` are both in `.gitignore` — safe to
create/edit freely, never commit them. If they already exist from a
prior session, just reuse them (check `BOOTSTRAP_TEACHER_SECRET` is
still a real value, not the placeholder).

**Known local anon key**: the `ANON_KEY` above is the standard demo
JWT this repo's local Supabase config produces (`supabase-demo`
issuer). If `supabase status` prints a different `ANON_KEY` /
`PUBLISHABLE_KEY`, prefer whatever it just printed over this cached
value — CLI versions occasionally change the key format.

## Launch

Run each in the background, in this order, waiting for each to be
ready before starting the next:

```bash
# Edge Functions runtime (needed for bootstrap/invite/submission endpoints)
cd /Users/scottcreynolds/code/wbwcourseware
nohup pnpm exec supabase functions serve --env-file supabase/.env > /tmp/wbw-functions.log 2>&1 &
sleep 4 && tail -10 /tmp/wbw-functions.log   # confirm "Serving functions on ..."

# Vite dev server — MUST use --host 127.0.0.1 (see gotcha #1)
nohup pnpm exec vite --host 127.0.0.1 --port 5173 > /tmp/wbw-dev.log 2>&1 &
sleep 3 && curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:5173   # expect 200
```

## Get an authenticated teacher session

If a teacher already exists (check first — skip bootstrap if so):

```bash
docker exec -i supabase_db_writers-be-writing-courseware psql -U postgres -d postgres \
  -t -c "select email_normalized, role from profiles where role='teacher';"
```

Otherwise, bootstrap one:

```bash
cd /Users/scottcreynolds/code/wbwcourseware
SECRET=$(grep BOOTSTRAP_TEACHER_SECRET supabase/.env | cut -d= -f2)
curl -s -X POST http://127.0.0.1:55321/functions/v1/bootstrap-teacher \
  -H "content-type: application/json" \
  -H "x-bootstrap-secret: $SECRET" \
  -d '{"email":"teacher@example.com","displayName":"Teacher Name","redirectTo":"http://127.0.0.1:5173/update-password"}'
# => {"status":"bootstrapped","userId":"..."}
```

Grab the invite link from Mailpit (do this immediately — tokens
expire fast, see gotcha #4):

```bash
MSG_ID=$(curl -s "http://127.0.0.1:55324/api/v1/messages" | python3 -c "import json,sys; print(json.load(sys.stdin)['messages'][0]['ID'])")
LINK=$(curl -s "http://127.0.0.1:55324/api/v1/message/$MSG_ID" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Text') or d.get('HTML'))" \
  | grep -oE 'http://127\.0\.0\.1:55321[^"< )]*')
echo "$LINK"
```

Drive the invite-accept + password-set flow with Playwright (run from
inside the project dir so `@playwright/test` resolves):

```js
// e.g. .tmp-visual-check/setup.mjs — see cleanup note below
import { chromium } from '@playwright/test'

const browser = await chromium.launch()
const page = await (await browser.newContext({ viewport: { width: 1280, height: 900 } })).newPage()

await page.goto(process.env.INVITE_LINK)  // the LINK from above
await page.waitForLoadState('networkidle')

await page.locator('input[type="password"]').first().fill('TestPassword123!')
await page.locator('input[type="password"]').nth(1).fill('TestPassword123!')
await page.getByRole('button', { name: /update|set|save/i }).first().click()
await page.waitForLoadState('networkidle')

// Save the authenticated session for reuse across scripts
await page.context().storageState({ path: '/tmp/wbw-auth-state.json' })
await browser.close()
```

```bash
INVITE_LINK="$LINK" node .tmp-visual-check/setup.mjs
```

Every subsequent script can skip login by loading that saved state:

```js
const context = await browser.newContext({ storageState: '/tmp/wbw-auth-state.json', viewport: { width: 1280, height: 1000 } })
```

## Drive it

With an authenticated context, navigate and interact normally:

```js
await page.goto('http://127.0.0.1:5173/teacher')
await page.waitForLoadState('networkidle')
await page.screenshot({ path: '/tmp/wbw-check.png', fullPage: true })
```

Then **look at the screenshot** with the Read tool — a blank or
unauthenticated-looking frame means the storageState didn't apply or
the session expired; re-run the bootstrap+accept flow.

Useful selectors confirmed working: Vuetify buttons via `getByRole('button', { name: ... })`,
tabs via `getByRole('tab', { name: 'Details' })` (this app's course
editor tabs are: Details, Modules, Release & due dates, Students,
Announcements, Discussions), dialog fields via
`page.locator('.v-dialog').getByLabel(...)` (scope to `.v-dialog` —
plain `getByLabel` can match a hidden field behind the overlay).

## Cleanup

```bash
pkill -f "vite --host 127.0.0.1"
pkill -f "supabase functions serve"
rm -rf .tmp-visual-check   # if you created a scratch driver-script dir in-repo
```

Leave the Supabase Docker stack running between sessions (`pnpm
supabase:stop` only if you're done for good — it's slow to cold-start
and other local projects may share the Docker daemon). The
bootstrapped teacher account and any test courses persist in the
local DB across sessions unless you `pnpm supabase:reset`.

## Verified working end-to-end on 2026-09-09

Bootstrapped `teacher@example.com`, created a course via the UI,
walked all six course-editor tabs, created three modules, toggled
expand/collapse on two of them, reloaded the page, and confirmed via
`localStorage` inspection (`page.evaluate`) that the expand state
round-tripped correctly. See commit `df1c771` for the feature this
validated.
