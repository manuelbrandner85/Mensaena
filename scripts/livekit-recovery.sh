#!/bin/bash
# Recovery: stellt die einfache funktionierende livekit.yaml wieder her
# (vor dem livekit-perfect-setup.sh Lauf)
set -e

LK_DIR="/docker/livekit"
[ ! -d "$LK_DIR" ] && { echo "FEHLER: $LK_DIR nicht gefunden"; exit 1; }
cd "$LK_DIR"

echo "=== Backups verfuegbar ==="
ls -lt *.bak.* 2>/dev/null | head -5

echo ""
echo "=== Versuche aeltesten Backup zu finden ==="
OLDEST_BAK=$(ls -t *.bak.* 2>/dev/null | tail -1)

if [ -z "$OLDEST_BAK" ]; then
  echo "Kein Backup vorhanden – schreibe minimale funktionierende Config"
  # Aktuelle Keys extrahieren
  apt-get install -y python3-yaml -qq 2>/dev/null || true

  python3 - <<'PYEOF'
import yaml
with open('livekit.yaml') as f:
    cfg = yaml.safe_load(f) or {}
keys = cfg.get('keys', {})
if not keys:
    print("FEHLER: Keine Keys gefunden")
    exit(1)

# Minimale funktionierende Config (wie urspruenglich)
minimal = {
    'port': 7880,
    'redis': {'address': 'redis:6379'},  # Container-Name (war 127.0.0.1, beide gehen)
    'keys': keys,
    'rtc': {
        'tcp_port': 7881,
        'port_range_start': 50000,
        'port_range_end': 60000,
        'use_external_ip': True,
    },
    'room': {
        'auto_create': True,
        'empty_timeout': 300,
    },
    'logging': {'level': 'info'},
}

with open('livekit.yaml', 'w') as f:
    yaml.dump(minimal, f, default_flow_style=False, sort_keys=False)
print("Minimale Config geschrieben")
PYEOF
else
  echo "Restore von: $OLDEST_BAK"
  cp "$OLDEST_BAK" livekit.yaml
  echo "Restored."
fi

echo ""
echo "=== Aktuelle livekit.yaml ==="
cat livekit.yaml

echo ""
echo "=== LiveKit neu starten ==="
docker compose restart livekit
sleep 6

echo ""
echo "=== Status ==="
docker compose ps

echo ""
echo "=== Log ==="
docker compose logs --tail=20 livekit

echo ""
echo "✅ Recovery abgeschlossen!"
echo ""
echo "Teste jetzt:"
echo "  1. Community-Livestream im Chat"
echo "  2. DM-Anruf"
