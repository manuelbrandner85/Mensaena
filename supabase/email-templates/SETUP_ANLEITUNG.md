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

- **Site URL** auf `https://www.mensaena.de` setzen
- **Redirect URLs** (Allow List) MUSS alle diese Einträge enthalten:
  - `https://www.mensaena.de/**`
  - `https://mensaena.de/**`
  - `https://mensaena.pages.dev/**` (legacy, für Cloudflare-Preview)
  - `http://localhost:3000/**` (lokale Entwicklung)

> **Wichtig:** Fehlen `www.mensaena.de/**` in der Redirect-URL-Liste, werden
> `resetPasswordForEmail`-Aufrufe mit `redirectTo: https://www.mensaena.de/auth?mode=reset`
> stillschweigend verworfen – der Nutzer sieht keine Fehlermeldung, erhält aber
> auch keine E-Mail. Das war der Grund für fehlende Passwort-Reset-Mails.

## SMTP / E-Mail-Versand
→ https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/providers
(Auth → Emails → SMTP Settings)

Die Supabase-Standard-SMTP hat ein Rate-Limit von **~4 E-Mails/Stunde** und ist
nur für Tests gedacht. Für Produktion sollte ein eigener SMTP-Provider
konfiguriert werden (Resend, Postmark, SendGrid, …). Ohne eigenen SMTP gehen
Reset-Mails verloren, sobald das Limit erreicht ist.

## Nach dem Ändern prüfen
1. Passwort-Reset auf https://www.mensaena.de/auth testen (mit echter Mailadresse).
2. E-Mail sollte innerhalb von ~30 Sekunden eintreffen.
3. Klick auf den Link öffnet `https://www.mensaena.de/auth?mode=reset`.
4. Falls keine E-Mail kommt → `wrangler tail` oder Supabase-Logs prüfen.
