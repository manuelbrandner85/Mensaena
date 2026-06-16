-- ════════════════════════════════════════════════════════════════════════
-- Reflexions-Loop: schließt den Kreis Produktion → Fix. Täglich aggregiert
-- godmode_reflect_production_errors() die crash_logs der letzten 48h und legt
-- für wiederkehrende Laufzeit-Crashes (>=2 betroffene Nutzer) automatisch
-- einen Bug-Vorschlag in admin_dev_suggestions an. Der Vorschlag erscheint im
-- Dashboard und kann (auch vom Autopilot) zum Fix-Auftrag werden.
-- Dedupe: kein zweiter offener Vorschlag mit identischem Titel.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.godmode_reflect_production_errors()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rec record;
  v_title text;
begin
  for v_rec in
    select cl.error_message,
           max(cl.error_type)         as error_type,
           max(cl.app_version)        as app_version,
           count(*)                   as crash_count,
           count(distinct cl.user_id) as users
      from public.crash_logs cl
     where cl.created_at > now() - interval '48 hours'
       and coalesce(cl.error_message, '') <> ''
     group by cl.error_message
    having count(distinct cl.user_id) >= 2
     order by count(distinct cl.user_id) desc, count(*) desc
     limit 3
  loop
    v_title := 'Crash beheben: ' || left(v_rec.error_message, 80);

    -- Dedupe: schon ein offener/angenommener Vorschlag mit diesem Titel?
    if exists (
      select 1 from public.admin_dev_suggestions s
       where s.title = v_title
         and s.status in ('pending', 'accepted', 'implemented')
    ) then
      continue;
    end if;

    insert into public.admin_dev_suggestions (
      category, severity, title, description, instruction, impact, effort
    ) values (
      'bug',
      case when v_rec.users >= 5 then 'critical' else 'high' end,
      v_title,
      format('Wiederkehrender Laufzeit-Crash: %s× bei %s Nutzern (v%s).',
             v_rec.crash_count, v_rec.users, coalesce(v_rec.app_version, '?')),
      format(
        'Behebe den wiederkehrenden Laufzeit-Crash aus der Produktion. '
        'Fehlertyp: %s. Meldung: %s. Finde die Ursache (Stacktrace/Kontext in '
        'crash_logs), reproduziere sie gedanklich und fixe sie robust '
        '(null-sicher, mit Fehlerbehandlung, ohne neue Regressionen).',
        coalesce(v_rec.error_type, '?'), v_rec.error_message),
      5,
      3
    );
  end loop;
end;
$$;

-- Täglich 02:00 UTC (idempotent: vorher unschedule).
DO $$ BEGIN PERFORM cron.unschedule('godmode_reflection_loop');
EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule(
  'godmode_reflection_loop',
  '0 2 * * *',
  $sql$SELECT public.godmode_reflect_production_errors()$sql$
);
