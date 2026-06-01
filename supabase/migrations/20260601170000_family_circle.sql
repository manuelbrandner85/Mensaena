-- R3: Familien-Kreis — vertrauenswürdiger Kreis + Sicherheits-Alarme.
create table if not exists public.trusted_contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid not null references public.profiles(id) on delete cascade,
  relation_label text,
  status text not null default 'pending', -- pending | accepted | declined
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (owner_id, contact_id),
  check (owner_id <> contact_id)
);

create index if not exists idx_trusted_owner on public.trusted_contacts(owner_id, status);
create index if not exists idx_trusted_contact on public.trusted_contacts(contact_id, status);

alter table public.trusted_contacts enable row level security;

-- Lesen: ich als Eigentümer:in ODER als angefragte Person.
drop policy if exists tc_select on public.trusted_contacts;
create policy tc_select on public.trusted_contacts
  for select to authenticated using (
    owner_id = auth.uid() or contact_id = auth.uid()
  );

-- Anlegen passiert über RPC (security definer); Direkt-Insert nur als self.
drop policy if exists tc_insert on public.trusted_contacts;
create policy tc_insert on public.trusted_contacts
  for insert to authenticated with check (owner_id = auth.uid());

-- Aktualisieren: angefragte Person (annehmen/ablehnen) ODER Eigentümer:in.
drop policy if exists tc_update on public.trusted_contacts;
create policy tc_update on public.trusted_contacts
  for update to authenticated using (
    contact_id = auth.uid() or owner_id = auth.uid()
  );

-- Löschen: beide Seiten dürfen die Verbindung entfernen.
drop policy if exists tc_delete on public.trusted_contacts;
create policy tc_delete on public.trusted_contacts
  for delete to authenticated using (
    owner_id = auth.uid() or contact_id = auth.uid()
  );

-- Sicherheits-Alarme (SOS / "Ich bin sicher") an den eigenen Kreis.
create table if not exists public.circle_alerts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'sos', -- sos | safe
  message text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create index if not exists idx_circle_alerts_sender on public.circle_alerts(sender_id, created_at);

alter table public.circle_alerts enable row level security;

-- Lesen: ich selbst ODER jemand, mit dem ich eine angenommene
-- Vertrauens-Verbindung habe (in beide Richtungen).
drop policy if exists ca_select on public.circle_alerts;
create policy ca_select on public.circle_alerts
  for select to authenticated using (
    sender_id = auth.uid()
    or exists (
      select 1 from public.trusted_contacts t
      where t.status = 'accepted'
        and (
          (t.owner_id = circle_alerts.sender_id and t.contact_id = auth.uid())
          or (t.contact_id = circle_alerts.sender_id and t.owner_id = auth.uid())
        )
    )
  );

-- Senden: nur als sich selbst.
drop policy if exists ca_insert on public.circle_alerts;
create policy ca_insert on public.circle_alerts
  for insert to authenticated with check (sender_id = auth.uid());

drop policy if exists ca_delete on public.circle_alerts;
create policy ca_delete on public.circle_alerts
  for delete to authenticated using (sender_id = auth.uid());

-- RPC: Kontakt per E-Mail anfragen (lookupt Profil, legt pending-Zeile an).
create or replace function public.request_trusted_contact(
  p_email text,
  p_relation text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contact uuid;
begin
  select id into v_contact from public.profiles
    where lower(email) = lower(trim(p_email)) limit 1;
  if v_contact is null then
    return 'not_found';
  end if;
  if v_contact = auth.uid() then
    return 'self';
  end if;
  insert into public.trusted_contacts (owner_id, contact_id, relation_label, status)
    values (auth.uid(), v_contact, nullif(trim(coalesce(p_relation,'')), ''), 'pending')
    on conflict (owner_id, contact_id) do nothing;
  return 'ok';
end;
$$;

revoke all on function public.request_trusted_contact(text, text) from public;
grant execute on function public.request_trusted_contact(text, text) to authenticated;
