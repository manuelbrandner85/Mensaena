# LiveKit-Setup für Mensaena Flutter App

LiveKit-Server läuft auf **Hostinger VPS** unter `wss://livekit.mensaena.de`.
Die Flutter-App fordert das JWT von der **Supabase Edge Function**
`livekit-token` an. Damit das funktioniert müssen 2 Secrets in Supabase
hinterlegt sein.

## Status-Check

```bash
curl -X POST \
  "https://huaqldjkgyosefzfhjnf.supabase.co/functions/v1/livekit-token?check=1" \
  -H "Content-Type: application/json" -d '{}'
```

Antwort sollte sein:
```json
{
  "livekit_url": "wss://livekit.mensaena.de",
  "has_key": true,
  "has_secret": true
}
```

Wenn `has_key` oder `has_secret` = `false` → Secrets fehlen → siehe unten.

## Secrets setzen

### Option A: Supabase CLI (einfach)

```bash
cd /home/user/Mensaena
npx supabase login         # einmalig, Browser öffnet sich
npx supabase secrets set \
  --project-ref huaqldjkgyosefzfhjnf \
  LIVEKIT_SELF_KEY='mensaena-<dein-key-aus-livekit.yaml>' \
  LIVEKIT_SELF_SECRET='<dein-secret-aus-livekit.yaml>'
```

Optional auch URL überschreiben (sonst Default `wss://livekit.mensaena.de`):
```bash
npx supabase secrets set \
  --project-ref huaqldjkgyosefzfhjnf \
  LIVEKIT_SELF_URL='wss://livekit.mensaena.de'
```

### Option B: Supabase Dashboard (UI)

1. https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/functions/secrets
2. Klick **"Add new secret"**
3. Name: `LIVEKIT_SELF_KEY` — Value: (der API-Key von Hostinger livekit.yaml)
4. Wiederholen für `LIVEKIT_SELF_SECRET`
5. **Edge Function neu deployen ist NICHT nötig** — Secrets werden live übernommen

## Werte holen von Hostinger VPS

Auf dem Hostinger VPS (IP 72.62.154.95):

```bash
ssh user@72.62.154.95
sudo cat /docker/livekit*/livekit.yaml | grep -A2 "api_keys:"
```

Dort sollte stehen:
```yaml
api_keys:
  mensaena-abc12345...: <secret-string>
```

Der Key-Name (`mensaena-abc12345...`) ist der `LIVEKIT_SELF_KEY`.
Der Value (`<secret-string>`) ist der `LIVEKIT_SELF_SECRET`.

## Verifikation

Nach dem Setzen:

```bash
curl "https://huaqldjkgyosefzfhjnf.supabase.co/functions/v1/livekit-token?check=1" \
  -X POST -H "Content-Type: application/json" -d '{}'
# → {"livekit_url":"wss://livekit.mensaena.de","has_key":true,"has_secret":true}
```

In der App:
1. Community-Channel öffnen (z.B. "Krisen & Notfall")
2. Radio-FAB tippen → LiveRoomScreen öffnet sich
3. Sollte connecten ohne Fehler-Message
