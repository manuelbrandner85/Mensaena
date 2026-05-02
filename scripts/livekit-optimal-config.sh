#!/bin/bash
# Optimale LiveKit-Konfiguration für Mensaena
# Behebt alle bekannten Issues und optimiert fuer Production
set -e

LK_DIR="/docker/livekit"

if [ ! -d "$LK_DIR" ]; then
  echo "FEHLER: $LK_DIR nicht gefunden. LiveKit-Pfad anpassen."
  exit 1
fi

echo "=== LiveKit Optimal-Konfiguration ==="
echo ""

# Backup
cp "$LK_DIR/livekit.yaml" "$LK_DIR/livekit.yaml.bak.$(date +%s)"
echo "Backup: $LK_DIR/livekit.yaml.bak.$(date +%s)"

# Existierende Keys auslesen (NICHT ueberschreiben!)
KEYS=$(grep -A 5 "^keys:" "$LK_DIR/livekit.yaml" | head -20 | grep -E "^  [a-zA-Z0-9_-]+:")

if [ -z "$KEYS" ]; then
  echo "FEHLER: Keine API-Keys in livekit.yaml gefunden – Abbruch"
  exit 1
fi

echo "Behalte vorhandene Keys."

# Optimierte Config schreiben
cat > "$LK_DIR/livekit.yaml" <<EOF
# LiveKit Production Config – optimiert fuer Mensaena
# Generiert: $(date)

port: 7880
bind_addresses:
  - ""

# Redis fuer Multi-Node + State (Container-Name, NICHT 127.0.0.1)
redis:
  address: redis:6379

# API-Keys (aus Backup uebernommen)
keys:
$KEYS

# WebRTC Konfiguration
rtc:
  # TCP-Fallback fuer User hinter strenger Firewall
  tcp_port: 7881
  # UDP Media-Range (50000-60000 = 10000 Ports = bis zu 5000 Streams)
  port_range_start: 50000
  port_range_end: 60000
  # KRITISCH: ueberschreibt internal-IP mit External (NAT-Traversal)
  use_external_ip: true
  # ICE-Lite-Mode (schneller Connect, da LiveKit als reflexive Address agiert)
  use_ice_lite: false

# Raum-Defaults
room:
  auto_create: true
  empty_timeout: 300        # Raum schliesst nach 5min ohne Teilnehmer
  departure_timeout: 20     # Wartet 20s nach letztem Disconnect
  max_participants: 100     # Hard-Limit pro Raum

# Logging
logging:
  level: info
  pion_level: error
  json: false

# Webhook (optional – fuer Monitoring/Analytics)
# webhook:
#   api_key: <key-name-from-keys-above>
#   urls:
#     - https://www.mensaena.de/api/livekit/webhook

# Audio-Sample-Rate (48kHz = HiFi, Standard)
audio:
  active_level: 35
  min_score: 0.6
  smoothing_factor: 0.7

# Limits zum Schutz vor Abuse
limit:
  num_tracks: -1                     # unlimited
  bytes_per_sec: 0                   # unlimited (lokales Netz)
  subscription_limit_video: 200
  subscription_limit_audio: 200
EOF

echo "✅ livekit.yaml geschrieben"
echo ""

echo "=== Firewall – RTC TCP (7881) auch oeffnen ==="
ufw allow 7881/tcp comment 'LiveKit RTC TCP' 2>/dev/null || true

echo ""
echo "=== LiveKit + Redis Container neu starten ==="
cd "$LK_DIR"
docker compose down
docker compose up -d
sleep 8

echo ""
echo "=== Status ==="
docker compose ps
echo ""
echo "=== Log (letzte 20 Zeilen) ==="
docker compose logs --tail=20 livekit 2>/dev/null || docker logs livekit-livekit-1 --tail=20 2>/dev/null || true
echo ""
echo "✅ Setup abgeschlossen!"
echo ""
echo "Test:"
echo "  curl -sI https://livekit.srv1438024.hstgr.cloud"
echo "  Teste in der App: DM-Anruf + Community-Livestream starten"
