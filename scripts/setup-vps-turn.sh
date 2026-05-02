#!/bin/bash
set -e

LIVEKIT_DIR="/opt/livekit"
TURN_DOMAIN="turn.mensaena.de"
EMAIL="admin@mensaena.de"

echo "=============================="
echo " LiveKit TURN + Redis Setup"
echo "=============================="

# 1. certbot
echo ""
echo "[1/5] certbot installieren..."
apt-get update -qq
apt-get install -y certbot python3-yaml -qq

# SSL-Zertifikat
if [ ! -f "/etc/letsencrypt/live/$TURN_DOMAIN/fullchain.pem" ]; then
  echo "     SSL-Zertifikat für $TURN_DOMAIN holen..."
  certbot certonly --standalone -d "$TURN_DOMAIN" \
    --non-interactive --agree-tos -m "$EMAIL" \
    --preferred-challenges http \
    && echo "     ✅ Zertifikat erhalten" \
    || echo "     ⚠️  Zertifikat fehlgeschlagen (DNS noch nicht propagiert – später wiederholen mit: certbot certonly --standalone -d turn.mensaena.de)"
else
  echo "     ✅ Zertifikat bereits vorhanden"
fi

# 2. livekit.yaml sichern + aktualisieren
echo ""
echo "[2/5] livekit.yaml aktualisieren..."
cp "$LIVEKIT_DIR/livekit.yaml" "$LIVEKIT_DIR/livekit.yaml.bak" 2>/dev/null || true

python3 - <<PYEOF
import yaml

with open('$LIVEKIT_DIR/livekit.yaml', 'r') as f:
    cfg = yaml.safe_load(f) or {}

cfg['turn'] = {
    'enabled': True,
    'domain': '$TURN_DOMAIN',
    'tls_port': 5349,
    'udp_port': 3478,
    'external_tls': False,
    'cert_file': '/etc/letsencrypt/live/$TURN_DOMAIN/fullchain.pem',
    'key_file':  '/etc/letsencrypt/live/$TURN_DOMAIN/privkey.pem',
}
cfg['redis'] = {'address': 'redis:6379'}

with open('$LIVEKIT_DIR/livekit.yaml', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)

print('     ✅ livekit.yaml aktualisiert (TURN + Redis)')
PYEOF

# 3. docker-compose.yaml – Redis hinzufügen
echo ""
echo "[3/5] Redis in docker-compose.yaml eintragen..."
cd "$LIVEKIT_DIR"

python3 - <<PYEOF
import yaml

with open('docker-compose.yaml', 'r') as f:
    dc = yaml.safe_load(f) or {}

if 'redis' in dc.get('services', {}):
    print('     ✅ Redis bereits vorhanden')
else:
    if 'services' not in dc:
        dc['services'] = {}
    dc['services']['redis'] = {
        'image': 'redis:7-alpine',
        'restart': 'unless-stopped',
        'volumes': ['redis_data:/data'],
    }
    if 'volumes' not in dc:
        dc['volumes'] = {}
    dc['volumes']['redis_data'] = None

    with open('docker-compose.yaml', 'w') as f:
        yaml.dump(dc, f, default_flow_style=False, allow_unicode=True)
    print('     ✅ Redis-Service hinzugefügt')
PYEOF

# 4. Firewall
echo ""
echo "[4/5] Firewall-Ports öffnen..."
ufw allow 3478/udp comment 'TURN UDP'  2>/dev/null || true
ufw allow 5349/tcp comment 'TURN TLS'  2>/dev/null || true
ufw allow 80/tcp   comment 'certbot'   2>/dev/null || true
echo "     ✅ Ports 3478/UDP und 5349/TCP geöffnet"

# 5. Docker Compose neu starten
echo ""
echo "[5/5] LiveKit + Redis neu starten..."
cd "$LIVEKIT_DIR"
docker compose down
docker compose up -d
sleep 6

echo ""
echo "=============================="
echo " Status"
echo "=============================="
docker compose ps
echo ""
echo "✅ Setup abgeschlossen!"
echo ""
echo "Nächste Schritte:"
echo "  1. DNS: turn.mensaena.de → $(curl -sf https://api.ipify.org) im hPanel anlegen (A-Record)"
echo "  2. Nach DNS-Propagation (~5 Min): certbot erneut versuchen falls Zertifikat fehlschlug"
echo "     certbot certonly --standalone -d turn.mensaena.de --non-interactive --agree-tos -m admin@mensaena.de"
