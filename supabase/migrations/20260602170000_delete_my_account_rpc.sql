-- GDPR Art. 17: echte Selbst-Löschung. Der Settings-Screen rief bisher eine
-- NICHT existente RPC 'delete_my_account' → fiel in einen Fake-Soft-Delete
-- (nur Profil anonymisiert + is_banned, Posts/Messages/etc. blieben). Diese
-- RPC löscht den auth.users-Eintrag → CASCADE entfernt alle abhängigen Daten
-- (gleiche Mechanik wie der 14-Tage-Cron execute_pending_account_deletions).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  me uuid;
begin
  me := auth.uid();
  if me is null then
    raise exception 'auth required' using errcode = 'insufficient_privilege';
  end if;
  delete from public.account_deletion_requests where user_id = me;
  delete from auth.users where id = me;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
