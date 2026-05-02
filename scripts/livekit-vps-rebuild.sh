#!/bin/bash
# FIX-110: Komplette LiveKit-Neuinstallation auf VPS
# Loescht alles vorhandene und setzt sauber auf mit Caddy-L4 (TLS-SNI-Routing),
# Redis, TURN auf turn.mensaena.de:443.
#
# VORAUSSETZUNG: DNS-A-Records muessen propagiert sein:
#   livekit.mensaena.de -> 72.62.154.95
#   turn.mensaena.de    -> 72.62.154.95
#
# Pruefe DNS bevor du startest:
#   host livekit.mensaena.de
#   host turn.mensaena.de

set -e

PUBLIC_IP="72.62.154.95"
LK_DIR="/opt/livekit"

echo "========================================"
echo " LiveKit Komplett-Neuaufbau – FIX-110"
echo "========================================"
echo ""

# ── 1.1 DNS-Check ──────────────────────────────────────────────────────────
echo "=== 1.1 DNS-Check ==="
for domain in livekit.mensaena.de turn.mensaena.de; do
  RESOLVED=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $NF}' | head -1)
  if [ "$RESOLVED" = "$PUBLIC_IP" ]; then
    echo "  ✅ $domain → $RESOLVED"
  else
    echo "  ❌ $domain → '$RESOLVED' (erwartet $PUBLIC_IP)"
    echo ""
    echo "FEHLER: DNS noch nicht propagiert. Lege A-Records an und warte."
    echo "Domain-Provider:"
    echo "  $domain  A  $PUBLIC_IP  TTL 300"
    exit 1
  fi
done

# ── 1.2 VPS aufraeumen ─────────────────────────────────────────────────────
echo ""
echo "=== 1.2 Bestehende Docker-Resources stoppen ==="
docker ps -aq | xargs -r docker rm -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true
docker network prune -f 2>/dev/null || true
docker system prune -f 2>/dev/null || true

if [ -d "$LK_DIR" ]; then
  echo "  Loesche altes $LK_DIR"
  rm -rf "$LK_DIR"
fi
mkdir -p "$LK_DIR"
echo "  ✅ Frisches $LK_DIR erstellt"

# ── 1.3 API-Keys generieren ────────────────────────────────────────────────
echo ""
echo "=== 1.3 API-Keys generieren ==="
API_KEY="APImsn$(openssl rand -hex 8)"
API_SECRET=$(openssl rand -base64 30 | tr -d '\n=' | head -c 40)
echo "$API_KEY" > "$LK_DIR/.api_key"
echo "$API_SECRET" > "$LK_DIR/.api_secret"
chmod 600 "$LK_DIR/.api_key" "$LK_DIR/.api_secret"
echo "  ✅ Keys generiert in $LK_DIR/.api_key + .api_secret"

# ── 1.4 Firewall ───────────────────────────────────────────────────────────
echo ""
echo "=== 1.4 Firewall (UFW) ==="
ufw allow 80/tcp comment 'HTTP Caddy'        2>/dev/null || true
ufw allow 443/tcp comment 'HTTPS Caddy/TURN' 2>/dev/null || true
ufw allow 7881/tcp comment 'LiveKit RTC TCP' 2>/dev/null || true
ufw allow 3478/udp comment 'TURN UDP'        2>/dev/null || true
ufw allow 50000:60000/udp comment 'WebRTC Media' 2>/dev/null || true
ufw reload 2>/dev/null || true
echo "  ✅ UFW-Regeln gesetzt"

# ── 1.5 livekit.yaml ───────────────────────────────────────────────────────
echo ""
echo "=== 1.5 livekit.yaml ==="
cat > "$LK_DIR/livekit.yaml" <<'EOF'
port: 7880
log_level: info

redis:
  address: redis:6379

rtc:
  port_range_start: 50000
  port_range_end: 60000
  tcp_port: 7881
  use_external_ip: true
  allow_tcp_fallback: true

turn:
  enabled: true
  domain: turn.mensaena.de
  tls_port: 443
  udp_port: 3478
  external_tls: true

prometheus_port: 6789

room:
  empty_timeout: 300
  departure_timeout: 20
  enabled_codecs:
    - mime: audio/opus
    - mime: video/vp8
    - mime: video/h264
EOF
echo "  ✅ $LK_DIR/livekit.yaml"

# ── 1.6 caddy.yaml ─────────────────────────────────────────────────────────
echo ""
echo "=== 1.6 caddy.yaml (Caddy L4 mit SNI-Routing) ==="
cat > "$LK_DIR/caddy.yaml" <<'EOF'
logging:
  logs:
    default:
      level: INFO

