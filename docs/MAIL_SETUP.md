# Mensaena – E-Mail-Versand

> **Aktueller Stand (DNS-Probe Cloudflare):** mensaena.de ist bereits sauber an
> **Lima-City** (Hoster) konfiguriert: MX `mail.lima-city.de`, SPF
> `v=spf1 include:lima-city.de ~all`, DMARC `p=none; rua=mailto:info@mensaena.de`.
> Damit funktioniert der bestehende SMTP-Versand der Edge-Function `send-email`
> **out of the box** über das Lima-City-Postfach.

## Bestehender Pfad: SMTP über Lima-City (Default, läuft)
- Function `send-email` nutzt `mail.lima-city.de:465` (TLS) mit Login.
- Secrets (Supabase → Edge Functions → Secrets):
  - `SMTP_HOST = mail.lima-city.de`
  - `SMTP_PORT = 465`
  - `SMTP_USER` = E-Mail-Adresse bei Lima-City (z. B. `Info@mensaena.de` oder
    `hallo@mensaena.de`, sofern bei Lima-City angelegt)
  - `SMTP_PASSWORD` = Postfach-Passwort
  - `SMTP_FROM` = Absenderadresse (muss ein Lima-City-Postfach sein, sonst Reject)
- Footer (Absender / Abmeldung / Impressum) wird automatisch angehängt.

**Wenn als Absender `hallo@mensaena.de` gewünscht ist:**
1. Im Lima-City-Webmail/Kundencenter ein Postfach `hallo@mensaena.de` anlegen
   (oder als Alias auf das bestehende Postfach legen).
2. `SMTP_USER` + `SMTP_FROM` entsprechend setzen.
3. Kein DNS-Update nötig (SPF erlaubt Lima-City bereits).

## Optional: Resend (zusätzlicher Anbieter)
Die Function unterstützt **Resend** als HTTP-API-Pfad, falls Volumen oder
Zustellrate später ein Problem werden. Wird automatisch genutzt, sobald
`MAIL_API_KEY` (Resend) gesetzt ist; sonst läuft SMTP weiter.

Dafür wären **DNS-Erweiterungen** nötig (Cloudflare DNS-Zone „mensaena.de"):
1. Account bei Resend erstellen, Domain hinzufügen.
2. SPF erweitern (TXT, **derselbe** Eintrag, ergänzt um Resend):
   ```
   v=spf1 include:lima-city.de include:_spf.resend.com ~all
   ```
3. **DKIM**: Resend zeigt zwei CNAME-Records (`resend._domainkey` o. ä.) →
   1:1 in Cloudflare als CNAME, Proxy AUS (graue Wolke).
4. **Return-Path**: `bounces.mensaena.de` als CNAME auf Resend (falls Resend es
   anzeigt) – wichtig für Bounce-Tracking.
5. DMARC kann bleiben (`p=none`) oder später auf `p=quarantine` verschärfen,
   sobald Resend stabil liefert.

Secrets dafür:
- `MAIL_API_KEY = re_xxx` (Resend Dashboard → API Keys)
- `MAIL_FROM = Mensaena <hallo@mensaena.de>` (default)

Verifikation:
```bash
curl -X POST https://gyqujitkvymlmgroovch.functions.supabase.co/send-email \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"to":"<deine-test-adresse>","subject":"Mensaena Test","html":"<p>Hallo aus Mensaena 🌱</p>","category":"marketing"}'
```

## Kampagnen-Versand (Flutter Admin → Marketing)
`/dashboard/admin/marketing` → Tab „E-Mail":
- Entwurf erstellen → „Senden" → Function `send-email-campaign` ruft pro Empfänger
  `send-email` auf, schreibt Audit-Zeile in `email_sends`, aktualisiert
  `email_campaigns.sent_count/recipient_count/status`.
- Nur Empfänger mit `profiles.email_opt_in = true`. Globale Notbremse
  (`app_settings.marketing_paused`) bricht sofort ab.
- Bulk-Limit pro Funktionsaufruf: 200 Empfänger (Volumenschutz).

## Push-Kampagnen
`/dashboard/admin/marketing` → Tab „Push":
- Titel + Text + Ziel-Route → Function `send-push-campaign` schreibt
  `notifications`-Zeilen mit `metadata.marketing = true`. Der vorhandene
  DB-Trigger sendet daraus Pushes via FCM.
- Jeder Empfänger durchläuft `notify_guard` (Opt-in `marketing_opt_in`,
  Frequenz 1/72h + 2/Woche, stille Zeiten 22–8 Berlin).
