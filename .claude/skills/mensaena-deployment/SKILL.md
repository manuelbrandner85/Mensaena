---
name: mensaena-deployment
description: Deploy-Workflow und CI/CD für Mensaena
globs: [".github/workflows/**", "wrangler.toml", "open-next.config.*", "capacitor.config.*"]
---

# Mensaena Deployment

## Web (Cloudflare Pages + Workers)
1. npm run build
2. git add -A && git commit
3. git push origin main
→ GitHub Actions deployed automatisch

## Deploy-Workflow (.github/workflows/deploy.yml)
1. npm ci
2. npx opennextjs-cloudflare build
3. mv open-next.config.ts _open-next.config.ts.ci-skip
4. npx wrangler deploy
WICHTIG: Das mv ist zwingend! Wrangler 4.x erkennt die Datei und
ruft opennextjs-cloudflare deploy auf → Error 10000.

## Android (Capacitor)
- npm run cap:build → npm run cap:sync → Gradle assembleRelease
- GitHub Actions: android.yml → signierte APK + GitHub Release

## NIEMALS im Deploy-Workflow
- Supabase CLI / supabase db push
- Weitere Build-Schritte

## Supabase Migrationen
- Dateien in supabase/migrations/
- Manuell: Supabase Dashboard SQL Editor
- Oder: Management API mit Access Token
