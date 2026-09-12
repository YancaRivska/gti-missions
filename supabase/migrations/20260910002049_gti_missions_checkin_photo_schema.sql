alter table public.gti_missions_challenges add column if not exists requires_photo boolean not null default false;
alter table public.gti_missions_challenge_entries add column if not exists photo_path text;
alter table public.gti_missions_challenge_entries add column if not exists photo_expires_at timestamptz;
create index if not exists gti_missions_challenge_entries_photo_exp_idx on public.gti_missions_challenge_entries(photo_expires_at) where photo_path is not null;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('gti-missions-checkins','gti-missions-checkins',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;
