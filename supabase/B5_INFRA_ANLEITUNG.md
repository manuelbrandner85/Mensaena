# B5 Infra – Manuelle Schritte im Supabase Dashboard

## 5.1 DNS (ERLEDIGT)
mensaena.de + www.mensaena.de zeigen auf Cloudflare Pages. SSL aktiv.

## 5.2 Auth URLs
Dashboard: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/url-configuration

1. **Site URL** setzen auf: `https://www.mensaena.de`
2. **Redirect URLs** hinzufuegen (alle 4):
   - `https://www.mensaena.de/**`
   - `https://mensaena.de/**`
   - `https://mensaena.pages.dev/**`
   - `http://localhost:3000/**`

## 5.3 Email-Templates
Dashboard: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/templates

Fuer jedes Template: HTML aus `supabase/templates/` kopieren und einfuegen.

| Template | Datei | Subject |
|---|---|---|
| Confirm signup | confirm_signup.html | Willkommen bei Mensaena – E-Mail bestaetigen |
| Reset password | reset_password.html | Mensaena – Passwort zuruecksetzen |
| Magic link | magic_link.html | Mensaena – Dein Anmelde-Link |
| Invite user | invite_user.html | Du wurdest zu Mensaena eingeladen! |

## 5.5 pg_cron aktivieren
Dashboard: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/database/extensions

1. Suche "pg_cron" und aktiviere die Extension
2. Danach im SQL Editor ausfuehren:
```
SELECT cron.schedule('daily-cleanup', '0 3 * * *', 'SELECT run_scheduled_cleanup()');
```

## 5.6 pg_net aktivieren
Dashboard: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/database/extensions

1. Suche "pg_net" und aktiviere die Extension

## 5.7 Secrets (ERLEDIGT)
SUPABASE_SERVICE_ROLE_KEY ist bereits als Cloudflare Worker Secret gesetzt.
NEXT_PUBLIC_SUPABASE_URL + NEXT_PUBLIC_SUPABASE_ANON_KEY sind in wrangler.toml als [vars].
