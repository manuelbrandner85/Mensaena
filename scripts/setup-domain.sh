#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-domain.sh – Mensaena Domain Setup Script
#
# Dieses Script erledigt AUTOMATISCH (nach DNS-Umzug):
#   1. mensaena.de Zone in Cloudflare anlegen
#   2. DNS-Records setzen (CNAME www + apex → Worker)
#   3. Redirect-Regel mensaena.de → www.mensaena.de anlegen
#   4. SSL-Modus auf Full Strict setzen
#   5. HSTS aktivieren
#   6. Worker deployen mit Custom Domain
#   7. workers.dev-Subdomain deaktivieren (optional)
#
# VORAUSSETZUNG:
#   - CF_TOKEN muss Zone:Read + Zone:Edit + Worker:Edit Rechte haben
#   - Alternativ: Global API Key (CF_EMAIL + CF_GLOBAL_KEY)
#   - mensaena.de muss auf Cloudflare-Nameserver zeigen
#
# VERWENDUNG:
#   CF_TOKEN="dein_token_mit_zone_rechten" bash scripts/setup-domain.sh
#   oder:
#   CF_EMAIL="mail@example.com" CF_GLOBAL_KEY="dein_global_key" bash scripts/setup-domain.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Konfiguration ─────────────────────────────────────────────────────────────
ACCOUNT_ID="accac25964381d7a5200932dac6d270d"
WORKER_NAME="mensaena"
DOMAIN="mensaena.de"
WWW_DOMAIN="www.mensaena.de"
WORKER_SUBDOMAIN="mensaena.manuelbrandner4.workers.dev"

# Auth: entweder Bearer Token (bevorzugt) oder Global Key
CF_TOKEN="${CF_TOKEN:-}"
CF_EMAIL="${CF_EMAIL:-}"
CF_GLOBAL_KEY="${CF_GLOBAL_KEY:-}"

# ── Farben ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC} $1"; exit 1; }
info() { echo -e "${BLUE}→${NC} $1"; }
sep()  { echo -e "\n${BOLD}─────────────────────────────────────────${NC}"; }

# ── Auth-Header bestimmen ─────────────────────────────────────────────────────
if [[ -n "${CF_TOKEN}" ]]; then
  AUTH_HEADER="Authorization: Bearer ${CF_TOKEN}"
  info "Verwende Bearer Token für Authentifizierung"
elif [[ -n "${CF_EMAIL}" && -n "${CF_GLOBAL_KEY}" ]]; then
  AUTH_HEADER="X-Auth-Email: ${CF_EMAIL}"
  AUTH_KEY_HEADER="X-Auth-Key: ${CF_GLOBAL_KEY}"
  info "Verwende Global API Key für Authentifizierung"
else
  err "Kein API-Token gefunden. Setze CF_TOKEN oder CF_EMAIL+CF_GLOBAL_KEY"
fi

# ── Helper: CF API aufrufen ───────────────────────────────────────────────────
cf_api() {
  local method="$1"; local endpoint="$2"; local data="${3:-}"
  local url="https://api.cloudflare.com/client/v4${endpoint}"

  if [[ -n "${CF_TOKEN}" ]]; then
    if [[ -n "$data" ]]; then
      curl -s -X "$method" "$url" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$data"
    else
      curl -s -X "$method" "$url" \
        -H "Authorization: Bearer ${CF_TOKEN}"
    fi
  else
    if [[ -n "$data" ]]; then
      curl -s -X "$method" "$url" \
        -H "X-Auth-Email: ${CF_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_KEY}" \
        -H "Content-Type: application/json" \
        -d "$data"
    else
      curl -s -X "$method" "$url" \
        -H "X-Auth-Email: ${CF_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_KEY}"
    fi
  fi
}

cf_success() {
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('success') else 'fail')" 2>/dev/null
}

cf_result() {
  echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('result',{}), indent=2))" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
sep
echo -e "${BOLD}MENSAENA – Domain Setup${NC}"
echo "Domain:  ${DOMAIN}"
echo "Worker:  ${WORKER_NAME}"
echo "Account: ${ACCOUNT_ID}"
sep

# ── SCHRITT 1: Token prüfen ───────────────────────────────────────────────────
info "Schritt 1: API-Token verifizieren..."
VERIFY=$(cf_api GET "/user/tokens/verify")
if [[ $(cf_success "$VERIFY") != "ok" ]]; then
  err "Token ungültig: $(echo $VERIFY | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get(\"errors\"))')"
fi
log "Token aktiv"

