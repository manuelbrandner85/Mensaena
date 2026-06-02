-- Der Karma-Trigger feuerte bei JEDEM Update mit status='accepted' (auch
-- accepted→accepted), ohne Übergangs-Prüfung → mehrfaches Annehmen oder ein
-- erneutes Speichern der Zeile vergab Karma mehrfach (Exploit per Doppel-Tap).
-- Jetzt nur beim echten Übergang nach 'accepted' (Insert mit accepted ODER
-- OLD.status != 'accepted'). Idempotent via create or replace.
create or replace function public.tg_interaction_karma()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_post_owner uuid;
begin
  if new.status = 'accepted'
     and (tg_op = 'INSERT' or old.status is distinct from 'accepted') then
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
