# Mensaena – Marketing & Retention (DSGVO-konform)

> **Grundregel:** Automatik NUR gegenüber bestehenden, eingewilligten Nutzern und
> über eigene/öffentliche Kanäle. KEINE automatischen Nachrichten an Fremde, KEIN
> automatisches Posten/Anschreiben auf externen Plattformen.

## Schutzregeln (in jeder sendenden Funktion erzwungen)
`supabase/functions/_shared/notify_guard.ts` → `marketingGuard(admin, {userId, optInColumn})`:
- **Notbremse:** `app_settings.marketing_paused = 'true'` stoppt sofort alles.
- **Opt-out:** sendet nur, wenn `profiles.<optInColumn>` = true.
- **Frequenz:** max. 1 Marketing-Push / 72h **und** max. 2 / 7 Tage. Gezählt werden
  nur Notifications mit `metadata.marketing = true` (transaktionale zählen nicht).
- **Stille Zeiten:** 22:00–08:00 (Europe/Berlin) → `scheduledFor` statt sofort.
- Jede Auto-Nachricht verlinkt `/dashboard/settings` (Abmeldung).

## Neue/erweiterte Edge Functions
| Function | Zweck | Auslöser |
|---|---|---|
| `reactivate-dormant` | Reaktivierung schlafender Nutzer (7+ Tage inaktiv, opt-in) | pg_cron tägl. 17:00 UTC |
| `ai-weekly-recap` (erweitert) | Wochenrückblick **+ teilbarer `share_text`** | pg_cron Mo 09:00 UTC |
| `confirm-email` *(geplant, s.u.)* | Double-Opt-in-Bestätigung | öffentlicher Link |
| `send-welcome-email` *(geplant, s.u.)* | 3-teilige Willkommensserie | pg_cron tägl. |

### Deploy (CI macht es automatisch bei Push auf main; manuell:)
```bash
supabase functions deploy reactivate-dormant ai-weekly-recap \
  --project-ref gyqujitkvymlmgroovch --no-verify-jwt
```

## pg_cron (bereits eingerichtet auf gyquj)
```sql
-- Reaktivierung schlafender Nutzer – täglich 17:00 UTC (= 19:00 Berlin, außerhalb
-- der Ruhezeit; stille Zeiten regelt notify_guard pro Nutzer)
SELECT cron.schedule('reactivate_dormant','0 17 * * *',
  $$SELECT public.invoke_edge_function('reactivate-dormant')$$);

-- Wöchentlicher Community-Rückblick – Montag 09:00 UTC
SELECT cron.schedule('ai_weekly_recap','0 9 * * 1',
  $$SELECT public.invoke_edge_function('ai-weekly-recap')$$);

-- (geplant) Willkommensserie – täglich 08:00 UTC
-- SELECT cron.schedule('send_welcome_email','0 8 * * *',
--   $$SELECT public.invoke_edge_function('send-welcome-email')$$);
```

## Einwilligung / Opt-out (Flutter)
- `profiles.marketing_opt_in` / `reactivation_opt_in` (Default true) / `email_opt_in`
  (Default false, nur via Double-Opt-in).
- Settings → Benachrichtigungen → Abschnitt „Marketing & Reaktivierung": zwei
  Toggles (live), i18n `privacy_prefs.*` in 7 Sprachen.

## Transactional-Mail (für die geplante E-Mail-Serie)
Es existiert bereits die Edge Function **`send-email`**, die SMTP-Daten aus
`private.email_config` liest (bei der Migration nach gyquj mitgenommen). Für die
Willkommensserie wird **kein neuer Anbieter** benötigt, solange `private.email_config`
gültige SMTP-Zugangsdaten enthält (Host/Port/User/Pass/From). Falls ein dedizierter
Dienst (z. B. Resend/Postmark) gewünscht ist: API-Key als Supabase-Secret
`RESEND_API_KEY` o. ä. hinterlegen und `send-email` darauf umstellen.

## Wöchentlichen Rückblick manuell posten (kein Auto-Posting!)
1. App-Dashboard → Karte „Diese Woche in der Gemeinschaft" → **„Diese Woche teilen"**
   (nutzt `community_recaps.share_text`, via `share_plus`).
2. Text erscheint im System-Share-Dialog → in den **eigenen** Social-Kanal
   (Instagram/Facebook/WhatsApp-Status der Mensaena-Seite) posten.
3. Niemals automatisiert/an Fremde – nur eigene Kanäle, manuell durch den Owner.

## Google Ad Grants (manuell, nur wenn gemeinnützig)
> Ad Grants sind ausschließlich für **gemeinnützige** Organisationen. Voraussetzung:
> anerkannte Gemeinnützigkeit + Google-for-Nonprofits-Konto.
1. **Gemeinnützigkeit nachweisen:** Google for Nonprofits (über TechSoup/Stifter-helfen)
   beantragen und verifizieren lassen.
2. **Ad-Grants-Konto:** in Google Ads aktivieren (max. 10.000 USD/Monat, 2 USD CPC-Cap,
   Smart Bidding erlaubt Cap-Überschreitung).
3. **Kampagnen** auf die Region-Landingpages (`/regionen/[slug]`, s. Punkt 4) ausrichten;
   Keywords rund um „Nachbarschaftshilfe {Stadt}", „Hilfe in der Nachbarschaft".
4. **Conversion-Tracking:** Ziel = abgeschlossene Registrierung. In Google Ads ein
   Conversion-Event anlegen und auf der Danke-/Dashboard-Seite auslösen.
