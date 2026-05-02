#!/bin/bash
# FIX-110: Simple LiveKit-Setup auf Hostinger VPS
# Kein Caddy, kein TURN-Setup. LiveKit serviert TLS direkt auf 443.
# SSL via certbot standalone, Auto-Renewal mit Restart-Hook.
#
# VORAUSSETZUNG: DNS-A-Record propagiert:
#   livekit.mensaena.de -> 72.62.154.95 (Cloudflare: Proxy DNS-only/grau)

set -e

PUBLIC_IP="72.62.154.95"
LK_DIR="/opt/livekit"
DOMAIN="livekit.mensaena.de"

echo "========================================"
echo " LiveKit Simple-Setup – FIX-110"
echo "========================================"
echo ""

# ── 1.1 DNS-Check ──────────────────────────────────────────────────────────
echo "=== 1.1 DNS-Check ==="
RESOLVED=$(host "$DOMAIN" 2>/dev/null | grep "has address" | awk '{print $NF}' | head -1)
if [ "$RESOLVED" = "$PUBLIC_IP" ]; then
  echo "  ✅ $DOMAIN → $RESOLVED"
else
  echo "  ❌ $DOMAIN → '$RESOLVED' (erwartet $PUBLIC_IP)"
  echo ""
  echo "FEHLER: DNS nicht propagiert. In Cloudflare anlegen:"
  echo "  Type: A | Name: livekit | Content: $PUBLIC_IP | Proxy: DNS only (graue Wolke)"
  exit 1
fi

# ── 1.2 SSH ZUERST sichern + VPS aufraeumen ────────────────────────────────
echo ""
echo "=== 1.2 SSH-Sicherung + VPS aufraeumen ==="
ufw allow 22/tcp comment 'SSH' 2>/dev/null || true
ufw allow OpenSSH 2>/dev/null || true
echo "  ✅ SSH-Regel gesetzt (vor allem anderen)"

docker ps -aq | xargs -r docker stop 2>/dev/null || true
docker ps -aq | xargs -r docker rm -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true
docker network prune -f 2>/dev/null || true
docker system prune -f 2>/dev/null || true

if [ -d "$LK_DIR" ]; then
  rm -rf "$LK_DIR"
fi
mkdir -p "$LK_DIR"
cd "$LK_DIR"
echo "  ✅ Frisches $LK_DIR"

# ── 1.3 SSL-Zertifikat via certbot ─────────────────────────────────────────
echo ""
echo "=== 1.3 SSL via certbot ==="
apt update -qq
apt install -y certbot

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  echo "  ✅ Zertifikat bereits vorhanden"
else
  certbot certonly --standalone \
    -d "$DOMAIN" \
    --agree-tos --no-eff-email \
    -m admin@mensaena.de \
    --non-interactive
fi
ls -la "/etc/letsencrypt/live/$DOMAIN/" 2>/dev/null

# ── 1.4 API-Keys generieren ────────────────────────────────────────────────
echo ""
echo "=== 1.4 API-Keys generieren ==="
LIVEKIT_API_KEY="APImsn$(openssl rand -hex 8)"
LIVEKIT_API_SECRET=$(openssl rand -base64 32 | tr -d '=/+' | head -c 40)

echo "$LIVEKIT_API_KEY"    > "$LK_DIR/.api_key"
echo "$LIVEKIT_API_SECRET" > "$LK_DIR/.api_secret"
chmod 600 "$LK_DIR/.api_key" "$LK_DIR/.api_secret"
echo "  ✅ Keys gespeichert"

# ── 1.5 Firewall ───────────────────────────────────────────────────────────
echo ""
echo "=== 1.5 Firewall (UFW) ==="
ufw allow 80/tcp comment 'HTTP certbot'        2>/dev/null || true
ufw allow 443/tcp comment 'LiveKit TLS direkt' 2>/dev/null || true
ufw allow 7881/tcp comment 'LiveKit RTC TCP'   2>/dev/null || true
ufw allow 3478/udp comment 'TURN UDP'          2>/dev/null || true
ufw allow 50000:60000/udp comment 'WebRTC Media' 2>/dev/null || true
ufw --force enable 2>/dev/null || true
ufw reload 2>/dev/null || true
ufw status verbose | head -15

if ! ufw status | grep -qE "22/tcp\s+ALLOW|OpenSSH\s+ALLOW"; then
  echo "❌ KRITISCH: SSH nicht ALLOW! Abbruch."
  exit 1
