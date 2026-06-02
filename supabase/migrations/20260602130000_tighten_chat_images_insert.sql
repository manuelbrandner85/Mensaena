-- Sicherheits-Fix: chat_images_insert hatte KEINE Auth-Prüfung
-- (with_check = bucket_id='chat-images') → anonyme Uploads möglich.
-- Wir verlangen jetzt Authentifizierung. Pfad-Format bleibt unverändert
-- (kein uid-Prefix erzwungen, um bestehende Uploads nicht zu brechen).
drop policy if exists chat_images_insert on storage.objects;
create policy chat_images_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chat-images' and auth.uid() is not null);