5. Pflichten beachten: ≥5 % CTR halten, Konto aktiv pflegen, gültige Conversions.

## Technische Basis (Punkt 6) – Status
- ✅ Conversion-fähige Registrierung + sauberes SEO/Open-Graph (Web).
- ⏳ **Region-Landingpages `/regionen/[slug]`** (Next.js) + `sitemap.ts`-Erweiterung:
  aggregierte Zahlen (keine personenbezogenen Daten), schema.org LocalBusiness,
  OG-Tags. **Offen** (Fokus dieser Iteration war die Flutter-App).

## Offene Folgeschritte (dokumentiert)
- **E-Mail-Willkommensserie** (`send-welcome-email` + `confirm-email` + Double-Opt-in-
  Toggle in Settings + Mailtexte 7 Sprachen).
- **Meilenstein-Feier-Sheet** (erste Hilfe / Karma-Stufe / 1. Event/Gruppe →
  CelebrateBurst → „Teile deinen Moment" / „Lade Nachbarn ein").
- **Next.js Region-Landingpages** + sitemap (Punkt 4).

---

## Phase 3 + 4 — Automatik (Backend, selbstlaufend via pg_cron)

Alle sendenden Funktionen erzwingen `_shared/notify_guard.ts` (Notbremse
`marketing_paused`, Opt-out je Spalte, Frequenz 1/72h & 2/7d, stille Zeiten
22–8 Berlin). Automatik nur gegenüber bestehenden, eingewilligten Nutzern —
**kein** automatisches externes Posten/Anschreiben.

### Phase 3 (bereits live)
- `auto-milestones-dates` — Jubiläen („1 Jahr dabei") + runde Hilfe-Zahlen → Karma + Glückwunsch.
- `reactivate-dormant` — Eskalation 7/21/45 Tage (`reactivation_log`), danach Ruhe.
- `region-ignite-alert` — Region ≥ 20 aktiv → Admin-Notification + KI-Tipp (idempotent).
- Empfehlungs-Belohnung (3/5/10) → Karma + Badge + Gratulation (DB-Trigger).

### Phase 4 (neu, dieser Stand)
| Function | Zweck | Tabelle |
|---|---|---|
| `auto-social-content` | KI erzeugt aus anonymen Wochenzahlen teilbare Posts → Entwürfe | `content_plan` (status=draft) |
| `auto-health-report` | KI-Wochenbericht (Wachstum/Regionen/Empfehlungen) → Admin-Notif + optional Owner-Mail | — |
| `auto-smart-timing` | lernt beste Versand-Stunde (global + pro Region) aus Öffnungen | `send_time_pref` ← `campaign_events` |
| `feedback-after-help` | freundliche Bitte um Erfahrungsbericht nach abgeschlossener Hilfe | (→ `testimonials`) |
| `auto-winback` | bei abbestelltem Kanal sparsam verbleibenden erlaubten Kanal nutzen | — |

**Content-Planer (Flutter-Admin, Tab „Content-Planer"):** listet `content_plan`,
erstellen/bearbeiten/teilen (`share_plus`) und **manuell** veröffentlichen.
KI-Social-Posts landen als Entwurf — Freigabe ausschließlich per Klick (kein Auto-Posting).

### Deploy
Functions deployen automatisch über `.github/workflows/supabase.yml` bei Push
auf `main` (Ordner `supabase/functions/*`). Migration `20260606170000_marketing_phase4.sql`
(`content_plan`, `send_time_pref`, `campaign_events` + RLS) deployt im selben Lauf.

Benötigte Secrets (Supabase → Edge Functions → Secrets): `MAIL_API_KEY` (Resend,
bereits gesetzt), optional `MAIL_OWNER` (Empfänger des Health-Reports) **oder**
`app_settings`-Key `owner_email`.

### pg_cron — neue Jobs (✅ automatisch via Migration, KEIN manueller Schritt)
> **Status: eingerichtet.** Migration `20260606200000_marketing_phase4_cron.sql`
> legt einen Helper `private.invoke_edge_function(text)` + die 5 Cron-Jobs an.
> Deployt automatisch über `.github/workflows/supabase.yml` (`supabase db push`)
> bei Push auf `main` gegen `gyqujitkvymlmgroovch`.
>
> Auth läuft über den öffentlichen anon-Key aus `private.push_config` — kein
> service_role-Key im Repo nötig (die Functions sind `--no-verify-jwt` deployed,
> der anon-Key genügt zum Routing; intern nutzen sie SERVICE_ROLE aus ihrer
> eigenen Secret-Env). Stille Zeiten erzwingt der `notify_guard`; die Cron-Zeiten
> liegen bewusst tagsüber (UTC). Das Scheduling ist idempotent (Upsert pro
> Jobname) und drift-tolerant (no-op wenn `cron`-Schema fehlt, z. B. Preview).

| Job | Zeitplan (UTC) | Function |
|---|---|---|
| `auto-social-content` | Mo 08:00 (`0 8 * * 1`) | KI-Social-Entwürfe → `content_plan` |
| `auto-health-report` | Mo 07:00 (`0 7 * * 1`) | KI-Wochenbericht → Admin/Owner |
| `auto-smart-timing` | So 23:00 (`0 23 * * 0`) | beste Versand-Stunde lernen |
| `feedback-after-help` | täglich 16:00 (`0 16 * * *`) | Bitte um Erfahrungsbericht |
| `auto-winback` | Mi 15:00 (`0 15 * * 3`) | sparsamer Win-Back |

Jobs prüfen: `select jobname, schedule, active from cron.job order by jobname;`
