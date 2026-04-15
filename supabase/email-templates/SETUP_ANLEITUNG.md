# Mensaena – E-Mail-Templates für Supabase Auth

## So richtest du die Templates ein (2 Minuten)

1. Öffne: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/templates

2. **"Confirm signup"** → Betreff + HTML aus `confirm-signup.html` einfügen
3. **"Reset password"** → Betreff + HTML aus `reset-password.html` einfügen  
4. **"Invite user"** → Betreff + HTML aus `invite-user.html` einfügen
5. **"Magic link"** → Betreff + HTML aus `magic-link.html` einfügen

## Betreffzeilen
- Signup:   `Mensaena – Bitte bestätige deine E-Mail ✓`
- Reset:    `Mensaena – Passwort zurücksetzen 🔑`
- Invite:   `Du wurdest zu Mensaena eingeladen 🌍`
- Magic:    `Dein Mensaena Anmeldelink 🌿`

## Wichtige Supabase-Auth-Einstellungen
→ https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/url-configuration

- **Site URL** MUSS eine reine Basis-URL sein: `https://www.mensaena.de`
  (KEIN Pfad, KEINE Query-Parameter!)
- **Redirect URLs** (Allow List):
  - `https://www.mensaena.de/**`
  - `https://mensaena.de/**`
  - `https://mensaena.pages.dev/**` (legacy, für Cloudflare-Preview)
  - `http://localhost:3000/**` (lokale Entwicklung)

> **Root-Cause fehlender Passwort-Reset-Mails (15.04.2026):**
> Die `site_url` war versehentlich auf `https://mensaena.de/auth?mode=reset`
> gesetzt – also mit Pfad und Query. Supabase verwendet `site_url` als Fallback
> für `redirectTo` und als Basis beim Templating der Mail-Links. Ein URL-String
> mit Query-Parametern führt zu ungültigen Links und zu stillschweigend
> verworfenen Mails. Fix: `site_url` auf `https://www.mensaena.de` gesetzt
> (Management API `PATCH /v1/projects/{ref}/config/auth`).

## SMTP / E-Mail-Versand
→ https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/providers
(Auth → Emails → SMTP Settings)

Der Mensaena-Account nutzt Custom-SMTP via `mail.lima-city.de:465` mit
`Info@online.de` als Absender. Das Supabase-Default-SMTP ist auf ~4 Mails/Stunde
limitiert und sollte nicht produktiv eingesetzt werden.

## Nach dem Ändern prüfen
1. Passwort-Reset auf https://www.mensaena.de/auth testen (mit echter Mailadresse).
2. E-Mail sollte innerhalb von ~30 Sekunden eintreffen.
3. Klick auf den Link öffnet `https://www.mensaena.de/auth?mode=reset`.
4. Falls keine E-Mail kommt → `wrangler tail` oder Supabase-Logs prüfen.
