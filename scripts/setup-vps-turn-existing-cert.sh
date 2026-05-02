#!/bin/bash
# Aktualisiert TURN-Konfiguration auf vorhandenes LiveKit-Zertifikat
# (kein neuer DNS-Eintrag, kein neues Zertifikat noetig)
set -e

LIVEKIT_DIR="/opt/livekit"

echo "=== Vorhandenes Zertifikat suchen ==="
CERT_DIR=$(ls -1d /etc/letsencrypt/live/*/ 2>/dev/null | head -1)
if [ -z "$CERT_DIR" ]; then
  echo "FEHLER: Kein Letsencrypt-Zertifikat gefunden"
  exit 1
fi
DOMAIN=$(basename "$CERT_DIR")
CERT="${CERT_DIR}fullchain.pem"
KEY="${CERT_DIR}privkey.pem"
echo "Verwende Zertifikat: $DOMAIN"
echo "  Cert: $CERT"
echo "  Key:  $KEY"

echo ""
echo "=== livekit.yaml aktualisieren ==="
apt-get install -y python3-yaml -qq 2>/dev/null || true
python3 - <<PYEOF
import yaml

with open('$LIVEKIT_DIR/livekit.yaml', 'r') as f:
    cfg = yaml.safe_load(f) or {}

cfg['turn'] = {
    'enabled': True,
    'domain': '$DOMAIN',
    'tls_port': 5349,
    'udp_port': 3478,
    'external_tls': False,
    'cert_file': '$CERT',
    'key_file':  '$KEY',
}
cfg['redis'] = {'address': 'redis:6379'}

with open('$LIVEKIT_DIR/livekit.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)

print('livekit.yaml aktualisiert')
PYEOF

echo ""
echo "=== Firewall ==="
ufw allow 5349/tcp 2>/dev/null || true
ufw allow 3478/udp 2>/dev/null || true

echo ""
echo "=== Neustart ==="
cd "$LIVEKIT_DIR"
docker compose down
docker compose up -d
sleep 6
docker compose ps

echo ""
echo "Fertig! TURN nutzt jetzt das vorhandene Zertifikat von $DOMAIN"
