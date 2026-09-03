export const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('APP_ORIGIN') ?? 'http://127.0.0.1:5173',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-bootstrap-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
