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
→ https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/auth/providers

- **Site URL** auf `https://mensaena.pages.dev` setzen
- **Redirect URLs** hinzufügen:
  - `https://mensaena.pages.dev/**`
  - `http://localhost:3000/**`
