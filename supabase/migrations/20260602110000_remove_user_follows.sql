-- Entfernung des Follow-Systems (User-Wunsch). Friend-Requests sind ab
-- jetzt der einzige soziale Connect-Mechanismus.

-- get_reposted_feed nutzte user_follows → auf akzeptierte friendships
-- umstellen, damit Reposts von Freund:innen im Feed erscheinen.
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
  join public.friendships f
    on f.status = 'accepted'
   and (
        (f.requester_id = auth.uid() and f.addressee_id = r.user_id)
     or (f.addressee_id = auth.uid() and f.requester_id = r.user_id)
   )
  where r.created_at > now() - interval '7 days'
    and r.user_id <> auth.uid()
  order by r.post_id, r.created_at desc
  limit greatest(1, least(p_limit, 50));
$$;

drop table if exists public.user_follows cascade;
