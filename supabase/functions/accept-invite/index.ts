import {createClient} from 'npm:@supabase/supabase-js@2'
import {corsHeaders} from '../_shared/cors.ts'
import {jsonResponse} from '../_shared/http.ts'

const hex=(buffer:ArrayBuffer)=>[...new Uint8Array(buffer)].map(byte=>byte.toString(16).padStart(2,'0')).join('')
Deno.serve(async request=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
  if(request.method!=='POST')return jsonResponse({error:'Method not allowed'},405)
  const url=Deno.env.get('SUPABASE_URL'),service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if(!url||!service)return jsonResponse({error:'Server is not configured'},500)
  let body:{token?:unknown;password?:unknown;displayName?:unknown};try{body=await request.json()}catch{return jsonResponse({error:'Invalid JSON'},400)}
  const token=typeof body.token==='string'?body.token:'',password=typeof body.password==='string'?body.password:'',displayName=typeof body.displayName==='string'?body.displayName.trim():''
  if(token.length<20)return jsonResponse({error:'Invitation is invalid or expired'},400)
  const tokenHash=hex(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token)))
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}})
  const {data:invitation}=await admin.from('cohort_invitations').select('id,email_normalized,status,expires_at').eq('token_hash',tokenHash).maybeSingle()
  if(!invitation||invitation.status!=='pending'||Date.parse(invitation.expires_at)<=Date.now())return jsonResponse({error:'Invitation is invalid or expired'},400)
  let userId:string|undefined,userEmail:string|undefined
  const authorization=request.headers.get('authorization')
  if(authorization){const jwt=authorization.replace(/^Bearer\s+/i,'');const {data:{user}}=await admin.auth.getUser(jwt);if(user){userId=user.id;userEmail=user.email}}
  if(!userId){
    if(password.length<12)return jsonResponse({error:'Password must contain at least 12 characters'},400)
    const {data,error}=await admin.auth.admin.createUser({email:invitation.email_normalized,password,email_confirm:true,user_metadata:displayName?{display_name:displayName}:{}})
    if(error)return jsonResponse({error:'Account already exists. Sign in, then open invitation link again.'},409)
    userId=data.user.id;userEmail=data.user.email
  }
  if(userEmail?.trim().toLowerCase()!==invitation.email_normalized)return jsonResponse({error:'Signed-in account does not match invitation'},403)
  const {error}=await admin.rpc('activate_cohort_invitation',{target_invitation_id:invitation.id,target_student_id:userId,target_email:userEmail})
  if(error)return jsonResponse({error:'Invitation could not be accepted'},400)
  return jsonResponse({status:'accepted'})
})
