#!/bin/bash
# Perfekt-Konfiguration LiveKit fuer Mensaena (Hostinger VPS)
# v2: robuste Key-Extraktion via Python YAML
set -e

LK_DIR="/docker/livekit"
[ ! -d "$LK_DIR" ] && { echo "FEHLER: $LK_DIR nicht gefunden"; exit 1; }
cd "$LK_DIR"

echo "=== 1. Backup ==="
BAK="livekit.yaml.bak.$(date +%Y%m%d-%H%M%S)"
cp livekit.yaml "$BAK"
echo "Backup: $BAK"

echo ""
echo "=== 2. Existierende Config einlesen ==="
apt-get install -y python3-yaml -qq 2>/dev/null || true

# Existierende Config laden + neue schreiben (Keys + benutzte Werte erhalten)
python3 - <<'PYEOF'
import yaml, sys

with open('livekit.yaml', 'r') as f:
    cfg = yaml.safe_load(f) or {}

# API-Keys MUESSEN existieren
keys = cfg.get('keys') or {}
if not keys:
    print("FEHLER: Keine API-Keys in livekit.yaml gefunden")
    sys.exit(1)
print(f"Gefundene Keys: {len(keys)} – {list(keys.keys())}")

# Optimale Production-Config aufbauen
new_cfg = {
    'port': 7880,
    'bind_addresses': [''],
    # KRITISCH: redis muss Container-Name sein, nicht 127.0.0.1
    'redis': {
        'address': 'redis:6379',
    },
    'keys': keys,  # UNVERAENDERT uebernehmen
    'rtc': {
        'tcp_port': 7881,
        'port_range_start': 50000,
        'port_range_end': 60000,
        'use_external_ip': True,
        'use_ice_lite': False,
    },
    'room': {
        'auto_create': True,
        'empty_timeout': 300,
        'departure_timeout': 20,
        'max_participants': 100,
    },
    'logging': {
        'level': 'info',
        'pion_level': 'error',
        'json': False,
    },
    'audio': {
        'active_level': 35,
        'min_score': 0.6,
        'smoothing_factor': 0.7,
    },
    'limit': {
        'num_tracks': -1,
        'bytes_per_sec': 0,
        'subscription_limit_video': 200,
        'subscription_limit_audio': 200,
    },
}

with open('livekit.yaml', 'w') as f:
    yaml.dump(new_cfg, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print("✅ livekit.yaml geschrieben (Keys uebernommen)")
PYEOF

if [ $? -ne 0 ]; then
  echo "FEHLER beim Config-Schreiben – stelle Backup wieder her"
  cp "$BAK" livekit.yaml
  exit 1
fi

echo ""
echo "=== 3. Neue Config zur Kontrolle ==="
head -30 livekit.yaml

echo ""
echo "=== 4. Container neu starten ==="
docker compose down
docker compose up -d
sleep 8

echo ""
echo "=== 5. Container-Status ==="
docker compose ps

echo ""
echo "=== 6. LiveKit-Log (letzte 25 Zeilen) ==="
LOG=$(docker compose logs --tail=25 livekit 2>&1)
echo "$LOG"

echo ""
if echo "$LOG" | grep -qi "redis.*error\|connection refused\|panic"; then
  echo "⚠️  PROBLEM erkannt im Log!"
  echo ""
  echo "Falls 'redis' nicht aufloesbar ist, alternativen Container-Namen ermitteln:"
  docker compose ps | grep -i redis
  echo ""
  echo "Backup wiederherstellen mit:"
  echo "  cp $BAK livekit.yaml && docker compose restart livekit"
else
  echo "✅ LiveKit laeuft sauber!"
fi

echo ""
echo "Naechster Schritt: App testen (DM-Anruf, Livestream)"
