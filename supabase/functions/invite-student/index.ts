import {createClient} from 'npm:@supabase/supabase-js@2'
import {corsHeaders} from '../_shared/cors.ts'
import {jsonResponse} from '../_shared/http.ts'

const normalize=(value:unknown)=>typeof value==='string'&&/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim())?value.trim().toLowerCase():null
const hex=(buffer:ArrayBuffer)=>[...new Uint8Array(buffer)].map(byte=>byte.toString(16).padStart(2,'0')).join('')
const escapeHtml=(value:string)=>value.replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]??char))

Deno.serve(async request=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
  if(request.method!=='POST')return jsonResponse({error:'Method not allowed'},405)
  const url=Deno.env.get('SUPABASE_URL'),anon=Deno.env.get('SUPABASE_ANON_KEY'),service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if(!url||!anon||!service)return jsonResponse({error:'Server is not configured'},500)
  const authorization=request.headers.get('authorization')??''
  const caller=createClient(url,anon,{global:{headers:{Authorization:authorization}}})
  const {data:{user}}=await caller.auth.getUser()
  if(!user)return jsonResponse({error:'Authentication required'},401)
  let body:{courseId?:unknown;email?:unknown};try{body=await request.json()}catch{return jsonResponse({error:'Invalid JSON'},400)}
  const email=normalize(body.email),courseId=typeof body.courseId==='string'?body.courseId:null
  if(!email||!courseId)return jsonResponse({error:'Course and valid email are required'},400)
  const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}})
  const [{data:profile},{data:course}]=await Promise.all([admin.from('profiles').select('role').eq('id',user.id).single(),admin.from('courses').select('id,title,teacher_id').eq('id',courseId).single()])
  if(profile?.role!=='teacher'||course?.teacher_id!==user.id)return jsonResponse({error:'Not authorized'},403)
  const tenMinutesAgo=new Date(Date.now()-600000).toISOString()
  const {count:recentCount}=await admin.from('course_invitations').select('id',{count:'exact',head:true}).eq('invited_by',user.id).gte('created_at',tenMinutesAgo)
  if((recentCount??0)>=10)return jsonResponse({error:'Too many invitations. Wait before trying again.'},429)
  const tokenBytes=crypto.getRandomValues(new Uint8Array(32)),token=btoa(String.fromCharCode(...tokenBytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','')
  const tokenHash=hex(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token)))
  await admin.from('course_invitations').update({status:'revoked'}).eq('course_id',courseId).eq('email_normalized',email).eq('status','pending')
  const {data:invitation,error}=await admin.from('course_invitations').insert({course_id:courseId,email_normalized:email,token_hash:tokenHash,expires_at:new Date(Date.now()+14*86400000).toISOString(),invited_by:user.id}).select('id').single()
  if(error)return jsonResponse({error:'Invitation could not be created'},500)
  const origin=Deno.env.get('APP_ORIGIN')??'',inviteUrl=`${origin}/accept-invite?token=${encodeURIComponent(token)}`
  const resendKey=Deno.env.get('RESEND_API_KEY')??''
  if(resendKey){
    const response=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${resendKey}`,'Content-Type':'application/json'},body:JSON.stringify({from:Deno.env.get('EMAIL_FROM'),to:[email],subject:`Invitation to ${course.title}`,html:`<p>You have been invited to <strong>${escapeHtml(course.title)}</strong>.</p><p><a href="${escapeHtml(inviteUrl)}">Create or connect your account</a></p><p>This link expires in 14 days.</p>`})})
    if(!response.ok)return jsonResponse({status:'created',invitationId:invitation.id,emailStatus:'failed'},202)
    return jsonResponse({status:'created',invitationId:invitation.id,emailStatus:'sent'},201)
  }
  if(Deno.env.get('APP_ENV')==='local')return jsonResponse({status:'created',invitationId:invitation.id,emailStatus:'local',developmentInviteUrl:inviteUrl},201)
  return jsonResponse({error:'Email is not configured'},500)
})
