create extension if not exists pgcrypto;

alter table public.gti_missions_profiles
  add column if not exists avatar_path text,
  add column if not exists height_cm numeric(5,1),
  add column if not exists weight_kg numeric(5,1);

update public.gti_missions_profiles set exercise_weekly_target=3 where exercise_weekly_target<3;
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_exercise_weekly_target_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_exercise_weekly_target_check check (exercise_weekly_target between 3 and 7);
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_terms_version_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_terms_version_check check (terms_version is null or terms_version in ('1.0','1.1'));
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_avatar_path_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_avatar_path_check check (avatar_path is null or char_length(avatar_path) <= 300);
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_height_cm_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_height_cm_check check (height_cm is null or height_cm between 100 and 250);
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_weight_kg_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_weight_kg_check check (weight_kg is null or weight_kg between 30 and 300);

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('gti-missions-avatars','gti-missions-avatars',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "GTI Missions players can view avatars" on storage.objects;
create policy "GTI Missions players can view avatars" on storage.objects for select to authenticated
using (bucket_id='gti-missions-avatars' and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.1'));

drop policy if exists "GTI Missions users can upload own avatar" on storage.objects;
create policy "GTI Missions users can upload own avatar" on storage.objects for insert to authenticated
with check (bucket_id='gti-missions-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.1'));

drop policy if exists "GTI Missions users can update own avatar" on storage.objects;
create policy "GTI Missions users can update own avatar" on storage.objects for update to authenticated
using (bucket_id='gti-missions-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check (bucket_id='gti-missions-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.1'));

drop policy if exists "GTI Missions users can delete own avatar" on storage.objects;
create policy "GTI Missions users can delete own avatar" on storage.objects for delete to authenticated
using (bucket_id='gti-missions-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false);

create table if not exists public.gti_missions_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin','owner')),
  created_at timestamptz not null default now()
);
alter table public.gti_missions_admins enable row level security;
drop policy if exists gti_missions_admins_select_self on public.gti_missions_admins;
create policy gti_missions_admins_select_self on public.gti_missions_admins for select to authenticated
using (user_id=(select auth.uid()) and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false);
revoke all on public.gti_missions_admins from anon;
grant select on public.gti_missions_admins to authenticated;

create table if not exists public.gti_missions_admin_bootstrap (
  id smallint primary key default 1 check (id=1),
  code_hash text not null,
  created_at timestamptz not null default now()
);
alter table public.gti_missions_admin_bootstrap enable row level security;
revoke all on public.gti_missions_admin_bootstrap from anon, authenticated;
-- Credencial histórica omitida: o bootstrap compartilhado foi desativado.
