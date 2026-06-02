-- FIX 1: Karma-Trigger nutzte NEW.user_id, aber interactions hat nur
-- helper_id → der Trigger wäre bei jeder angenommenen Hilfe gecrasht
-- ('record NEW has no field user_id') und hätte den Accept blockiert.
create or replace function public.tg_interaction_karma()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_post_owner uuid;
begin
  if new.status = 'accepted' then
    select user_id into v_post_owner from posts where id = new.post_id;
    if new.helper_id is not null then
      perform public._add_karma(
        new.helper_id, 10, 'Hilfe-Angebot angenommen', 'interaction', new.id);
    end if;
    if v_post_owner is not null then
      perform public._add_karma(
        v_post_owner, 2, 'Hilfe erhalten', 'interaction', new.id);
    end if;
  end if;
  return new;
end;
$$;

-- FIX 2: Badge-Vergabe-Engine. Vorher wurde NUR der Referral-Badge je
-- vergeben — alle anderen Katalog-Badges waren unerreichbar. Diese Funktion
-- berechnet pro berechenbarem requirement_type den Ist-Stand des Nutzers und
-- verleiht jedes erreichte Badge (idempotent) inkl. Karma-Gutschrift. Der
-- bestehende Trigger trg_notify_on_badge_earned benachrichtigt automatisch.
create or replace function public.check_and_award_badges()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  me uuid := auth.uid();
  r record;
  v_new integer := 0;
  v_inserted integer;
begin
  if me is null then
    raise exception 'auth required' using errcode = 'insufficient_privilege';
  end if;

  for r in
    with metrics(rtype, val) as (
      values
        ('register',             1),
        ('posts_created',        (select count(*)::int from posts where user_id = me)),
        ('articles_written',     (select count(*)::int from knowledge_articles where author_id = me)),
        ('comments_written',     (select count(*)::int from post_comments where user_id = me)),
        ('help_offered',         (select count(*)::int from interactions where helper_id = me and status in ('accepted','completed','done'))),
        ('legendary_helper',     (select count(*)::int from interactions where helper_id = me and status in ('accepted','completed','done'))),
        ('streak_days',          (select coalesce(longest_streak, 0)::int from user_streaks where user_id = me)),
        ('timebank_hours',       (select coalesce(sum(hours), 0)::int from timebank_entries where giver_id = me and status = 'confirmed')),
        ('events_created',       (select count(*)::int from events where author_id = me)),
        ('groups_created',       (select count(*)::int from groups where creator_id = me)),
        ('groups_joined',        (select count(*)::int from group_members where user_id = me)),
        ('challenges_completed', (select count(*)::int from daily_challenges where user_id = me and is_completed)),
        ('trust_score',          (select coalesce(round(trust_score), 0)::int from profiles where id = me)),
        ('followers',            (select count(*)::int from friendships where status = 'accepted' and (requester_id = me or addressee_id = me))),
        ('invitees_joined',      (select count(*)::int from referrals where inviter_id = me and invitee_id is not null))
    )
    select b.id as badge_id, coalesce(b.points, 0) as points
    from public.badges b
    join metrics m on m.rtype = b.requirement_type
    where m.val >= b.requirement_value
      and not exists (
        select 1 from public.user_badges ub
        where ub.user_id = me and ub.badge_id = b.id
      )
  loop
    insert into public.user_badges (user_id, badge_id)
      values (me, r.badge_id)
      on conflict (user_id, badge_id) do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted > 0 then
      v_new := v_new + 1;
      if r.points > 0 then
        perform public._add_karma(me, r.points, 'Badge erhalten', 'badge', r.badge_id);
      end if;
    end if;
  end loop;
  return v_new;
end;
$$;

revoke all on function public.check_and_award_badges() from public;
grant execute on function public.check_and_award_badges() to authenticated;
