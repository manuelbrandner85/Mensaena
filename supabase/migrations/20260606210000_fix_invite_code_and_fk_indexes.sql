-- ════════════════════════════════════════════════════════════════════════
-- Fix: "Nachbar einladen" defekt + App-weite Langsamkeit (FK-Indizes)
--
-- 1) referrals.invite_code war NOT NULL OHNE Default. Die App fügt beim Öffnen
--    des Einladen-Screens eine Zeile NUR mit inviter_id + status ein (ohne
--    invite_code) → Insert scheiterte immer mit NOT NULL (SQLSTATE 23502) →
--    Einladungslink/-feature kaputt. Ein Default repariert auch die bereits
--    installierte App sofort (kein App-Update nötig).
--
-- 2) Performance: 73 Foreign-Key-Spalten ohne deckenden Index (Supabase-
--    Advisor 0001). Fehlende FK-Indizes verlangsamen Joins, ON DELETE-Cascades
--    und RLS-Checks → trägt zur allgemeinen Langsamkeit bei. Self-healing
--    DO-Block: legt für jede FK-Spalte ohne führenden Index einen an.
-- ════════════════════════════════════════════════════════════════════════

-- 1) Invite-Code Default (8-stelliger Code, durch UNIQUE-Constraint geschützt)
ALTER TABLE public.referrals
  ALTER COLUMN invite_code
  SET DEFAULT upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

-- 2) Fehlende FK-Indizes idempotent anlegen.
DO $$
DECLARE r record; idxname text;
BEGIN
  FOR r IN
    SELECT c.conrelid::regclass AS tbl,
           replace(c.conrelid::regclass::text, 'public.', '') AS tname,
           a.attname AS col, a.attnum
    FROM pg_constraint c
    JOIN lateral unnest(c.conkey) AS k(attnum) ON true
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
    WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace
      AND NOT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indrelid = c.conrelid AND (i.indkey::int2[])[0] = k.attnum
      )
  LOOP
    idxname := left('idx_' || r.tname || '_' || r.col || '_fk', 63);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %s (%I)', idxname, r.tbl, r.col);
  END LOOP;
END $$;
