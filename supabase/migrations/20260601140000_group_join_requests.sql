-- G3: Beitritts-Anträge für (private) Gruppen mit kurzer Frage.
create table if not exists public.group_join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  message text,
  status text not null default 'pending', -- pending | approved | rejected
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (group_id, user_id)
);

create index if not exists idx_gjr_group_status
  on public.group_join_requests(group_id, status);

alter table public.group_join_requests enable row level security;

drop policy if exists gjr_select on public.group_join_requests;
create policy gjr_select on public.group_join_requests
  for select to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.group_members m
      where m.group_id = group_join_requests.group_id
        and m.user_id = auth.uid()
        and m.role in ('owner','admin')
    )
  );

drop policy if exists gjr_insert on public.group_join_requests;
create policy gjr_insert on public.group_join_requests
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');

drop policy if exists gjr_update on public.group_join_requests;
create policy gjr_update on public.group_join_requests
  for update to authenticated using (
    exists (
      select 1 from public.group_members m
      where m.group_id = group_join_requests.group_id
        and m.user_id = auth.uid()
        and m.role in ('owner','admin')
    )
  );

drop policy if exists gjr_delete on public.group_join_requests;
create policy gjr_delete on public.group_join_requests
  for delete to authenticated using (user_id = auth.uid());

-- Approve-RPC: setzt Status approved + fügt das Mitglied hinzu, atomar.
create or replace function public.approve_group_join(p_request_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  select * into r from public.group_join_requests where id = p_request_id;
  if r is null then return false; end if;
  if not exists (
    select 1 from public.group_members m
    where m.group_id = r.group_id and m.user_id = auth.uid()
      and m.role in ('owner','admin')
  ) then
    raise exception 'Unauthorized';
  end if;
  update public.group_join_requests
    set status = 'approved', decided_at = now()
    where id = p_request_id;
  insert into public.group_members (group_id, user_id, role)
    values (r.group_id, r.user_id, 'member')
    on conflict (group_id, user_id) do nothing;
  return true;
end;
$$;

revoke all on function public.approve_group_join(uuid) from public;
grant execute on function public.approve_group_join(uuid) to authenticated;
