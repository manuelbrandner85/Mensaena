-- M1: Kommentare/Anfragen unter Marktplatz-Inseraten.
-- Spiegelt post_comments. flat (kein Threading nötig für Inserate).
create table if not exists public.marketplace_comments (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.marketplace_listings(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_marketplace_comments_listing
  on public.marketplace_comments(listing_id, created_at);

alter table public.marketplace_comments enable row level security;

-- Lesen: jede:r authentifizierte Nutzer:in (gelöschte werden client-seitig
-- via deleted_at ausgeblendet).
drop policy if exists mc_select on public.marketplace_comments;
create policy mc_select on public.marketplace_comments
  for select to authenticated using (true);

-- Schreiben: nur als man selbst.
drop policy if exists mc_insert on public.marketplace_comments;
create policy mc_insert on public.marketplace_comments
  for insert to authenticated with check (user_id = auth.uid());

-- Löschen: eigener Kommentar ODER Inserats-Besitzer (Moderation).
drop policy if exists mc_delete on public.marketplace_comments;
create policy mc_delete on public.marketplace_comments
  for delete to authenticated using (
    user_id = auth.uid()
    or exists (
      select 1 from public.marketplace_listings l
      where l.id = listing_id
        and (l.user_id = auth.uid() or l.seller_id = auth.uid())
    )
  );

-- Eigenen Kommentar als gelöscht markieren dürfen (soft-delete via update).
drop policy if exists mc_update on public.marketplace_comments;
create policy mc_update on public.marketplace_comments
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());
