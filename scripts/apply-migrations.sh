#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# apply-migrations.sh – Wendet ausstehende Supabase-Migrationen automatisch an
#
# Tracking:   public._migration_history  (wird automatisch angelegt)
# Erstlauf:   Alle Migrationen werden versucht; Fehler bei bereits vorhandenen
#             Objekten werden ignoriert (DB ist bereits im richtigen Zustand).
#             Jede Datei wird als "baseline" markiert.
# Folgeläufe: Nur neue Dateien (nicht in _migration_history) werden angewendet.
#             Fehler erzeugen einen CI-Fehler.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DB_URL="${DATABASE_URL:?DATABASE_URL env var must be set}"

echo "==> Supabase Migration Runner"
echo "==> Verbinde mit Datenbank..."

# ── Tracking-Tabelle anlegen ──────────────────────────────────────────────────
psql "$DB_URL" -c "
CREATE TABLE IF NOT EXISTS public._migration_history (
  filename   TEXT        PRIMARY KEY,
  status     TEXT        NOT NULL DEFAULT 'applied',  -- 'baseline' | 'applied'
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);" > /dev/null

# ── Erstlauf erkennen ─────────────────────────────────────────────────────────
IS_FIRST_RUN=$(psql "$DB_URL" -t -A -c "SELECT (COUNT(*) = 0)::text FROM public._migration_history;")

if [ "$IS_FIRST_RUN" = "true" ]; then
  echo "==> Erstlauf erkannt – Baseline wird eingerichtet (Fehler werden ignoriert)"
fi

APPLIED=0
SKIPPED=0

# Dateien alphabetisch sortiert verarbeiten (entspricht chronologischer Reihenfolge)
for f in $(find supabase/migrations -maxdepth 1 -name "*.sql" | sort); do
  filename=$(basename "$f")

  # Bereits angewendet?
  in_history=$(psql "$DB_URL" -t -A -c \
    "SELECT COUNT(*) FROM public._migration_history WHERE filename = '${filename}';")
  if [ "$in_history" != "0" ]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "--> Wende an: $filename"

  if [ "$IS_FIRST_RUN" = "true" ]; then
    # Erstlauf: Fehler tolerieren (Objekte möglicherweise bereits vorhanden)
    psql "$DB_URL" -f "$f" 2>&1 || echo "    ⚠ Hinweis: Datei hatte Fehler – wird trotzdem als baseline markiert"
    psql "$DB_URL" -c \
      "INSERT INTO public._migration_history (filename, status) VALUES ('${filename}', 'baseline') ON CONFLICT DO NOTHING;" > /dev/null
    echo "    ✓ Baseline: $filename"
  else
    # Normaler Lauf: Fehler brechen CI ab
    psql "$DB_URL" -f "$f"
    psql "$DB_URL" -c \
      "INSERT INTO public._migration_history (filename, status) VALUES ('${filename}', 'applied') ON CONFLICT DO NOTHING;" > /dev/null
    echo "    ✓ Angewendet: $filename"
  fi

  APPLIED=$((APPLIED + 1))
done

echo "==> Fertig: ${APPLIED} angewendet, ${SKIPPED} übersprungen"
