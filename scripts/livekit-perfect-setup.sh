#!/bin/bash
# Perfekt-Konfiguration LiveKit fuer Mensaena (Hostinger VPS)
# Behebt: Redis-Adresse falsch + Optimale Settings
set -e

LK_DIR="/docker/livekit"

if [ ! -d "$LK_DIR" ]; then
  echo "FEHLER: $LK_DIR nicht gefunden"; exit 1
fi

cd "$LK_DIR"

echo "=== 1. Backup ==="
cp livekit.yaml "livekit.yaml.bak.$(date +%Y%m%d-%H%M%S)"
ls -la *.bak.* 2>/dev/null | tail -3

echo ""
echo "=== 2. API-Keys aus aktueller Config extrahieren ==="
KEYS_BLOCK=$(awk '/^keys:/,/^[a-z]/' livekit.yaml | head -n -1)
if [ -z "$KEYS_BLOCK" ]; then
  echo "FEHLER: Keine API-Keys gefunden – Abbruch"
  exit 1
fi
echo "$KEYS_BLOCK" | head -5

echo ""
echo "=== 3. Optimale livekit.yaml schreiben ==="
cat > livekit.yaml <<EOF
# LiveKit Production Config – Mensaena
# Generiert: $(date)
# Doku: https://docs.livekit.io/home/self-hosting/deployment/

# Signalling-Port (intern, von Traefik via 443 WSS proxied)
port: 7880
bind_addresses:
  - ""

# Redis – Container-Name aus docker-compose, NICHT 127.0.0.1
# (LiveKit-Container kann Host nicht direkt erreichen)
redis:
  address: redis:6379

# API-Keys (UNVERAENDERT aus Backup)
$KEYS_BLOCK

# WebRTC Konfiguration
rtc:
  # TCP-Fallback fuer User hinter strenger Firewall
  tcp_port: 7881
  # UDP Media-Range (50000-60000 = 10000 Ports)
  port_range_start: 50000
  port_range_end: 60000
  # KRITISCH fuer NAT: erkennt automatisch externe IP
  use_external_ip: true
  # ICE-Lite aus = stabilere Verbindungen mit STUN/TURN-Hilfe
  use_ice_lite: false

# Raum-Defaults
room:
  auto_create: true
  empty_timeout: 300       # Raum schliesst nach 5min ohne Teilnehmer
  departure_timeout: 20    # Wartet 20s nach Disconnect (fuer Reconnect)
  max_participants: 100    # Hard-Limit pro Raum

# Logging
logging:
  level: info
  pion_level: error
  json: false

# Audio Voice-Activity-Detection
audio:
  active_level: 35
  min_score: 0.6
  smoothing_factor: 0.7

# Schutz vor Abuse
limit:
  num_tracks: -1
  bytes_per_sec: 0
  subscription_limit_video: 200
  subscription_limit_audio: 200
EOF
echo "✅ livekit.yaml geschrieben"

echo ""
echo "=== 4. Firewall – RTC TCP (7881) ist intern, muss NICHT raus ==="
echo "Nur 3478/UDP TURN ist offen (das genuegt fuer NAT-Traversal)"

echo ""
echo "=== 5. LiveKit + Redis Container neu starten ==="
docker compose down
docker compose up -d
sleep 8

echo ""
echo "=== 6. Status ==="
docker compose ps

echo ""
echo "=== 7. LiveKit Connectivity Test ==="
sleep 3
LIVEKIT_LOG=$(docker compose logs --tail=30 livekit 2>&1 || docker logs livekit-livekit-1 --tail=30 2>&1)
echo "$LIVEKIT_LOG" | tail -20

if echo "$LIVEKIT_LOG" | grep -qi "error.*redis\|redis.*error\|connection refused"; then
  echo ""
  echo "⚠️  REDIS-FEHLER erkannt! Pruefe Container-Namen:"
  docker compose ps | grep redis
  echo ""
  echo "Falls 'redis' nicht funktioniert, alternativ versuchen:"
  echo "  redis: address: livekit-redis-1:6379"
fi

echo ""
echo "✅ Setup fertig!"
echo ""
echo "Test in der App:"
echo "  1. DM-Anruf starten/annehmen"
echo "  2. Community-Livestream starten"
echo "  3. Kamera ein/aus, Mikro ein/aus"
