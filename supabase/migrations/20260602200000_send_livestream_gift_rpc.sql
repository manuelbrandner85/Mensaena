-- Livestream-Gifts kosteten 'karma_cost', das aber NIE abgezogen wurde →
-- jeder konnte unbegrenzt Gifts senden, auch mit 0 Karma. Diese RPC prüft
-- atomar das Guthaben, zieht das Karma ab (über _add_karma, negativ) und
-- legt das Gift an. Rückgabe: verbleibendes Karma, oder -1 bei zu wenig.
create or replace function public.send_livestream_gift(
  p_room_id uuid,
  p_gift_type text
)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  me uuid := auth.uid();
  v_cost integer;
  v_balance integer;
begin
  if me is null then
    raise exception 'auth required' using errcode = 'insufficient_privilege';
  end if;

  v_cost := case p_gift_type
              when 'diamond' then 20
              when 'star' then 5
              when 'applause' then 1
              else -1
            end;
  if v_cost < 0 then
    raise exception 'invalid gift type' using errcode = 'invalid_parameter_value';
  end if;

  select coalesce(karma_points, 0) into v_balance
    from public.profiles where id = me for update;
  if v_balance < v_cost then
    return -1;
  end if;

  perform public._add_karma(me, -v_cost, 'Livestream-Geschenk', 'gift', p_room_id);

  insert into public.livestream_gifts (room_id, sender_id, gift_type, karma_cost)
    values (p_room_id, me, p_gift_type, v_cost);

  return v_balance - v_cost;
end;
$$;

revoke all on function public.send_livestream_gift(uuid, text) from public;
grant execute on function public.send_livestream_gift(uuid, text) to authenticated;
