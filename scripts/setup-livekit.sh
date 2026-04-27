#!/bin/bash
# Mensaena LiveKit Self-Hosted Setup
# Run as root on Ubuntu 22.04 VPS:
#   bash <(curl -fsSL https://raw.githubusercontent.com/manuelbrandner85/Mensaena/main/scripts/setup-livekit.sh)

set -e
DOMAIN="${LIVEKIT_DOMAIN:-meet.mensaena.de}"
LK_API_KEY="mensaena-$(openssl rand -hex 8)"
LK_API_SECRET="$(openssl rand -hex 32)"
EMAIL="${LETSENCRYPT_EMAIL:-admin@mensaena.de}"

echo "================================================"
echo " Mensaena LiveKit Setup"
echo " Domain : $DOMAIN"
echo " API Key: $LK_API_KEY"
echo "================================================"

# ── 1. System Update ────────────────────────────────────────────────────────
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget git ufw nginx certbot python3-certbot-nginx openssl

# ── 2. Docker ───────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
docker --version

# ── 3. Firewall ─────────────────────────────────────────────────────────────
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw allow 3478/udp   # TURN
ufw allow 3478/tcp   # TURN
ufw allow 5349/tcp   # TURNS
ufw allow 5349/udp   # TURNS
ufw allow 50000:60000/udp  # WebRTC media
ufw --force enable
echo "✅ Firewall configured"

# ── 4. LiveKit config directory ─────────────────────────────────────────────
mkdir -p /opt/livekit
cat > /opt/livekit/livekit.yaml << LKEOF
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true

redis:
  address: redis:6379

turn:
  enabled: true
  domain: ${DOMAIN}
  tls_port: 5349
  udp_port: 3478
  credential: mensaena-turn-secret

keys:
  ${LK_API_KEY}: ${LK_API_SECRET}

logging:
  level: info

room:
  auto_create: true
  empty_timeout: 300
  max_participants: 50
LKEOF
echo "✅ LiveKit config created"

# ── 5. Docker Compose ────────────────────────────────────────────────────────
cat > /opt/livekit/docker-compose.yml << DCEOF
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    command: --config /etc/livekit/livekit.yaml
    restart: unless-stopped
    network_mode: host
    volumes:
      - /opt/livekit/livekit.yaml:/etc/livekit/livekit.yaml

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --save ""
    networks:
      - livekit-net

networks:
  livekit-net:
DCEOF

# Fix: livekit uses host network, redis needs to be accessible
# Use host network for redis too
sed -i 's/networks:\n      - livekit-net/network_mode: host/' /opt/livekit/docker-compose.yml

cat > /opt/livekit/docker-compose.yml << DCEOF
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    network_mode: host
    command: redis-server --save "" --port 6379

  livekit:
    image: livekit/livekit-server:latest
    restart: unless-stopped
    network_mode: host
    depends_on:
      - redis
    volumes:
      - /opt/livekit/livekit.yaml:/etc/livekit/livekit.yaml
    command: --config /etc/livekit/livekit.yaml
DCEOF
echo "✅ Docker Compose config created"

# ── 6. Nginx config (before SSL) ────────────────────────────────────────────
cat > /etc/nginx/sites-available/livekit << NGEOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400;
    }
}
NGEOF
ln -sf /etc/nginx/sites-available/livekit /etc/nginx/sites-enabled/livekit
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
echo "✅ Nginx configured"

# ── 7. Start LiveKit ─────────────────────────────────────────────────────────
cd /opt/livekit
docker compose pull
docker compose up -d
echo "✅ LiveKit started"

# ── 8. SSL Certificate ───────────────────────────────────────────────────────
echo ""
echo "⏳ Waiting 10s for LiveKit to start before requesting SSL..."
sleep 10
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos -m "${EMAIL}" --redirect || {
  echo "⚠️  SSL failed – DNS A-Record für ${DOMAIN} zeigt noch nicht auf diesen Server."
  echo "   Setze: ${DOMAIN} → $(curl -s ifconfig.me)"
  echo "   Dann führe aus: certbot --nginx -d ${DOMAIN} -m ${EMAIL} --agree-tos --redirect"
}

# ── 9. Systemd service for auto-start ───────────────────────────────────────
cat > /etc/systemd/system/livekit.service << SVCEOF
[Unit]
Description=Mensaena LiveKit Server
After=docker.service network-online.target
Requires=docker.service

[Service]
WorkingDirectory=/opt/livekit
ExecStart=/usr/bin/docker compose up
ExecStop=/usr/bin/docker compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable livekit
echo "✅ Systemd service enabled"

# ── 10. Save credentials ─────────────────────────────────────────────────────
cat > /opt/livekit/credentials.txt << CREDEOF
=== Mensaena LiveKit Credentials ===
Domain:     ${DOMAIN}
WSS URL:    wss://${DOMAIN}
API Key:    ${LK_API_KEY}
API Secret: ${LK_API_SECRET}

Diese Werte in Cloudflare Environment Variables eintragen:
LIVEKIT_SELF_URL    = wss://${DOMAIN}
LIVEKIT_SELF_KEY    = ${LK_API_KEY}
LIVEKIT_SELF_SECRET = ${LK_API_SECRET}
CREDEOF

echo ""
echo "================================================"
echo " ✅ LiveKit Setup abgeschlossen!"
echo "================================================"
cat /opt/livekit/credentials.txt
echo "================================================"
echo " DNS: Setze A-Record ${DOMAIN} → $(curl -s ifconfig.me 2>/dev/null)"
echo "================================================"
