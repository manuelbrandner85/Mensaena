-- Fix #FR1: FKs auf friendships müssen profiles(id) sein, damit PostgREST
-- den embedded select profiles!friendships_*_fkey auflösen kann. Bisher
-- zeigten sie auf auth.users(id) → Empfänger sah die Anfrage ohne Name/
-- Avatar und konnte sie effektiv nicht annehmen.
alter table public.friendships
  drop constraint if exists friendships_requester_id_fkey,
  drop constraint if exists friendships_addressee_id_fkey;

alter table public.friendships
  add constraint friendships_requester_id_fkey
    foreign key (requester_id) references public.profiles(id) on delete cascade,
  add constraint friendships_addressee_id_fkey
    foreign key (addressee_id) references public.profiles(id) on delete cascade;

-- Fix #FR2: Trigger, der bei pending-Insert eine Notification an den
-- Empfänger anlegt und bei accept eine an den ursprünglichen Anfrager
-- (damit die Annahme sichtbar wird). Vorher gab es KEINE Notification —
-- daher wusste der Empfänger oft gar nicht, dass eine Anfrage offen ist.
create or replace function public.fn_friendship_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if (tg_op = 'INSERT' and new.status = 'pending') then
    select coalesce(p.display_name, p.name, 'common.neighbour')
      into v_name from public.profiles p where p.id = new.requester_id;
    insert into public.notifications
      (user_id, type, title, body, link, category, priority, actor_id)
    values (
      new.addressee_id,
      'friend_request',
      v_name,
      'Möchte sich mit dir verbinden',
      '/dashboard/friends',
      'social',
      'normal',
      new.requester_id
    );
  elsif (tg_op = 'UPDATE' and new.status = 'accepted' and old.status <> 'accepted') then
    select coalesce(p.display_name, p.name, 'common.neighbour')
      into v_name from public.profiles p where p.id = new.addressee_id;
    insert into public.notifications
      (user_id, type, title, body, link, category, priority, actor_id)
    values (
      new.requester_id,
      'friend_accepted',
      v_name,
      'Hat eure Verbindung bestätigt',
      '/dashboard/friends',
      'social',
      'normal',
      new.addressee_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_friendship_notify on public.friendships;
create trigger trg_friendship_notify
  after insert or update of status on public.friendships
  for each row execute function public.fn_friendship_notify();

-- Fix #FR3: schneller Server-RPC zum Annehmen — einfacher Pfad, der RLS
-- explizit prüft und idempotent ist (mehrfaches Tap = kein Error).
create or replace function public.accept_friend_request(p_requester uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows int;
begin
  update public.friendships
    set status = 'accepted',
        responded_at = now()
    where requester_id = p_requester
      and addressee_id = auth.uid()
      and status = 'pending';
  get diagnostics v_rows = row_count;
  return v_rows > 0
    or exists (
      select 1 from public.friendships
      where requester_id = p_requester
        and addressee_id = auth.uid()
        and status = 'accepted'
    );
end;
$$;

revoke all on function public.accept_friend_request(uuid) from public;
grant execute on function public.accept_friend_request(uuid) to authenticated;
