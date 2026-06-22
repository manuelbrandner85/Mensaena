-- Zwei Bugfixes:
-- 1) Livestream-Einladung schlug fehl, weil der Client eine notifications-Row
--    für den EINGELADENEN (user_id = invitee) inserten wollte, die INSERT-RLS
--    aber nur user_id = auth.uid() erlaubt. Lösung: SECURITY DEFINER RPC, das
--    die Einladung serverseitig (RLS-bypass) erzeugt. actor_id = auth.uid().
-- 2) Selbst erstellte Community-Räume waren nicht löschbar (keine DELETE-RLS,
--    keine RPC, kein UI). Lösung: SECURITY DEFINER RPC, das nur Ersteller
--    (chat_channels.created_by / conversation_members.role='owner') ODER Admin
--    löschen lässt. ON-DELETE-CASCADE räumt Kanal/Mitglieder/Nachrichten ab.

-- ── 1) Livestream-Einladung ────────────────────────────────────────────────
create or replace function public.invite_to_livestream(
  p_invitee uuid,
  p_room text,
  p_title text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_host uuid := auth.uid();
  v_name text;
begin
  if v_host is null then
    raise exception 'auth required';
  end if;
  if v_host = p_invitee then
    raise exception 'cannot invite self';
  end if;

  select coalesce(display_name, name, 'Jemand') into v_name
  from profiles where id = v_host;

  insert into public.notifications
    (user_id, actor_id, type, category, title, body, link, metadata)
  values (
    p_invitee,
    v_host,
    'livestream_invite',
    'system',
    'Livestream-Einladung',
    coalesce(v_name, 'Jemand') || ' lädt dich in einen Livestream ein.',
    '/dashboard/live/' || p_room || '?host=0',
    jsonb_build_object('room_name', p_room)
      || case when p_title is not null
              then jsonb_build_object('title', p_title)
              else '{}'::jsonb end
  );
end;
$$;

grant execute on function public.invite_to_livestream(uuid, text, text) to authenticated;

-- ── 2) Community-Raum löschen ──────────────────────────────────────────────
create or replace function public.delete_community_channel(
  p_conversation uuid
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_creator uuid;
  v_is_owner boolean := false;
begin
  if v_uid is null then
    raise exception 'auth required';
  end if;

  select (role = 'admin') into v_is_admin from profiles where id = v_uid;

  select created_by into v_creator
  from chat_channels where conversation_id = p_conversation;

  select exists (
    select 1 from conversation_members
    where conversation_id = p_conversation
      and user_id = v_uid
      and role = 'owner'
  ) into v_is_owner;

  if not coalesce(v_is_admin, false)
     and v_creator is distinct from v_uid
     and not v_is_owner then
    raise exception 'not allowed';
  end if;

  -- ON DELETE CASCADE entfernt chat_channels, conversation_members,
  -- messages, message_pins, live_rooms, live_locations, announcements.
  delete from conversations where id = p_conversation;
end;
$$;

grant execute on function public.delete_community_channel(uuid) to authenticated;
