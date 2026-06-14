-- ============================================================================
-- Stellt die Storage-Buckets für Profilbilder/Cover/Post-Bilder samt RLS sicher.
--
-- Hintergrund: Die Bucket-/Policy-Definition lag bisher NUR in der Standalone-
-- Datei supabase/005_fix_avatars_storage.sql, die NICHT in migrations/ liegt und
-- daher von supabase.yml nie automatisch ausgeführt wird. Fehlte der Bucket oder
-- die INSERT-Policy auf einer Umgebung, schlug der Avatar-Upload fehl
-- ("Profilbild hochladen dann speichern" ging nicht). Diese Migration macht den
-- Zustand reproduzierbar + idempotent und ergänzt HEIC/HEIF (iPhone-Fotos).
-- ============================================================================

-- ── Buckets (public read, Größen-Limit, erlaubte MIME-Typen inkl. HEIC) ──────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif']),
  ('covers', 'covers', true, 10485760,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif']),
  ('post-images', 'post-images', true, 10485760,
   array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif'])
on conflict (id) do update set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ── RLS-Policies pro Bucket (idempotent neu setzen) ──────────────────────────
-- Public read, eingeloggte User dürfen Upload/Update/Delete. Pfad-Konvention im
-- Client ist <uid>/<datei>, der Bucket ist public lesbar (wie Firebase-Avatare).
do $$
declare
  b text;
begin
  foreach b in array array['avatars','covers','post-images'] loop
    execute format('drop policy if exists %I on storage.objects', b || '_public_select');
    execute format('drop policy if exists %I on storage.objects', b || '_auth_insert');
    execute format('drop policy if exists %I on storage.objects', b || '_auth_update');
    execute format('drop policy if exists %I on storage.objects', b || '_auth_delete');

    execute format($f$
      create policy %I on storage.objects for select
      using (bucket_id = %L)
    $f$, b || '_public_select', b);

    execute format($f$
      create policy %I on storage.objects for insert
      with check (bucket_id = %L and auth.role() = 'authenticated')
    $f$, b || '_auth_insert', b);

    execute format($f$
      create policy %I on storage.objects for update
      using (bucket_id = %L and auth.role() = 'authenticated')
      with check (bucket_id = %L and auth.role() = 'authenticated')
    $f$, b || '_auth_update', b, b);

    execute format($f$
      create policy %I on storage.objects for delete
      using (bucket_id = %L and auth.role() = 'authenticated')
    $f$, b || '_auth_delete', b);
  end loop;
end $$;
