# Schema-Drift: nicht-versionierte DB-Objekte

**Stand:** 2026-06-05 · Audit gegen `supabase/migrations/`

Die laufende App referenziert die folgenden Tabellen und RPCs, die in
**keiner Migrations-Datei** definiert sind. Sie existieren in der Live-DB
(per Supabase-Dashboard / Management-API angelegt — siehe CLAUDE.md
Workflow), wurden aber nie als Migration committet.

**Risiko:** Wiederaufbau aus dem Repo (Disaster-Recovery, frische
Umgebung, CI-Shadow-DB) erzeugt diese Objekte nicht. Ihre RLS ist im Repo
nicht reviewbar.

**Auflösung:** Pro Objekt das DDL aus der Live-DB exportieren
(`pg_dump --schema-only -t public.<name>` oder Dashboard → Table → Definition)
und als versionierte Migration nachziehen, danach RLS prüfen.

## Tabellen (60 Stück)

- [ ] `account_deletion_requests`
- [ ] `app_releases`
- [ ] `app_settings`
- [ ] `bot_feedback`
- [ ] `call_voicemails`
- [ ] `circle_alerts`
- [ ] `community_poll_votes`
- [ ] `community_polls`
- [ ] `crash_logs`
- [ ] `crisis_resources`
- [ ] `crisis_tasks`
- [ ] `daily_challenges`
- [ ] `error_logs`
- [ ] `event_checkins`
- [ ] `event_photos`
- [ ] `event_rideshares`
- [ ] `farm_favorites`
- [ ] `feature_flags`
- [ ] `followed_tags`
- [ ] `friendships`
- [ ] `group_events`
- [ ] `group_invitations`
- [ ] `group_join_requests`
- [ ] `group_post_comments`
- [ ] `karma_log`
- [ ] `knowledge_article_reads`
- [ ] `live_locations`
- [ ] `livestream_gifts`
- [ ] `livestream_messages`
- [ ] `marketplace_comments`
- [ ] `marketplace_favorites`
- [ ] `marketplace_messages`
- [ ] `marketplace_reports`
- [ ] `marketplace_reservations`
- [ ] `mentorships`
- [ ] `mood_entries`
- [ ] `organization_invites`
- [ ] `organization_members`
- [ ] `post_contact_preferences`
- [ ] `post_contact_requests`
- [ ] `post_drafts`
- [ ] `post_poll_votes`
- [ ] `post_polls`
- [ ] `post_reposts`
- [ ] `post_templates`
- [ ] `profile_views`
- [ ] `save_collections`
- [ ] `saved_events`
- [ ] `scheduled_broadcasts`
- [ ] `scheduled_calls`
- [ ] `scheduled_stream_reminders`
- [ ] `scheduled_streams`
- [ ] `stories`
- [ ] `story_views`
- [ ] `stream_clips`
- [ ] `thank_you_cards`
- [ ] `trusted_contacts`
- [ ] `user_safety_checkins`
- [ ] `user_streaks`
- [ ] `voicemails`

## RPCs / Functions (14 Stück)

- [ ] `admin_count_users()`
- [ ] `admin_get_table_columns()`
- [ ] `admin_hard_delete_message()`
- [ ] `approve_group_join()`
- [ ] `check_and_award_badges()`
- [ ] `complete_daily_challenge()`
- [ ] `delete_my_account()`
- [ ] `get_trust_breakdown()`
- [ ] `hide_all_dm_calls_for_me()`
- [ ] `hide_dm_call_for_me()`
- [ ] `invite_user_to_group()`
- [ ] `refresh_matches()`
- [ ] `request_trusted_contact()`
- [ ] `send_livestream_gift()`

## Hinweis

- `v_unread_counts` ist ein **View** (in 20260422030000_performance_views.sql
  definiert) — kein Drift, nur in der Extraktion zunächst als Tabelle gezählt.
- Edge-Function-Referenzen wurden separat geprüft: **alle vorhanden**.
- Diese Liste stammt aus statischer Code-Analyse (`.from()` / `.rpc()`);
  ein echter Voll-Abgleich braucht Live-DB-Zugriff (separater Audit-Schritt).