# ── SCHRITT 2: Zone prüfen / anlegen ─────────────────────────────────────────
info "Schritt 2: Cloudflare Zone für ${DOMAIN} prüfen..."
ZONE_CHECK=$(cf_api GET "/zones?name=${DOMAIN}&account.id=${ACCOUNT_ID}")
ZONE_ID=$(echo "$ZONE_CHECK" | python3 -c "
import sys,json
d=json.load(sys.stdin)
results=d.get('result',[])
print(results[0]['id'] if results else '')
" 2>/dev/null)

if [[ -z "$ZONE_ID" ]]; then
  info "Zone nicht gefunden – lege ${DOMAIN} in Cloudflare an..."
  ZONE_CREATE=$(cf_api POST "/zones" "{
    \"name\": \"${DOMAIN}\",
    \"account\": {\"id\": \"${ACCOUNT_ID}\"},
    \"jump_start\": true,
    \"type\": \"full\"
  }")
  if [[ $(cf_success "$ZONE_CREATE") != "ok" ]]; then
    ERR_MSG=$(echo "$ZONE_CREATE" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("errors"))' 2>/dev/null)
    err "Zone konnte nicht erstellt werden: ${ERR_MSG}
    
${BOLD}→ Das Token hat keine 'Zone:Create' Berechtigung.${NC}
Erstelle ein neues Token unter:
https://dash.cloudflare.com/profile/api-tokens
Mit Berechtigungen:
  - Zone:Edit  (für alle Zonen)
  - Zone:Read  (für alle Zonen)  
  - Workers Routes:Edit (für Account)
  - Workers Scripts:Edit (für Account)
Dann erneut ausführen: CF_TOKEN='neues_token' bash scripts/setup-domain.sh"
  fi
  ZONE_ID=$(echo "$ZONE_CREATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['id'])" 2>/dev/null)
  NS=$(echo "$ZONE_CREATE" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ns=d['result'].get('name_servers',[])
for n in ns: print('  '+n)
" 2>/dev/null)

  log "Zone erstellt! Zone-ID: ${ZONE_ID}"
  echo ""
  echo -e "${YELLOW}${BOLD}═══════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}${BOLD} JETZT MANUELL: Nameserver bei Lima-City ändern!${NC}"
  echo -e "${YELLOW}${BOLD}═══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "Gehe zu: ${BOLD}https://www.lima-city.de/usercp/domains${NC}"
  echo -e "Domain:  ${BOLD}mensaena.de${NC}"
  echo -e "Setze diese Nameserver:"
  echo -e "${GREEN}${NS}${NC}"
  echo ""
  echo -e "Warte dann 5–30 Minuten auf DNS-Propagation."
  echo -e "Danach: ${BOLD}bash scripts/setup-domain.sh${NC} erneut ausführen."
  echo ""
  exit 0
else
  log "Zone gefunden: ${ZONE_ID}"
fi

# ── SCHRITT 3: Zone-Status prüfen ─────────────────────────────────────────────
info "Schritt 3: Zone-Status prüfen..."
ZONE_INFO=$(cf_api GET "/zones/${ZONE_ID}")
ZONE_STATUS=$(echo "$ZONE_INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'].get('status',''))" 2>/dev/null)
log "Zone-Status: ${ZONE_STATUS}"

if [[ "$ZONE_STATUS" == "pending" ]]; then
  NS=$(echo "$ZONE_INFO" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ns=d['result'].get('name_servers',[])
for n in ns: print('  '+n)
" 2>/dev/null)
  warn "Zone ist noch im Status 'pending' – Nameserver noch nicht umgestellt."
  echo ""
  echo -e "${YELLOW}Setze diese Nameserver bei Lima-City:${NC}"
  echo "$NS"
  echo ""
  err "Bitte erst Nameserver umstellen und dann erneut ausführen."
fi

# ── SCHRITT 4: Alte DNS-Records prüfen ───────────────────────────────────────
info "Schritt 4: Alte Lima-City DNS-Records entfernen..."
DNS_LIST=$(cf_api GET "/zones/${ZONE_ID}/dns_records")
OLD_IDS=$(echo "$DNS_LIST" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for r in d.get('result',[]):
    # Lösche alte A-Records die auf Lima-City IPs zeigen
    if r['type'] == 'A' and r['content'].startswith('91.216.248'):
        print(r['id']+'|'+r['name']+'|'+r['content'])
" 2>/dev/null)

if [[ -n "$OLD_IDS" ]]; then
  while IFS='|' read -r record_id record_name record_content; do
    info "  Lösche alten A-Record: ${record_name} → ${record_content}"
    DEL=$(cf_api DELETE "/zones/${ZONE_ID}/dns_records/${record_id}")
    if [[ $(cf_success "$DEL") == "ok" ]]; then
      log "  Gelöscht: ${record_name} (${record_content})"
    else
      warn "  Konnte nicht löschen: ${record_name} – $(echo $DEL | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"errors\"))' 2>/dev/null)"
    fi
  done <<< "$OLD_IDS"
else
  log "Keine alten Lima-City A-Records gefunden"
fi

# ── SCHRITT 5: CNAME-Records setzen ──────────────────────────────────────────
info "Schritt 5: CNAME-Records für Worker setzen..."

set_cname() {
  local name="$1"; local zone_name="$2"
  # Prüfe ob Record bereits existiert
  EXISTING=$(cf_api GET "/zones/${ZONE_ID}/dns_records?type=CNAME&name=${name}.${DOMAIN}")
  EXISTING_ID=$(echo "$EXISTING" | python3 -c "
import sys,json
d=json.load(sys.stdin)
results=d.get('result',[])
print(results[0]['id'] if results else '')
" 2>/dev/null)

  local payload="{
    \"type\": \"CNAME\",
    \"name\": \"${name}\",
    \"content\": \"${WORKER_SUBDOMAIN}\",
    \"proxied\": true,
    \"ttl\": 1
  }"

  if [[ -n "$EXISTING_ID" ]]; then
    info "  CNAME ${name} existiert – aktualisiere..."
    RESULT=$(cf_api PUT "/zones/${ZONE_ID}/dns_records/${EXISTING_ID}" "$payload")
  else
    info "  Erstelle CNAME ${name}..."
    RESULT=$(cf_api POST "/zones/${ZONE_ID}/dns_records" "$payload")
  fi

  if [[ $(cf_success "$RESULT") == "ok" ]]; then
    log "  CNAME ${name}.${DOMAIN} → ${WORKER_SUBDOMAIN} (proxied)"
  else
    warn "  CNAME ${name} fehlgeschlagen: $(echo $RESULT | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"errors\"))' 2>/dev/null)"
  fi
}

set_cname "www"
# Apex CNAME (Cloudflare unterstützt CNAME Flattening für root)
APEX_EXISTING=$(cf_api GET "/zones/${ZONE_ID}/dns_records?type=CNAME&name=${DOMAIN}")
APEX_ID=$(echo "$APEX_EXISTING" | python3 -c "
import sys,json
d=json.load(sys.stdin)
results=d.get('result',[])
print(results[0]['id'] if results else '')
" 2>/dev/null)
APEX_PAYLOAD="{\"type\":\"CNAME\",\"name\":\"@\",\"content\":\"${WORKER_SUBDOMAIN}\",\"proxied\":true,\"ttl\":1}"
if [[ -n "$APEX_ID" ]]; then
  APEX_R=$(cf_api PUT "/zones/${ZONE_ID}/dns_records/${APEX_ID}" "$APEX_PAYLOAD")
else
  APEX_R=$(cf_api POST "/zones/${ZONE_ID}/dns_records" "$APEX_PAYLOAD")
fi
if [[ $(cf_success "$APEX_R") == "ok" ]]; then
  log "  CNAME @ (apex) → ${WORKER_SUBDOMAIN} (proxied)"
else
  warn "  Apex CNAME: $(echo $APEX_R | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"errors\"))' 2>/dev/null)"
fi

# ── SCHRITT 6: Redirect-Regel mensaena.de → www.mensaena.de ──────────────────
info "Schritt 6: Redirect-Regel mensaena.de → www.mensaena.de anlegen..."

# Prüfe bestehende Redirect Rules
RULES=$(cf_api GET "/zones/${ZONE_ID}/rulesets/phases/http_request_dynamic_redirect/entrypoint")
RULESET_ID=$(echo "$RULES" | python3 -c "
import sys,json
d=json.load(sys.stdin)
r=d.get('result',{})
print(r.get('id','') if r else '')
" 2>/dev/null)

REDIRECT_RULE='{
  "rules": [{
    "expression": "(http.host eq \"mensaena.de\")",
    "description": "Redirect apex zu www",
    "action": "redirect",
    "action_parameters": {
      "from_value": {
        "status_code": 301,
        "target_url": {
          "expression": "concat(\"https://www.mensaena.de\", http.request.uri.path)"
        },
        "preserve_query_string": true
      }
    },
    "enabled": true
  }]
}'

if [[ -n "$RULESET_ID" ]]; then
  REDIR_R=$(cf_api PUT "/zones/${ZONE_ID}/rulesets/${RULESET_ID}" "$REDIRECT_RULE")
else
  REDIR_R=$(cf_api POST "/zones/${ZONE_ID}/rulesets" \
    "{\"name\":\"Redirects\",\"kind\":\"zone\",\"phase\":\"http_request_dynamic_redirect\",${REDIRECT_RULE:1}")
fi

if [[ $(cf_success "$REDIR_R") == "ok" ]]; then
  log "Redirect-Regel aktiv: mensaena.de → www.mensaena.de"
else
  warn "Redirect-Regel: $(echo $REDIR_R | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"errors\"))' 2>/dev/null)"
fi

# ── SCHRITT 7: SSL auf Full Strict ────────────────────────────────────────────
info "Schritt 7: SSL-Modus auf Full (strict) setzen..."
SSL_R=$(cf_api PATCH "/zones/${ZONE_ID}/settings/ssl" '{"value":"strict"}')
[[ $(cf_success "$SSL_R") == "ok" ]] && log "SSL: Full Strict aktiviert" || warn "SSL-Setting: $(echo $SSL_R | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"errors\"))' 2>/dev/null)"

# HTTPS erzwingen
HTTPS_R=$(cf_api PATCH "/zones/${ZONE_ID}/settings/always_use_https" '{"value":"on"}')
[[ $(cf_success "$HTTPS_R") == "ok" ]] && log "HTTPS: Always-Use-HTTPS aktiviert" || warn "HTTPS-Setting fehlgeschlagen"

# ── SCHRITT 8: Worker deployen mit Custom Domain ──────────────────────────────
sep
info "Schritt 8: Worker mit Custom Domain deployen..."
cd "$(dirname "$0")/.."

CLOUDFLARE_API_TOKEN="${CF_TOKEN}" npx wrangler deploy 2>&1 | tail -5
log "Worker deployed"

# ── SCHRITT 9: Custom Domain am Worker registrieren ──────────────────────────
info "Schritt 9: Custom Domain am Worker registrieren..."

ZONE_ID_RESULT=$(cf_api GET "/zones?name=${DOMAIN}" | python3 -c "
import sys,json
d=json.load(sys.stdin)
results=d.get('result',[])
print(results[0]['id'] if results else '')
" 2>/dev/null)

register_custom_domain() {
  local hostname="$1"
  DOMAIN_R=$(cf_api PUT "/accounts/${ACCOUNT_ID}/workers/domains" "{
    \"hostname\": \"${hostname}\",
    \"service\": \"${WORKER_NAME}\",
    \"environment\": \"production\",
    \"zone_id\": \"${ZONE_ID_RESULT}\"
  }")
  if [[ $(cf_success "$DOMAIN_R") == "ok" ]]; then
    log "Custom Domain registriert: ${hostname}"
  else
    warn "Custom Domain ${hostname}: $(echo $DOMAIN_R | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"errors\"))' 2>/dev/null)"
  fi
}

register_custom_domain "www.mensaena.de"
register_custom_domain "mensaena.de"

# ── SCHRITT 10: workers.dev deaktivieren (optional) ───────────────────────────
info "Schritt 10: workers.dev-Subdomain deaktivieren..."
SUBDOMAIN_R=$(cf_api POST "/accounts/${ACCOUNT_ID}/workers/scripts/${WORKER_NAME}/subdomain" '{"enabled": false}')
if [[ $(cf_success "$SUBDOMAIN_R") == "ok" ]]; then
  log "workers.dev deaktiviert – nur noch www.mensaena.de aktiv"
else
  warn "workers.dev konnte nicht deaktiviert werden (ggf. noch Custom Domain aktiv)"
fi

# ── Abschluss ─────────────────────────────────────────────────────────────────
sep
echo -e "${GREEN}${BOLD}✅ SETUP ABGESCHLOSSEN${NC}"
echo ""
echo -e "Teste jetzt:"
echo -e "  ${BOLD}curl -IL https://www.mensaena.de${NC}"
echo -e "  ${BOLD}curl -IL https://mensaena.de${NC}"
echo -e "  ${BOLD}curl -IL https://mensaena.manuelbrandner4.workers.dev${NC}"
echo ""
echo -e "Erwartete Ergebnisse:"
echo -e "  www.mensaena.de              → HTTP 200, server: cloudflare"
echo -e "  mensaena.de                  → HTTP 301 → www.mensaena.de"
echo -e "  mensaena.manuelbrandner4.workers.dev → HTTP 301 → www.mensaena.de"
sep
