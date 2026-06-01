-- P5: Repost / "Verstärken". Ein User kann einen Post verstärken; das
-- erhöht den sozialen Push und macht ihn im Feed seiner Follower sichtbar.
create table if not exists public.post_reposts (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create index if not exists idx_post_reposts_post on public.post_reposts(post_id);
create index if not exists idx_post_reposts_user on public.post_reposts(user_id, created_at);

alter table public.post_reposts enable row level security;

drop policy if exists pr_select on public.post_reposts;
create policy pr_select on public.post_reposts
  for select to authenticated using (true);

drop policy if exists pr_insert on public.post_reposts;
create policy pr_insert on public.post_reposts
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists pr_delete on public.post_reposts;
create policy pr_delete on public.post_reposts
  for delete to authenticated using (user_id = auth.uid());

-- Feed der Follower: Posts, die Leute denen ICH folge in den letzten 7
-- Tagen verstärkt haben.
create or replace function public.get_reposted_feed(p_limit int default 20)
returns table(post_id uuid, reposter_id uuid, reposted_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select distinct on (r.post_id)
         r.post_id, r.user_id as reposter_id, r.created_at as reposted_at
  from public.post_reposts r
  join public.user_follows f
    on f.following_id = r.user_id
  where f.follower_id = auth.uid()
    and r.created_at > now() - interval '7 days'
    and r.user_id <> auth.uid()
  order by r.post_id, r.created_at desc
  limit greatest(1, least(p_limit, 50));
$$;

revoke all on function public.get_reposted_feed(int) from public;
grant execute on function public.get_reposted_feed(int) to authenticated;
