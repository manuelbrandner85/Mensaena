-- ============================================================
-- Bot-Feedback Tabelle: persistente 👍/👎-Bewertungen aus dem
-- Mensaena-Bot. Wird vom /api/bot/feedback-Endpoint befüllt
-- und im Admin-Dashboard ausgewertet.
-- ============================================================

create table if not exists public.bot_feedback (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid references auth.users(id) on delete set null,
  message_id text,
  rating text not null check (rating in ('up','down')),
  question text,
  answer text,
  route text
);

create index if not exists bot_feedback_created_idx on public.bot_feedback(created_at desc);
create index if not exists bot_feedback_rating_idx  on public.bot_feedback(rating);
create index if not exists bot_feedback_route_idx   on public.bot_feedback(route);

alter table public.bot_feedback enable row level security;

-- Jeder (auch anonym) darf Feedback einwerfen — die Write-Surface ist
-- bewusst simpel, damit der Bot offline/anonym weiter Signale einsammelt.
drop policy if exists bot_feedback_insert on public.bot_feedback;
create policy bot_feedback_insert on public.bot_feedback
  for insert
  with check (true);

-- Nur Admins und Moderatoren dürfen lesen (Dashboard-Auswertung).
drop policy if exists bot_feedback_admin_read on public.bot_feedback;
create policy bot_feedback_admin_read on public.bot_feedback
  for select
  using (
    exists (
      select 1 from public.profiles
      where profiles.id = auth.uid()
        and profiles.role in ('admin','moderator')
    )
  );
