-- Image-Upload-Audit: knowledge_repository.dart referenziert bucket
-- 'knowledge-images', der nie angelegt war. Fallback ging silently auf
-- chat-images → Wissens-Bilder landeten im falschen Bucket. Wir legen den
-- Bucket sauber an + Policies analog event-images.
insert into storage.buckets (id, name, public)
values ('knowledge-images', 'knowledge-images', true)
on conflict (id) do nothing;

drop policy if exists "knowledge_images_select" on storage.objects;
create policy "knowledge_images_select" on storage.objects
  for select using (bucket_id = 'knowledge-images');

drop policy if exists "knowledge_images_insert" on storage.objects;
create policy "knowledge_images_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'knowledge-images'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "knowledge_images_delete" on storage.objects;
create policy "knowledge_images_delete" on storage.objects
  for delete to authenticated using (
    bucket_id = 'knowledge-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
