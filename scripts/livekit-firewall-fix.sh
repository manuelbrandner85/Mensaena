#!/bin/bash
# Oeffnet die WebRTC UDP-Ports (50000-60000) in der Hostinger Firewall
# Wichtig: Diese Ports sind fuer LiveKit Media-Streams (Audio/Video).
# Ohne offene Ports: 'Verbinde...' haengt, weil ICE-Verbindung nicht klappt.
set -e

HOSTINGER_TOKEN="XD4oRJobX0xCtStGQKq0OoEAqHgAPoOYLq7WZyfI426dcdaf"
API_BASE="https://developers.hostinger.com/api"

echo "=== 1. UFW (lokal) – UDP-Range oeffnen ==="
ufw allow 50000:60000/udp comment 'LiveKit WebRTC Media' 2>/dev/null || true
ufw allow 7881/tcp comment 'LiveKit RTC TCP' 2>/dev/null || true
ufw allow 3478/udp comment 'TURN UDP' 2>/dev/null || true
echo "UFW-Regeln gesetzt:"
ufw status | grep -E "50000|7881|3478" | head -5

echo ""
echo "=== 2. Hostinger API – VPS-ID ermitteln ==="
LIST=$(curl -sf -H "Authorization: Bearer $HOSTINGER_TOKEN" \
  "$API_BASE/vps/v1/virtual-machines" 2>/dev/null || \
  curl -sf -H "Authorization: Bearer $HOSTINGER_TOKEN" \
  "https://api.hostinger.com/v1/vps/virtual-machines" 2>/dev/null || echo '{}')

VPS_ID=$(echo "$LIST" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    vms = d if isinstance(d, list) else d.get('data', [])
    for vm in vms:
        ip = vm.get('ip_address', '')
        ip_addresses = vm.get('ip_addresses', [])
        if ip == '72.62.154.95':
            print(vm.get('id', '')); sys.exit()
        if isinstance(ip_addresses, list):
            for ipo in ip_addresses:
                addr = ipo.get('address') if isinstance(ipo, dict) else ipo
                if addr == '72.62.154.95':
                    print(vm.get('id', '')); sys.exit()
except: pass
" 2>/dev/null)

echo "VPS_ID: $VPS_ID"

if [ -z "$VPS_ID" ]; then
  echo ""
  echo "⚠️  Konnte VPS-ID nicht ermitteln via API."
  echo ""
  echo "MANUELL im hPanel hinzufuegen:"
  echo "  hPanel → VPS → Firewall → Regel hinzufuegen:"
  echo "    Protokoll: UDP, Port: 50000-60000, Source: 0.0.0.0/0"
  echo "    Protokoll: UDP, Port: 3478, Source: 0.0.0.0/0  (falls noch nicht da)"
  echo ""
  echo "Lokale UFW ist bereits konfiguriert. Wenn Hostinger-Firewall blockiert,"
  echo "sind die Ports immer noch von aussen unerreichbar."
  exit 1
fi

echo ""
echo "=== 3. Firewall-Regeln via API hinzufuegen ==="

# Endpunkt-Variante 1
add_rule() {
  local proto="$1"
  local port="$2"
  local src="$3"
  local desc="$4"

  # Versuche verschiedene API-Endpunkt-Varianten
  for ep in \
    "$API_BASE/vps/v1/virtual-machines/$VPS_ID/firewall" \
    "https://api.hostinger.com/v1/vps/virtual-machines/$VPS_ID/firewall" \
    "$API_BASE/vps/v1/virtual-machines/$VPS_ID/firewall/rules"
  do
    R=$(curl -sf -X POST \
      -H "Authorization: Bearer $HOSTINGER_TOKEN" \
      -H "Content-Type: application/json" \
      "$ep" \
      -d "{\"protocol\":\"$proto\",\"port\":\"$port\",\"source\":\"$src\",\"action\":\"ACCEPT\",\"description\":\"$desc\"}" \
      2>/dev/null && echo OK || echo FAIL)
    if [ "$R" = "OK" ]; then
      echo "  ✅ $proto $port von $src ($ep)"
      return 0
    fi
  done
  echo "  ⚠️  $proto $port konnte nicht via API gesetzt werden"
  return 1
}

add_rule "UDP" "50000-60000" "0.0.0.0/0" "LiveKit WebRTC Media"
add_rule "UDP" "3478"        "0.0.0.0/0" "TURN UDP"
add_rule "TCP" "7881"        "0.0.0.0/0" "LiveKit RTC TCP"

echo ""
echo "=== 4. LiveKit Status ==="
docker compose -f /docker/livekit/docker-compose.yaml ps 2>/dev/null || docker ps | grep livekit

echo ""
echo "✅ Fertig!"
echo ""
echo "Falls API nicht alle Regeln setzen konnte, MANUELL im hPanel:"
echo "  Protokoll: UDP, Port: 50000-60000, Source: 0.0.0.0/0"
echo ""
echo "Dann teste den Livestream/Anruf erneut."
