drop policy if exists "GTI Missions users can upload checkin proof" on storage.objects;
create policy "GTI Missions users can upload checkin proof" on storage.objects for insert to authenticated
with check (
  bucket_id='gti-missions-checkins'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.1')
);

drop policy if exists "GTI Missions users and admins can view checkin proof" on storage.objects;
create policy "GTI Missions users and admins can view checkin proof" on storage.objects for select to authenticated
using (
  bucket_id='gti-missions-checkins'
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or exists(select 1 from public.gti_missions_admins a where a.user_id=(select auth.uid()))
  )
);

drop policy if exists "GTI Missions users can upload own avatar" on storage.objects;
create policy "GTI Missions users can upload own avatar" on storage.objects for insert to authenticated
with check (
  bucket_id='gti-missions-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
);

drop policy if exists "GTI Missions users can update own avatar" on storage.objects;
create policy "GTI Missions users can update own avatar" on storage.objects for update to authenticated
using (
  bucket_id='gti-missions-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
)
with check (
  bucket_id='gti-missions-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
);

drop policy if exists "GTI Missions users can delete own avatar" on storage.objects;
create policy "GTI Missions users can delete own avatar" on storage.objects for delete to authenticated
using (
  bucket_id='gti-missions-avatars'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
);

drop policy if exists "GTI Missions players can view avatars" on storage.objects;
create policy "GTI Missions players can view avatars" on storage.objects for select to authenticated
using (
  bucket_id='gti-missions-avatars'
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.1')
  )
);
