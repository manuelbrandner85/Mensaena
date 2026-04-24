#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Mensaena Push-Notification Setup Assistant
#
# Führt dich durch den einmaligen FCM-Setup:
# - GitHub-Secrets setzen (GOOGLE_SERVICES_JSON, SUPABASE_*)
# - GitHub-Variable setzen (SUPABASE_PROJECT_REF)
# - Supabase push_config für FCM befüllen (Project ID + Service Account JSON)
# - Migrations + Edge Function sofort deployen (statt auf nächsten Push warten)
#
# Vorausgesetzt / werden bei Bedarf installiert:
#   - GitHub CLI (gh)       – für Secrets + Variables
#   - Supabase CLI (supabase) – für DB + Functions
#   - jq                    – für JSON-Validierung
#
# Führ dieses Script einmal aus:
#   bash scripts/setup-push.sh
# ═══════════════════════════════════════════════════════════════════════════

set -Eeuo pipefail

# ── Styling ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_BOLD=$(printf '\033[1m'); C_DIM=$(printf '\033[2m'); C_RED=$(printf '\033[31m')
  C_GRN=$(printf '\033[32m'); C_YEL=$(printf '\033[33m'); C_CYA=$(printf '\033[36m')
  C_RST=$(printf '\033[0m')
else
  C_BOLD=''; C_DIM=''; C_RED=''; C_GRN=''; C_YEL=''; C_CYA=''; C_RST=''
fi

step()  { echo; echo "${C_BOLD}${C_CYA}▶ $*${C_RST}"; }
ok()    { echo "  ${C_GRN}✓${C_RST} $*"; }
warn()  { echo "  ${C_YEL}⚠${C_RST} $*"; }
fail()  { echo "  ${C_RED}✗${C_RST} $*"; }
info()  { echo "  ${C_DIM}$*${C_RST}"; }
ask()   { printf "  ${C_BOLD}?${C_RST} %s " "$1"; }

cd "$(dirname "$0")/.."
repo_root=$(pwd)

# ── Prereq check ─────────────────────────────────────────────────────────
step "Prerequisites checken"

need() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 vorhanden ($("$1" --version 2>&1 | head -1))"
  else
    fail "$1 fehlt."
    echo "    Installation:"
    case "$1" in
      gh) echo "      brew install gh  ODER  https://cli.github.com/" ;;
      supabase) echo "      brew install supabase/tap/supabase  ODER  https://supabase.com/docs/guides/local-development/cli/getting-started" ;;
      jq) echo "      brew install jq  ODER  apt-get install jq" ;;
    esac
    exit 1
  fi
}
need gh
need supabase
need jq

# ── GitHub Auth ──────────────────────────────────────────────────────────
step "GitHub CLI eingeloggt?"
if gh auth status >/dev/null 2>&1; then
  ok "eingeloggt als $(gh api user --jq .login)"
else
  warn "nicht eingeloggt. Login jetzt starten…"
  gh auth login
fi

# Repo-Kontext
repo_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "")
if [ -z "$repo_slug" ]; then
  ask "Repo-Slug (z.B. manuelbrandner85/Mensaena):"
  read -r repo_slug
fi
ok "Repository: $repo_slug"

# ── Firebase google-services.json ───────────────────────────────────────
step "Firebase: google-services.json"
info "Vorher einmalig anlegen:"
info "  1. https://console.firebase.google.com → Projekt hinzufügen"
info "  2. Android-App hinzufügen, Paket-ID 'de.mensaena.app'"
info "  3. google-services.json herunterladen → Pfad unten eingeben"

while :; do
  ask "Pfad zu google-services.json (leer zum Überspringen):"
  read -r gs_path
  gs_path="${gs_path/#\~/$HOME}"
  if [ -z "$gs_path" ]; then
    warn "Übersprungen – GitHub-Secret GOOGLE_SERVICES_JSON nicht gesetzt"
    break
  fi
  if [ ! -f "$gs_path" ]; then
    fail "Datei existiert nicht: $gs_path"
    continue
  fi
  if ! jq -e . "$gs_path" >/dev/null 2>&1; then
    fail "Keine valide JSON: $gs_path"
    continue
  fi
  pkg=$(jq -r '.client[0].client_info.android_client_info.package_name // "?"' "$gs_path")
  if [ "$pkg" != "de.mensaena.app" ]; then
    warn "Package-Name ist '$pkg' statt 'de.mensaena.app' – Android-Build wird fehlschlagen."
    ask "Trotzdem fortfahren? (y/N)"
    read -r conf
    [[ "$conf" =~ ^[yY]$ ]] || continue
  fi
  gh secret set GOOGLE_SERVICES_JSON --repo "$repo_slug" < "$gs_path"
  ok "Secret GOOGLE_SERVICES_JSON gesetzt"
  break
done

# ── Firebase Service Account ─────────────────────────────────────────────
step "Firebase: Service Account (für send-push Edge Function)"
info "Vorher einmalig anlegen:"
info "  Firebase Console → ⚙️ → Project settings → Service accounts"
info "  → 'Generate new private key' → JSON herunterladen"

