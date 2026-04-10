# B5 Infra – Alle Schritte erledigt
> Aktualisiert: 2026-04-10

## 5.1 DNS (ERLEDIGT)
mensaena.de + www.mensaena.de zeigen auf Cloudflare Pages. SSL aktiv.

## 5.2 Auth URLs (ERLEDIGT - via Management API)
- Site URL: `https://www.mensaena.de`
- Redirect URLs: `https://www.mensaena.de/**`, `https://mensaena.de/**`, `https://mensaena.pages.dev/**`, `http://localhost:3000/**`

## 5.3 Email-Templates (ERLEDIGT - via Management API)
4 Templates + deutsche Subjects gesetzt:
- Confirm signup: `Willkommen bei Mensaena - E-Mail bestaetigen`
- Reset password: `Mensaena - Passwort zuruecksetzen`
- Magic link: `Mensaena - Dein Anmelde-Link`
- Invite user: `Du wurdest zu Mensaena eingeladen!`

## 5.4 Storage RLS (ERLEDIGT)
8 Buckets, 28 Policies. Alle Buckets haben SELECT/INSERT/DELETE Policies.

## 5.5 pg_cron (ERLEDIGT - via Management API)
- Extension: pg_cron v1.6.4 aktiviert
- Cron-Job: `daily-cleanup` um 03:00 UTC (`SELECT run_scheduled_cleanup()`)

## 5.6 pg_net (ERLEDIGT - via Management API)
- Extension: pg_net v0.20.0 aktiviert

## 5.7 Secrets (ERLEDIGT)
SUPABASE_SERVICE_ROLE_KEY ist als Cloudflare Worker Secret gesetzt.
NEXT_PUBLIC_SUPABASE_URL + NEXT_PUBLIC_SUPABASE_ANON_KEY sind in wrangler.toml als [vars].

## 5.8 Auth Redirect (ERLEDIGT)
emailRedirectTo im signUp-Code gesetzt (auth/page.tsx).

## 5.9 Email-Template-Dateien (ERLEDIGT)
4 HTML-Dateien in supabase/templates/ erstellt.

## 5.10 Deploy (ERLEDIGT)
mensaena.de + www.mensaena.de live auf Cloudflare Pages.