apps:
  tls:
    automation:
      policies:
        - subjects:
            - livekit.mensaena.de
            - turn.mensaena.de
          issuers:
            - module: acme
              email: admin@mensaena.de

  layer4:
    servers:
      main:
        listen: [":443"]
        routes:
          - match:
              - tls:
                  sni: ["turn.mensaena.de"]
            handle:
              - handler: tls
              - handler: proxy
                upstreams:
                  - dial: ["livekit:5349"]
          - match:
              - tls:
                  sni: ["livekit.mensaena.de"]
            handle:
              - handler: tls
              - handler: proxy
                upstreams:
                  - dial: ["livekit:7880"]

  http:
    servers:
      http_redirect:
        listen: [":80"]
        routes:
          - handle:
              - handler: static_response
                status_code: 308
                headers:
                  Location: ["https://{http.request.host}{http.request.uri}"]
EOF
echo "  ✅ $LK_DIR/caddy.yaml"

# ── 1.7 redis.conf ─────────────────────────────────────────────────────────
echo ""
echo "=== 1.7 redis.conf ==="
cat > "$LK_DIR/redis.conf" <<'EOF'
bind 0.0.0.0
protected-mode no
port 6379
appendonly yes
maxmemory 128mb
maxmemory-policy allkeys-lru
EOF
echo "  ✅ $LK_DIR/redis.conf"

# ── 1.8 docker-compose.yaml ────────────────────────────────────────────────
echo ""
echo "=== 1.8 docker-compose.yaml ==="
cat > "$LK_DIR/docker-compose.yaml" <<EOF
services:
  caddy:
    image: livekit/caddyl4:latest
    restart: always
    network_mode: host
    volumes:
      - ./caddy.yaml:/etc/caddy.yaml
      - caddy_data:/data
    command: run --config /etc/caddy.yaml --adapter yaml

  livekit:
    image: livekit/livekit-server:latest
    restart: always
    network_mode: host
    depends_on:
      redis:
        condition: service_healthy
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml
    environment:
      LIVEKIT_KEYS: "$API_KEY: $API_SECRET"
    command: --config /etc/livekit.yaml --node-ip=$PUBLIC_IP

  redis:
    image: redis:7-alpine
    restart: always
    network_mode: host
    volumes:
      - ./redis.conf:/usr/local/etc/redis/redis.conf
      - redis_data:/data
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  caddy_data:
  redis_data:
EOF
echo "  ✅ $LK_DIR/docker-compose.yaml"

# ── 1.9 Starten ────────────────────────────────────────────────────────────
echo ""
echo "=== 1.9 Container starten ==="
cd "$LK_DIR"
docker compose up -d
sleep 12

echo ""
echo "Container-Status:"
docker compose ps

echo ""
echo "=== LiveKit-Log (letzte 30 Zeilen) ==="
docker compose logs --tail=30 livekit 2>&1 | tail -30

echo ""
echo "=== Caddy-Log (letzte 20 Zeilen) ==="
docker compose logs --tail=20 caddy 2>&1 | tail -20

# ── 1.10 Tests ─────────────────────────────────────────────────────────────
echo ""
echo "=== 1.10 Connectivity-Tests ==="
echo ""
echo "DNS:"
host livekit.mensaena.de | tail -1
host turn.mensaena.de | tail -1

echo ""
echo "HTTPS livekit.mensaena.de (warte auf TLS-Cert via Let's Encrypt — ggf. 60s):"
sleep 30  # Caddy braucht Zeit fuer Cert-Acquisition
curl -sI --max-time 10 "https://livekit.mensaena.de" 2>&1 | head -3 || echo "noch nicht bereit (Cert acquisition laeuft)"

echo ""
echo "TLS turn.mensaena.de:443:"
echo | timeout 5 openssl s_client -connect turn.mensaena.de:443 -servername turn.mensaena.de 2>&1 | grep -E "subject=|issuer=" | head -2 || echo "TLS-Test fehlgeschlagen"

echo ""
echo "Redis:"
docker compose exec -T redis redis-cli ping 2>/dev/null || echo "Redis-Test fehlgeschlagen"

echo ""
echo "Prometheus:"
curl -sf --max-time 3 "http://localhost:6789/metrics" 2>/dev/null | head -5 || echo "Prometheus noch nicht bereit"

# ── 1.11 systemd ───────────────────────────────────────────────────────────
echo ""
echo "=== 1.11 systemd-Service ==="
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
echo "  ✅ livekit-docker.service eingerichtet"

# ── 1.12 Vercel-Hinweise ───────────────────────────────────────────────────
echo ""
echo "========================================"
echo " ✅ VPS Setup ABGESCHLOSSEN"
echo "========================================"
echo ""
echo "Vercel/Cloudflare Worker Environment Variables setzen:"
echo ""
echo "  LIVEKIT_SELF_URL    = wss://livekit.mensaena.de"
echo "  LIVEKIT_SELF_KEY    = $API_KEY"
echo "  LIVEKIT_SELF_SECRET = $API_SECRET"
echo ""
echo "ALTE Variablen LOESCHEN:"
echo "  LIVEKIT_API_KEY"
echo "  LIVEKIT_API_SECRET"
echo ""
echo "Danach: App neu deployen."
echo ""
echo "API-Keys auch gespeichert in:"
echo "  $LK_DIR/.api_key"
echo "  $LK_DIR/.api_secret"