fcm_project_id=""
fcm_sa_json=""
while :; do
  ask "Pfad zum Service-Account-JSON (leer zum Überspringen):"
  read -r sa_path
  sa_path="${sa_path/#\~/$HOME}"
  if [ -z "$sa_path" ]; then
    warn "Übersprungen – FCM-Push aus der Edge Function funktioniert noch nicht"
    break
  fi
  if [ ! -f "$sa_path" ]; then
    fail "Datei existiert nicht: $sa_path"
    continue
  fi
  if ! jq -e '.project_id and .private_key and .client_email' "$sa_path" >/dev/null 2>&1; then
    fail "JSON fehlen Felder (project_id / private_key / client_email)"
    continue
  fi
  fcm_project_id=$(jq -r .project_id "$sa_path")
  fcm_sa_json=$(cat "$sa_path")
  ok "Service Account gelesen (Projekt: $fcm_project_id)"
  break
done

# ── Supabase Token ───────────────────────────────────────────────────────
step "Supabase: Access Token"
info "Erstelle einen Token unter: https://supabase.com/dashboard/account/tokens"
ask "SUPABASE_ACCESS_TOKEN (sbp_...):"
read -rs sb_token; echo
if [ -n "$sb_token" ]; then
  echo -n "$sb_token" | gh secret set SUPABASE_ACCESS_TOKEN --repo "$repo_slug"
  ok "Secret SUPABASE_ACCESS_TOKEN gesetzt"
  export SUPABASE_ACCESS_TOKEN="$sb_token"
fi

# ── Supabase Project Ref ─────────────────────────────────────────────────
step "Supabase: Project Ref"
info "Steht im Dashboard-URL: https://supabase.com/dashboard/project/<REF>"
ask "SUPABASE_PROJECT_REF (z.B. huaqldjkgyosefzfhjnf):"
read -r sb_ref
if [ -n "$sb_ref" ]; then
  gh variable set SUPABASE_PROJECT_REF --repo "$repo_slug" --body "$sb_ref"
  ok "Variable SUPABASE_PROJECT_REF gesetzt"
fi

# ── Supabase DB Password ─────────────────────────────────────────────────
step "Supabase: DB-Passwort"
info "Dashboard → Project settings → Database → Connection string"
ask "SUPABASE_DB_PASSWORD:"
read -rs sb_pw; echo
if [ -n "$sb_pw" ]; then
  echo -n "$sb_pw" | gh secret set SUPABASE_DB_PASSWORD --repo "$repo_slug"
  ok "Secret SUPABASE_DB_PASSWORD gesetzt"
fi

# ── Link + Push + Deploy ─────────────────────────────────────────────────
if [ -n "${sb_token:-}" ] && [ -n "$sb_ref" ] && [ -n "${sb_pw:-}" ]; then
  step "Supabase linken + Migration sofort anwenden"
  supabase link --project-ref "$sb_ref" --password "$sb_pw" >/dev/null
  supabase db push --password "$sb_pw"
  ok "Migration 20260424190000_fcm_tokens.sql applied"

  # FCM Config in push_config schreiben (nur wenn Service Account vorhanden)
  if [ -n "$fcm_project_id" ] && [ -n "$fcm_sa_json" ]; then
    step "FCM-Config in push_config schreiben"
    escaped_json=$(printf '%s' "$fcm_sa_json" | sed "s/'/''/g")
    sql=$(cat <<EOF
UPDATE private.push_config SET value = '$fcm_project_id' WHERE key = 'fcm_project_id';
INSERT INTO private.push_config (key, value) VALUES ('fcm_project_id', '$fcm_project_id')
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

UPDATE private.push_config SET value = \$fcmjson\$$fcm_sa_json\$fcmjson\$ WHERE key = 'fcm_service_account_json';
INSERT INTO private.push_config (key, value) VALUES ('fcm_service_account_json', \$fcmjson\$$fcm_sa_json\$fcmjson\$)
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
EOF
)
    # Ausführen via supabase db execute – falls nicht vorhanden, psql-Fallback
    if supabase --help 2>&1 | grep -q "db execute"; then
      echo "$sql" | supabase db execute --password "$sb_pw"
    else
      warn "supabase db execute nicht verfügbar – SQL manuell ausführen:"
      echo "$sql"
    fi
    ok "FCM-Config gesetzt"
  fi

  step "Edge Function send-push deployen"
  supabase functions deploy send-push --no-verify-jwt
  ok "send-push live"
fi

# ── Summary ──────────────────────────────────────────────────────────────
step "Fertig 🎉"
echo
echo "${C_BOLD}Status:${C_RST}"
gh secret list --repo "$repo_slug" | grep -E "GOOGLE_SERVICES_JSON|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD" | sed 's/^/  /' || true
gh variable list --repo "$repo_slug" | grep -E "SUPABASE_PROJECT_REF" | sed 's/^/  /' || true
echo
echo "${C_BOLD}Nächster Schritt:${C_RST}"
echo "  Eine neue APK bauen lassen:"
echo "    gh workflow run android.yml --repo $repo_slug"
echo "  Oder einfach einen beliebigen Commit auf main pushen."
echo
echo "${C_DIM}Troubleshooting: docs/FCM_SETUP.md${C_RST}"
