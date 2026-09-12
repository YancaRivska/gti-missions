drop policy if exists "GTI Missions users can update own avatar" on storage.objects;
create policy "GTI Missions users can update own avatar" on storage.objects for update to authenticated
using (bucket_id='gti-missions-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false)
with check (bucket_id='gti-missions-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.1'));