fi

# ── 1.6 livekit.yaml ───────────────────────────────────────────────────────
echo ""
echo "=== 1.6 livekit.yaml ==="
cat > "$LK_DIR/livekit.yaml" <<'EOF'
port: 7880
log_level: info

redis:
  address: localhost:6379

rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true
  allow_tcp_fallback: true

room:
  empty_timeout: 300
  departure_timeout: 20
  enabled_codecs:
    - mime: audio/opus
    - mime: video/vp8
    - mime: video/h264

prometheus_port: 6789
EOF
echo "  ✅ $LK_DIR/livekit.yaml"

# ── 1.7 docker-compose.yaml ────────────────────────────────────────────────
echo ""
echo "=== 1.7 docker-compose.yaml ==="
cat > "$LK_DIR/docker-compose.yaml" <<EOF
services:
  livekit:
    image: livekit/livekit-server:latest
    restart: always
    network_mode: host
    depends_on:
      redis:
        condition: service_healthy
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml
      - /etc/letsencrypt:/etc/letsencrypt:ro
    environment:
      LIVEKIT_KEYS: "$LIVEKIT_API_KEY: $LIVEKIT_API_SECRET"
    command: >
      --config /etc/livekit.yaml
      --node-ip=$PUBLIC_IP
      --tls-cert /etc/letsencrypt/live/$DOMAIN/fullchain.pem
      --tls-key /etc/letsencrypt/live/$DOMAIN/privkey.pem

  redis:
    image: redis:7-alpine
    restart: always
    network_mode: host
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru --bind 127.0.0.1
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  redis_data:
EOF
echo "  ✅ $LK_DIR/docker-compose.yaml"

# ── 1.8 Starten ────────────────────────────────────────────────────────────
echo ""
echo "=== 1.8 Container starten ==="
docker compose up -d
sleep 12

docker compose ps
echo ""
echo "LiveKit-Log (letzte 30):"
docker compose logs --tail=30 livekit 2>&1 | tail -30
echo ""
echo "Redis-Log (letzte 10):"
docker compose logs --tail=10 redis 2>&1 | tail -10

# ── 1.9 Tests ──────────────────────────────────────────────────────────────
echo ""
echo "=== 1.9 Tests ==="
echo "DNS:"
host $DOMAIN | tail -1
echo ""
echo "HTTPS:"
sleep 5
curl -sI --max-time 10 "https://$DOMAIN" 2>&1 | head -3 || echo "noch nicht bereit"
echo ""
echo "Redis:"
docker compose exec -T redis redis-cli ping 2>/dev/null || echo "Redis-Test fehlgeschlagen"
echo ""
echo "Prometheus (intern):"
curl -sf --max-time 3 "http://localhost:6789/metrics" 2>/dev/null | head -3 || echo "Prometheus noch nicht bereit"

# ── 1.10 systemd Auto-Start ────────────────────────────────────────────────
echo ""
echo "=== 1.10 systemd-Service ==="
cat > /etc/systemd/system/livekit-docker.service <<EOF
[Unit]
Description=LiveKit Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$LK_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable livekit-docker.service 2>/dev/null || true
echo "  ✅ Auto-Start nach Reboot"

# ── 1.11 Certbot Auto-Renewal Hook ─────────────────────────────────────────
echo ""
echo "=== 1.11 Renewal-Hook ==="
mkdir -p /etc/letsencrypt/renewal-hooks/post
cat > /etc/letsencrypt/renewal-hooks/post/restart-livekit.sh <<'EOF'
#!/bin/bash
cd /opt/livekit && docker compose restart livekit
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/restart-livekit.sh
echo "  ✅ Auto-Renewal Hook aktiv"

# ── Output ────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " ✅ LIVEKIT SETUP ABGESCHLOSSEN"
echo "========================================"
echo ""
echo "JETZT IN VERCEL/CLOUDFLARE WORKER ENV SETZEN:"
echo ""
echo "  LIVEKIT_SELF_URL    = wss://$DOMAIN"
echo "  LIVEKIT_SELF_KEY    = $LIVEKIT_API_KEY"
echo "  LIVEKIT_SELF_SECRET = $LIVEKIT_API_SECRET"
echo ""
echo "ALTE Variablen LOESCHEN:"
echo "  LIVEKIT_API_KEY"
echo "  LIVEKIT_API_SECRET"
echo ""
echo "Keys auch in: $LK_DIR/.api_key + .api_secret"
