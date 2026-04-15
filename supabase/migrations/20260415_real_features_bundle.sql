-- Real-features bundle: quiet hours, offer/seek tags, event rideshares,
-- weekly challenges, group private threads (via conversations.group_id),
-- organization members + invite codes.
--
-- NOTE: Already applied live via Supabase MCP. This file exists for
-- documentation and future clean-environment replays.

-- 1) Profile additions: quiet hours + offer/seek tags
alter table profiles
  add column if not exists quiet_hours_enabled boolean default false,
  add column if not exists quiet_hours_start time,
  add column if not exists quiet_hours_end time,
  add column if not exists offer_tags text[] default '{}'::text[],
  add column if not exists seek_tags text[] default '{}'::text[];

-- 2) Challenges: weekly rotation
alter table challenges
  add column if not exists is_weekly boolean default false,
  add column if not exists week_of date;

create index if not exists idx_challenges_weekly on challenges(is_weekly, week_of)
  where is_weekly = true;

-- 3) Conversations: link to groups for private threads
alter table conversations
  add column if not exists group_id uuid references groups(id) on delete cascade;

create index if not exists idx_conversations_group on conversations(group_id)
  where group_id is not null;

-- 4) Event rideshares
create table if not exists event_rideshares (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null check (role in ('offer', 'seek')),
  seats integer not null default 1 check (seats between 1 and 8),
  from_location text,
  departure_time timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_event_rideshares_event on event_rideshares(event_id);

alter table event_rideshares enable row level security;

drop policy if exists event_rideshares_select on event_rideshares;
create policy event_rideshares_select on event_rideshares
  for select using (true);

drop policy if exists event_rideshares_insert on event_rideshares;
create policy event_rideshares_insert on event_rideshares
  for insert with check (auth.uid() = user_id);

drop policy if exists event_rideshares_update on event_rideshares;
create policy event_rideshares_update on event_rideshares
  for update using (auth.uid() = user_id);

drop policy if exists event_rideshares_delete on event_rideshares;
create policy event_rideshares_delete on event_rideshares
  for delete using (auth.uid() = user_id);

-- 5) Organization members
create table if not exists organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'admin')),
  joined_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index if not exists idx_org_members_org on organization_members(organization_id);
create index if not exists idx_org_members_user on organization_members(user_id);

alter table organization_members enable row level security;

drop policy if exists org_members_select on organization_members;
create policy org_members_select on organization_members
  for select using (true);

drop policy if exists org_members_delete_self on organization_members;
create policy org_members_delete_self on organization_members
  for delete using (auth.uid() = user_id);

-- 6) Organization invite codes
create table if not exists organization_invites (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  code text not null unique,
  created_by uuid references profiles(id) on delete set null,
  role text not null default 'member' check (role in ('member', 'admin')),
  max_uses integer not null default 10,
  use_count integer not null default 0,
  expires_at timestamptz not null default (now() + interval '30 days'),
  created_at timestamptz not null default now()
);

create index if not exists idx_org_invites_org on organization_invites(organization_id);

alter table organization_invites enable row level security;

drop policy if exists org_invites_admin_all on organization_invites;
create policy org_invites_admin_all on organization_invites
  for all using (
    exists (
      select 1 from organization_members m
      where m.organization_id = organization_invites.organization_id
        and m.user_id = auth.uid()
        and m.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from organization_members m
      where m.organization_id = organization_invites.organization_id
        and m.user_id = auth.uid()
        and m.role = 'admin'
    )
  );

-- 7) RPC to redeem an invite code
create or replace function redeem_org_invite(p_code text)
returns organization_members
language plpgsql
security definer
as $$
declare
  v_invite organization_invites;
  v_member organization_members;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_invite
  from organization_invites
  where code = upper(trim(p_code))
  for update;

  if not found then
    raise exception 'invalid code';
  end if;

  if v_invite.expires_at < now() then
    raise exception 'expired code';
  end if;

  if v_invite.use_count >= v_invite.max_uses then
    raise exception 'exhausted code';
  end if;

  insert into organization_members (organization_id, user_id, role)
  values (v_invite.organization_id, auth.uid(), v_invite.role)
  on conflict (organization_id, user_id) do update
    set role = greatest(organization_members.role, excluded.role)
  returning * into v_member;

  update organization_invites
  set use_count = use_count + 1
  where id = v_invite.id;

  return v_member;
end;
$$;

grant execute on function redeem_org_invite(text) to authenticated;
