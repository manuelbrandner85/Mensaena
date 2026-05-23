#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# setup-cloudflare-secrets.sh
#
# Konfiguriert alle benoetigten Cloudflare-Worker-Secrets fuer den
# Mensaena-Worker (deploy.yml + Production).
#
# Voraussetzung: `wrangler` CLI installiert + eingeloggt (wrangler login).
#
# Verwendung:
#   bash scripts/setup-cloudflare-secrets.sh
#
# Du wirst fuer jeden Secret einzeln nach dem Wert gefragt. Werte sind
# in 1Password / Cloudflare Dashboard zu finden.
# ════════════════════════════════════════════════════════════════════════
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v npx >/dev/null 2>&1; then
  echo "ERROR: npx nicht gefunden. Bitte Node.js installieren." >&2
  exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo " Cloudflare Worker Secrets — Mensaena"
echo "═══════════════════════════════════════════════════════"
echo
echo "Diese Secrets werden gesetzt:"
echo "  1. SUPABASE_SERVICE_ROLE_KEY  (von Supabase Dashboard → API)"
echo "  2. LIVEKIT_SELF_KEY            (von LiveKit Dashboard)"
echo "  3. LIVEKIT_SELF_SECRET         (von LiveKit Dashboard)"
echo
echo "Bei jedem Secret wirst du nach dem Wert gefragt. Eingaben sind"
echo "versteckt (kein Echo). Strg+C zum Abbrechen."
echo

setSecret() {
  local key="$1"
  echo
  echo "─── $key ───"
  npx wrangler secret put "$key"
}

setSecret SUPABASE_SERVICE_ROLE_KEY
setSecret LIVEKIT_SELF_KEY
setSecret LIVEKIT_SELF_SECRET

echo
echo "═══════════════════════════════════════════════════════"
echo " ✓ Fertig. Deploye neu mit: npx wrangler deploy --minify"
echo "═══════════════════════════════════════════════════════"
