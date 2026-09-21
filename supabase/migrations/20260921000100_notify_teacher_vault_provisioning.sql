-- Trusted RPC to provision the two Vault secrets that
-- dispatch_teacher_notification() reads (see
-- 20260914000200_teacher_notifications.sql). This existed previously only as
-- a manual "run this SQL by hand" step in docs/EMAIL.md, which was missed in
-- at least one environment and left teacher_notifications rows stuck at
-- pending with no visible error. Exposing it as a service_role-only RPC lets
-- an operator script (scripts/provision-notify-vault.mjs) provision it the
-- same way pnpm bootstrap:teacher provisions the teacher account, reading
-- the actual secret values from env/CLI at run time rather than pasting them
-- into SQL that gets committed to git.
create function public.provision_notify_teacher_vault_secrets(
  function_url text,
  service_key text
) returns void language plpgsql security definer set search_path = ''
as $$
begin
  if current_user not in ('service_role', 'postgres') then raise exception 'service role required'; end if;
  if coalesce(function_url, '') = '' or coalesce(service_key, '') = '' then
    raise exception 'function_url and service_key are both required';
  end if;

  if exists(select 1 from vault.secrets where name = 'notify_teacher_function_url') then
    perform vault.update_secret(
      (select id from vault.secrets where name = 'notify_teacher_function_url'), function_url);
  else
    perform vault.create_secret(function_url, 'notify_teacher_function_url');
  end if;

  if exists(select 1 from vault.secrets where name = 'notify_teacher_service_key') then
    perform vault.update_secret(
      (select id from vault.secrets where name = 'notify_teacher_service_key'), service_key);
  else
    perform vault.create_secret(service_key, 'notify_teacher_service_key');
  end if;
end $$;
revoke all on function public.provision_notify_teacher_vault_secrets(text, text) from public, anon, authenticated;
grant execute on function public.provision_notify_teacher_vault_secrets(text, text) to service_role;
