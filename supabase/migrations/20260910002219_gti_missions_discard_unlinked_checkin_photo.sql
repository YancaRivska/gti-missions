drop policy if exists "GTI Missions users can delete unlinked checkin proof" on storage.objects;
create policy "GTI Missions users can delete unlinked checkin proof" on storage.objects for delete to authenticated
using (
  bucket_id='gti-missions-checkins'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and not exists(select 1 from public.gti_missions_challenge_entries e where e.photo_path=storage.objects.name)
);
