#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# setup-livekit-secrets.sh
#
# One-Shot: Konfiguriert alle benoetigten LiveKit-Secrets an ALLEN noetigen
# Stellen (Cloudflare Worker UND Supabase Edge Function). Nach dem Lauf
# sind Audio-/Video-Calls + Channel-Livestreams sofort funktional.
#
# Voraussetzungen:
#   - wrangler CLI installiert + eingeloggt (npx wrangler login)
#   - supabase CLI installiert + eingeloggt (npx supabase login)
#   - LiveKit-Server laeuft auf wss://livekit.mensaena.de
#
# Verwendung:
#   bash scripts/setup-livekit-secrets.sh
#
# Du wirst nach dem KEY-Namen und dem SECRET-Wert gefragt (siehe
# /docker/livekit*/livekit.yaml auf Hostinger VPS 72.62.154.95).
# ════════════════════════════════════════════════════════════════════════
set -euo pipefail

SUPABASE_PROJECT_REF="gyqujitkvymlmgroovch"
LIVEKIT_SERVER_URL="wss://livekit.mensaena.de"
LIVEKIT_HTTP_URL="https://livekit.mensaena.de"

cd "$(dirname "$0")/.."

if ! command -v npx >/dev/null 2>&1; then
  echo "ERROR: npx nicht gefunden. Bitte Node.js installieren." >&2
  exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo "  LiveKit-Secrets Setup — Mensaena"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Werte holen via:"
echo "  ssh user@72.62.154.95"
echo "  sudo cat /docker/livekit*/livekit.yaml | grep -A2 'keys:'"
echo ""
echo "Format ist:"
echo "  keys:"
echo "    <KEY-NAME>: <SECRET-WERT>"
echo ""

read -p "LIVEKIT_SELF_KEY (der Key-Name, z.B. 'mensaena-abc123'): " KEY
read -s -p "LIVEKIT_SELF_SECRET (der Wert hinter dem Key, versteckt): " SECRET
echo ""
echo ""

if [ -z "$KEY" ] || [ -z "$SECRET" ]; then
  echo "❌ Beide Werte sind erforderlich. Abbruch." >&2
  exit 1
fi

# ── 1. Verifikation gegen LiveKit-Server ──────────────────────────────────
echo "── 1/3: Verifiziere Werte gegen LiveKit-Server ──"

VERIFY_RESULT=$(node -e "
const crypto = require('crypto');
const KEY = '$KEY';
const SECRET = '$SECRET';
const url = '$LIVEKIT_HTTP_URL';
const b64 = (s) => Buffer.from(s).toString('base64').replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const h = b64(JSON.stringify({alg:'HS256',typ:'JWT'}));
const now = Math.floor(Date.now()/1000);
const p = b64(JSON.stringify({iss:KEY,sub:'verify',iat:now,nbf:now,exp:now+60,video:{roomJoin:true,room:'verify'}}));
const s = crypto.createHmac('sha256',SECRET).update(h+'.'+p).digest('base64').replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
const token = h+'.'+p+'.'+s;
fetch(url+'/twirp/livekit.RoomService/ListRooms', {
  method:'POST',headers:{'Authorization':'Bearer '+token,'Content-Type':'application/json'},body:'{}'
}).then(r => r.text()).then(t => console.log(r.status+'|'+t)).catch(e => console.log('ERR|'+e.message));
" 2>&1)

if [[ "$VERIFY_RESULT" == *"invalid API key"* ]]; then
  echo "❌ LiveKit-Server kennt KEY '$KEY' nicht."
  echo "   Pruefe /docker/livekit*/livekit.yaml auf dem VPS."
  exit 1
fi

if [[ "$VERIFY_RESULT" == *"permissions denied"* ]] || [[ "$VERIFY_RESULT" == *"invalid signature"* ]]; then
  echo "❌ SECRET passt nicht zum KEY '$KEY'."
  echo "   Pruefe ob beide Werte korrekt copy-pasted sind."
  exit 1
fi

echo "✓ LiveKit-Server akzeptiert Token (KEY+SECRET valide)"
echo ""

# ── 2. Push nach Supabase Edge Function ───────────────────────────────────
echo "── 2/3: Push nach Supabase Edge Function ──"
npx supabase secrets set \
  --project-ref "$SUPABASE_PROJECT_REF" \
  LIVEKIT_SELF_KEY="$KEY" \
  LIVEKIT_SELF_SECRET="$SECRET" \
  LIVEKIT_SELF_URL="$LIVEKIT_SERVER_URL"

echo ""

# ── 3. Push nach Cloudflare Worker ────────────────────────────────────────
echo "── 3/3: Push nach Cloudflare Worker ──"
echo "$KEY"    | npx wrangler secret put LIVEKIT_SELF_KEY    --name mensaena
echo "$SECRET" | npx wrangler secret put LIVEKIT_SELF_SECRET --name mensaena

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✓ Fertig — Calls + Livestream sind aktiv"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Verifikation:"
echo "  curl -X POST 'https://${SUPABASE_PROJECT_REF}.supabase.co/functions/v1/livekit-token?check=1' \\"
echo "    -H 'Content-Type: application/json' -d '{}'"
echo ""
echo "Soll zeigen: \"has_key\":true,\"has_secret\":true"
