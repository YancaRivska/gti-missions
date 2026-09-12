create table if not exists public.gti_missions_challenges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]{3,60}$'),
  title text not null check (char_length(title) between 3 and 80),
  description text not null default '' check (char_length(description) <= 500),
  icon text not null default '🎯' check (char_length(icon) between 1 and 16),
  mode text not null default 'checkin' check (mode in ('checkin','quantity')),
  unit_label text not null default 'check-in' check (char_length(unit_label) between 1 and 30),
  daily_target numeric(10,2),
  weekly_target_days integer not null default 7 check (weekly_target_days between 1 and 7),
  xp_per_day integer not null default 25 check (xp_per_day between 1 and 100),
  weekly_bonus_xp integer not null default 100 check (weekly_bonus_xp between 0 and 250),
  starts_on date not null default (now() at time zone 'America/Sao_Paulo')::date,
  ends_on date,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((mode='checkin' and daily_target is null) or (mode='quantity' and daily_target is not null and daily_target>0)),
  check (ends_on is null or ends_on>=starts_on)
);
create index if not exists gti_missions_challenges_active_idx on public.gti_missions_challenges(is_active,starts_on,ends_on);
alter table public.gti_missions_challenges enable row level security;
drop policy if exists gti_missions_challenges_select_players on public.gti_missions_challenges;
create policy gti_missions_challenges_select_players on public.gti_missions_challenges for select to authenticated
using (
  coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and (
    exists(select 1 from public.gti_missions_admins a where a.user_id=(select auth.uid()))
    or (is_active and exists(select 1 from public.gti_missions_profiles p where p.user_id=(select auth.uid()) and p.accepted_terms_at is not null and p.terms_version='1.1'))
  )
);
revoke all on public.gti_missions_challenges from anon;
grant select on public.gti_missions_challenges to authenticated;

create table if not exists public.gti_missions_challenge_participants (
  challenge_id uuid not null references public.gti_missions_challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(challenge_id,user_id)
);
alter table public.gti_missions_challenge_participants enable row level security;
drop policy if exists gti_missions_challenge_participants_select_own on public.gti_missions_challenge_participants;
create policy gti_missions_challenge_participants_select_own on public.gti_missions_challenge_participants for select to authenticated
using (user_id=(select auth.uid()) and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false);
revoke all on public.gti_missions_challenge_participants from anon;
grant select on public.gti_missions_challenge_participants to authenticated;

create table if not exists public.gti_missions_challenge_entries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.gti_missions_challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_day date not null,
  value numeric(10,2) not null default 1 check (value>0),
  note text check (note is null or char_length(note)<=180),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(challenge_id,user_id,entry_day)
);
create index if not exists gti_missions_challenge_entries_user_idx on public.gti_missions_challenge_entries(user_id,challenge_id,entry_day desc);
alter table public.gti_missions_challenge_entries enable row level security;
drop policy if exists gti_missions_challenge_entries_select_own on public.gti_missions_challenge_entries;
create policy gti_missions_challenge_entries_select_own on public.gti_missions_challenge_entries for select to authenticated
using (user_id=(select auth.uid()) and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false);
revoke all on public.gti_missions_challenge_entries from anon;
grant select on public.gti_missions_challenge_entries to authenticated;

create table if not exists public.gti_missions_challenge_badges (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.gti_missions_challenges(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  label text not null check (char_length(label) between 1 and 120),
  awarded_at timestamptz not null default now(),
  unique(challenge_id,user_id,week_start)
);
alter table public.gti_missions_challenge_badges enable row level security;
drop policy if exists gti_missions_challenge_badges_select_own on public.gti_missions_challenge_badges;
create policy gti_missions_challenge_badges_select_own on public.gti_missions_challenge_badges for select to authenticated
using (user_id=(select auth.uid()) and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false);
revoke all on public.gti_missions_challenge_badges from anon;
grant select on public.gti_missions_challenge_badges to authenticated;

alter table public.gti_missions_xp_events drop constraint if exists gti_missions_xp_events_source_check;
alter table public.gti_missions_xp_events add constraint gti_missions_xp_events_source_check
check (source in ('water_log','water_goal','exercise_day','weekly_badge','custom_day','custom_week'));
