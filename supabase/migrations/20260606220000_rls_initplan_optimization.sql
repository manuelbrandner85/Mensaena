-- ════════════════════════════════════════════════════════════════════════
-- Performance: auth_rls_initplan (Supabase-Advisor 0003) — größter Hebel gegen
-- die App-weite Langsamkeit.
--
-- 453 RLS-Policies rufen auth.uid()/auth.role()/auth.jwt() DIREKT auf. Postgres
-- wertet diese Funktion dann PRO ZEILE neu aus → bei großen Tabellen drastisch
-- langsam. Empfehlung von Supabase: in einen Scalar-Subselect verpacken
-- → `(select auth.uid())` wird EINMAL pro Query ausgewertet (initplan-Cache).
-- Semantisch identisch, nur schneller.
--
-- Sicherheit: Die Rewrite läuft über einen stabilen Snapshot (Temp-Tabelle) und
-- prüft am Ende, dass die Policy-Anzahl UNVERÄNDERT ist — andernfalls
-- RAISE EXCEPTION → die gesamte Migration rollt atomar zurück (supabase db push
-- fährt jede Migration in einer Transaktion). So kann keine Policy verloren
-- gehen. Idempotent: bereits verpackte Policies (`(select auth.…`) werden
-- übersprungen.
-- ════════════════════════════════════════════════════════════════════════

DO $rls$
DECLARE
  r record;
  v_using   text;
  v_check   text;
  v_roles   text;
  v_sql     text;
  v_before  int;
  v_after   int;
BEGIN
  SELECT count(*) INTO v_before FROM pg_policies WHERE schemaname = 'public';

  -- Stabiler Snapshot der zu ändernden Policies (verhindert Cursor-Instabilität
  -- während DROP/CREATE POLICY den Katalog ändert).
  CREATE TEMP TABLE _rls_rewrite ON COMMIT DROP AS
    SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ 'auth\.(uid|role|jwt)\(\)'
      -- case-insensitive: Postgres speichert verpackte Ausdrücke als "( SELECT
      -- auth.uid() …)" (Großschreibung) → ohne ~* würde ein Re-Run doppelt
      -- verpacken. So sind bereits optimierte Policies ausgeschlossen (idempotent).
      AND (coalesce(qual, '') || ' ' || coalesce(with_check, '')) !~* '\(\s*select\s+auth\.';

  FOR r IN SELECT * FROM _rls_rewrite LOOP
    v_using := r.qual;
    v_check := r.with_check;
    IF v_using IS NOT NULL THEN
      v_using := regexp_replace(v_using, 'auth\.(uid|role|jwt)\(\)', '(select auth.\1())', 'g');
    END IF;
    IF v_check IS NOT NULL THEN
      v_check := regexp_replace(v_check, 'auth\.(uid|role|jwt)\(\)', '(select auth.\1())', 'g');
    END IF;

    SELECT string_agg(CASE WHEN role = 'public' THEN 'public' ELSE quote_ident(role) END, ', ')
      INTO v_roles
      FROM unnest(r.roles) AS role;

    EXECUTE format('DROP POLICY %I ON %I.%I', r.policyname, r.schemaname, r.tablename);

    v_sql := format('CREATE POLICY %I ON %I.%I AS %s FOR %s TO %s',
                    r.policyname, r.schemaname, r.tablename, r.permissive, r.cmd, v_roles);
    IF v_using IS NOT NULL THEN v_sql := v_sql || format(' USING (%s)', v_using); END IF;
    IF v_check IS NOT NULL THEN v_sql := v_sql || format(' WITH CHECK (%s)', v_check); END IF;
    EXECUTE v_sql;
  END LOOP;

  SELECT count(*) INTO v_after FROM pg_policies WHERE schemaname = 'public';
  IF v_after <> v_before THEN
    RAISE EXCEPTION 'RLS-Rewrite: Policy-Anzahl verändert (vorher %, nachher %) — Abbruch & Rollback',
      v_before, v_after;
  END IF;

  RAISE NOTICE 'RLS-Initplan-Optimierung: % Policies geprüft, Anzahl stabil bei %', v_before, v_after;
END
$rls$;
