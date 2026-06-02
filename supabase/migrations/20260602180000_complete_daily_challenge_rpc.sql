-- Daily-Challenge abschließen UND das Karma tatsächlich vergeben. Vorher
-- setzte der Client nur is_completed=true → die angezeigte '+X Karma' wurde
-- NIE gutgeschrieben (stiller Verlust). Idempotent: vergibt Karma nur beim
-- ersten Abschluss, und nur für die eigene Challenge.
create or replace function public.complete_daily_challenge(p_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  me uuid;
  v_reward integer;
  v_rows integer;
begin
  me := auth.uid();
  if me is null then
    raise exception 'auth required' using errcode = 'insufficient_privilege';
  end if;

  update public.daily_challenges
    set is_completed = true,
        completed_at = now()
    where id = p_id
      and user_id = me
      and is_completed = false
    returning coalesce(karma_reward, 0) into v_reward;

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return 0;
  end if;

  if v_reward > 0 then
    perform public._add_karma(me, v_reward, 'Tages-Challenge abgeschlossen',
      'daily_challenge', p_id);
  end if;
  return v_reward;
end;
$$;

revoke all on function public.complete_daily_challenge(uuid) from public;
grant execute on function public.complete_daily_challenge(uuid) to authenticated;
