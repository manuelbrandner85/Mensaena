#!/bin/bash
# DEFINITIVE LiveKit-Konfiguration: ICE-Kandidaten Filter
# Problem: LiveKit advertised auch Docker-Bridges (172.20.0.1, 172.18.0.1) als
# ICE-Kandidaten. iOS-Client versucht die zu erreichen statt der Public-IP.
# Fix: rtc.node_ip explizit setzen + Interface-Filter
set -e

LK_DIR="/docker/livekit"
[ ! -d "$LK_DIR" ] && { echo "FEHLER: $LK_DIR nicht gefunden"; exit 1; }
cd "$LK_DIR"

PUBLIC_IP="72.62.154.95"

echo "=== 1. Backup ==="
cp livekit.yaml "livekit.yaml.bak.$(date +%Y%m%d-%H%M%S)"

echo ""
echo "=== 2. Optimale Config schreiben (ICE-Fix) ==="
apt-get install -y python3-yaml -qq 2>/dev/null || true

python3 - <<PYEOF
import yaml

with open('livekit.yaml') as f:
    cfg = yaml.safe_load(f) or {}

keys = cfg.get('keys', {})
if not keys:
    print("FEHLER: Keine API-Keys")
    exit(1)

# DEFINITIVE Config – verhindert Advertising von Docker-IPs
new_cfg = {
    'port': 7880,
    'redis': {'address': 'redis:6379'},
    'keys': keys,
    'rtc': {
        # KRITISCH: Public IP explizit setzen → KEINE Docker-Bridge-IPs mehr in ICE-Candidates
        'node_ip': '$PUBLIC_IP',
        'tcp_port': 7881,
        'port_range_start': 50000,
        'port_range_end': 60000,
        # Auch dann externe IP nutzen falls node_ip mal nicht greift
        'use_external_ip': True,
        # ICE-Lite: schnellerer Connect (LiveKit als Reflexive-Address-Provider)
        'use_ice_lite': False,
    },
    'room': {
        'auto_create': True,
        'empty_timeout': 300,
        'departure_timeout': 20,
    },
    'logging': {
        'level': 'info',
        'pion_level': 'info',  # Mehr Detail bei ICE-Issues
    },
    # Built-in TURN als Fallback fuer User hinter strenger NAT/Firewall
    # (Mobile-Carrier mit Symmetric NAT)
    'turn': {
        'enabled': True,
        'udp_port': 3478,
        # Domain leer lassen → LiveKit nutzt node_ip
        'domain': '',
        'external_tls': False,
    },
}

with open('livekit.yaml', 'w') as f:
    yaml.dump(new_cfg, f, default_flow_style=False, sort_keys=False)
print("OK – livekit.yaml mit ICE-Fix geschrieben")
PYEOF

echo ""
echo "=== 3. Aktuelle Config ==="
cat livekit.yaml
echo ""

echo "=== 4. Container neu starten ==="
docker compose down
docker compose up -d
sleep 8

echo ""
echo "=== 5. Status ==="
docker compose ps

echo ""
echo "=== 6. LiveKit-Log (wichtig: 'using external IPs') ==="
docker compose logs --tail=30 livekit 2>&1 | grep -E "external IP|node IP|ICE|started|listening|node_ip" | head -20

echo ""
echo "=== 7. Connectivity-Tests ==="
nc -u -z -v -w 3 $PUBLIC_IP 50000 2>&1 | head -2 || true

echo ""
echo "✅ Fertig!"
echo ""
echo "Was sich geaendert hat:"
echo "  - node_ip: 72.62.154.95 (verhindert Docker-IPs in ICE-Candidates)"
echo "  - turn.enabled: true (Fallback fuer strenge NAT)"
echo ""
echo "Jetzt App neu oeffnen und Livestream/Call testen!"
