-- Run in Supabase SQL Editor for the project used by CIHUY.
-- Existing bucket name verified from the dashboard: photo-profil.
-- No tables or columns are created or changed.
begin;

do $$
begin
  if not exists (select 1 from storage.buckets where id = 'photo-profil') then
    raise exception 'Bucket photo-profil does not exist. Check the Storage dashboard.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'avatar_url'
  ) then
    raise exception 'Expected public.profiles.avatar_url was not found.';
  end if;
end $$;

update storage.buckets
set public = false,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/png', 'image/jpeg']
where id = 'photo-profil';

-- Only these app-owned policies are replaced when this script is rerun.
drop policy if exists cihuy_profile_photo_read on storage.objects;
drop policy if exists cihuy_profile_photo_insert on storage.objects;
drop policy if exists cihuy_profile_photo_delete on storage.objects;

create policy cihuy_profile_photo_read on storage.objects
for select to authenticated
using (bucket_id = 'photo-profil' and (storage.foldername(name))[1] = (select auth.uid()::text));

create policy cihuy_profile_photo_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'photo-profil' and (storage.foldername(name))[1] = (select auth.uid()::text));

create policy cihuy_profile_photo_delete on storage.objects
for delete to authenticated
using (bucket_id = 'photo-profil' and (storage.foldername(name))[1] = (select auth.uid()::text));

-- Upload uses a new filename each time (upsert=false), so no UPDATE policy is needed.
-- public.profiles already has owner-only SELECT/UPDATE policies in the initial migration.
commit;

select id, public, file_size_limit, allowed_mime_types
from storage.buckets where id = 'photo-profil';
select policyname, cmd, roles, qual, with_check
from pg_policies where schemaname = 'storage' and tablename = 'objects';
