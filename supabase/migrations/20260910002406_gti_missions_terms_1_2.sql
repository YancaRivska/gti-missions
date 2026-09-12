alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_terms_version_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_terms_version_check check (terms_version is null or terms_version in ('1.0','1.1','1.2'));

do $$
declare r record; v_def text;
begin
  for r in
    select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prokind='f' and p.proname in (
      'gti_missions_custom_challenge_statuses','gti_missions_join_challenge','gti_missions_leaderboard',
      'gti_missions_log_custom_challenge','gti_missions_log_exercise','gti_missions_log_water','gti_missions_my_stats'
    ) and pg_get_functiondef(p.oid) like '%1.1%'
  loop
    v_def:=pg_get_functiondef(r.oid);
    v_def:=replace(v_def,'''1.1''','''1.2''');
    execute v_def;
  end loop;
end $$;

drop policy if exists gti_missions_challenges_select_players on public.gti_missions_challenges;
create policy gti_missions_challenges_select_players on public.gti_missions_challenges for select to authenticated
using (
  coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and (
    exists(select 1 from public.gti_missions_admins a where a.user_id=(select auth.uid()))
    or (
      is_active and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.2')
    )
  )
);

drop policy if exists "GTI Missions players can view avatars" on storage.objects;
create policy "GTI Missions players can view avatars" on storage.objects for select to authenticated
using (
  bucket_id='gti-missions-avatars'
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.2')
  )
);

drop policy if exists "GTI Missions users can upload checkin proof" on storage.objects;
create policy "GTI Missions users can upload checkin proof" on storage.objects for insert to authenticated
with check (
  bucket_id='gti-missions-checkins'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.2')
);
