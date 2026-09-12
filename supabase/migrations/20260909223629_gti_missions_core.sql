create table if not exists public.gti_missions_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  username text not null check (username ~ '^[A-Za-z0-9._-]{3,30}$'),
  water_target_ml integer not null default 2000 check (water_target_ml between 500 and 6000),
  exercise_weekly_target integer not null default 3 check (exercise_weekly_target between 1 and 7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists gti_missions_profiles_username_lower_idx on public.gti_missions_profiles (lower(username));
create table if not exists public.gti_missions_water_entries (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  amount_ml integer not null check (amount_ml between 50 and 2000), logged_at timestamptz not null default now()
);
create index if not exists gti_missions_water_user_time_idx on public.gti_missions_water_entries (user_id, logged_at desc);
create table if not exists public.gti_missions_exercise_entries (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  exercise_name text not null check (char_length(exercise_name) between 1 and 80), duration_minutes integer not null check (duration_minutes between 1 and 300), logged_at timestamptz not null default now()
);
create index if not exists gti_missions_exercise_user_time_idx on public.gti_missions_exercise_entries (user_id, logged_at desc);
create table if not exists public.gti_missions_xp_events (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  source text not null check (source in ('water_log','water_goal','exercise_day','weekly_badge')), xp integer not null check (xp between 1 and 250),
  event_key text not null, created_at timestamptz not null default now(), unique (user_id, event_key)
);
create index if not exists gti_missions_xp_user_time_idx on public.gti_missions_xp_events (user_id, created_at desc);
create table if not exists public.gti_missions_weekly_badges (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  mission text not null check (mission in ('aqua','tech_rat')), week_start date not null, label text not null, awarded_at timestamptz not null default now(), unique (user_id, mission, week_start)
);
create index if not exists gti_missions_badges_user_week_idx on public.gti_missions_weekly_badges (user_id, week_start desc);
alter table public.gti_missions_profiles enable row level security;
alter table public.gti_missions_water_entries enable row level security;
alter table public.gti_missions_exercise_entries enable row level security;
alter table public.gti_missions_xp_events enable row level security;
alter table public.gti_missions_weekly_badges enable row level security;
drop policy if exists gti_missions_profiles_select_own on public.gti_missions_profiles;
create policy gti_missions_profiles_select_own on public.gti_missions_profiles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists gti_missions_profiles_insert_own on public.gti_missions_profiles;
create policy gti_missions_profiles_insert_own on public.gti_missions_profiles for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists gti_missions_profiles_update_own on public.gti_missions_profiles;
create policy gti_missions_profiles_update_own on public.gti_missions_profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists gti_missions_water_select_own on public.gti_missions_water_entries;
create policy gti_missions_water_select_own on public.gti_missions_water_entries for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists gti_missions_exercise_select_own on public.gti_missions_exercise_entries;
create policy gti_missions_exercise_select_own on public.gti_missions_exercise_entries for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists gti_missions_xp_select_own on public.gti_missions_xp_events;
create policy gti_missions_xp_select_own on public.gti_missions_xp_events for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists gti_missions_badges_select_own on public.gti_missions_weekly_badges;
create policy gti_missions_badges_select_own on public.gti_missions_weekly_badges for select to authenticated using ((select auth.uid()) = user_id);
create or replace function public.gti_missions_set_updated_at() returns trigger language plpgsql security invoker set search_path = public, pg_temp as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists gti_missions_profiles_updated_at on public.gti_missions_profiles;
create trigger gti_missions_profiles_updated_at before update on public.gti_missions_profiles for each row execute function public.gti_missions_set_updated_at();
create or replace function public.gti_missions_log_water(p_amount_ml integer) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_entry_id uuid; v_day date := (now() at time zone 'America/Sao_Paulo')::date; v_week date := date_trunc('week', now() at time zone 'America/Sao_Paulo')::date; v_target integer; v_total integer; v_log_count integer; v_goal_inserted uuid; v_badge_id uuid; v_completed_days integer; v_xp integer := 0;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_amount_ml < 50 or p_amount_ml > 2000 then raise exception 'Amount must be between 50 and 2000 ml'; end if;
  select water_target_ml into v_target from public.gti_missions_profiles where user_id = v_uid;
  if v_target is null then raise exception 'Complete your profile first'; end if;
  insert into public.gti_missions_water_entries(user_id, amount_ml) values (v_uid, p_amount_ml) returning id into v_entry_id;
  select count(*), coalesce(sum(amount_ml),0) into v_log_count, v_total from public.gti_missions_water_entries where user_id = v_uid and (logged_at at time zone 'America/Sao_Paulo')::date = v_day;
  if v_log_count <= 5 then insert into public.gti_missions_xp_events(user_id, source, xp, event_key) values (v_uid, 'water_log', 5, 'water_log:' || v_entry_id::text) on conflict do nothing; v_xp := v_xp + 5; end if;
  if v_total >= v_target then
    insert into public.gti_missions_xp_events(user_id, source, xp, event_key) values (v_uid, 'water_goal', 50, 'water_goal:' || v_day::text) on conflict (user_id, event_key) do nothing returning id into v_goal_inserted;
    if v_goal_inserted is not null then v_xp := v_xp + 50; end if;
  end if;
  select count(*) into v_completed_days from (select (logged_at at time zone 'America/Sao_Paulo')::date as d from public.gti_missions_water_entries where user_id = v_uid and (logged_at at time zone 'America/Sao_Paulo')::date between v_week and v_week + 6 group by 1 having sum(amount_ml) >= v_target) s;
  if v_completed_days >= 5 then
    insert into public.gti_missions_weekly_badges(user_id, mission, week_start, label) values (v_uid, 'aqua', v_week, 'Aqua Week ' || to_char(v_week, 'IW')) on conflict (user_id, mission, week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then insert into public.gti_missions_xp_events(user_id, source, xp, event_key) values (v_uid, 'weekly_badge', 100, 'badge:aqua:' || v_week::text) on conflict do nothing; v_xp := v_xp + 100; end if;
  end if;
  return jsonb_build_object('entry_id',v_entry_id,'today_ml',v_total,'xp_awarded',v_xp,'goal_met',v_total >= v_target);
end; $$;
create or replace function public.gti_missions_log_exercise(p_exercise_name text, p_duration_minutes integer) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_entry_id uuid; v_day date := (now() at time zone 'America/Sao_Paulo')::date; v_week date := date_trunc('week', now() at time zone 'America/Sao_Paulo')::date; v_weekly_target integer; v_days integer; v_day_xp integer; v_xp_id uuid; v_badge_id uuid; v_xp integer := 0;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if char_length(trim(p_exercise_name)) < 1 or char_length(trim(p_exercise_name)) > 80 then raise exception 'Invalid exercise'; end if;
  if p_duration_minutes < 1 or p_duration_minutes > 300 then raise exception 'Duration must be between 1 and 300 minutes'; end if;
  select exercise_weekly_target into v_weekly_target from public.gti_missions_profiles where user_id = v_uid;
  if v_weekly_target is null then raise exception 'Complete your profile first'; end if;
  insert into public.gti_missions_exercise_entries(user_id, exercise_name, duration_minutes) values (v_uid, trim(p_exercise_name), p_duration_minutes) returning id into v_entry_id;
  if p_duration_minutes >= 5 then
    v_day_xp := case when p_duration_minutes >= 20 then 30 else 15 end;
    insert into public.gti_missions_xp_events(user_id, source, xp, event_key) values (v_uid, 'exercise_day', v_day_xp, 'exercise_day:' || v_day::text) on conflict (user_id, event_key) do nothing returning id into v_xp_id;
    if v_xp_id is not null then v_xp := v_xp + v_day_xp; end if;
  end if;
  select count(distinct (logged_at at time zone 'America/Sao_Paulo')::date) into v_days from public.gti_missions_exercise_entries where user_id = v_uid and duration_minutes >= 5 and (logged_at at time zone 'America/Sao_Paulo')::date between v_week and v_week + 6;
  if v_days >= v_weekly_target then
    insert into public.gti_missions_weekly_badges(user_id, mission, week_start, label) values (v_uid, 'tech_rat', v_week, 'Tech Rat Week ' || to_char(v_week, 'IW')) on conflict (user_id, mission, week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then insert into public.gti_missions_xp_events(user_id, source, xp, event_key) values (v_uid, 'weekly_badge', 100, 'badge:tech_rat:' || v_week::text) on conflict do nothing; v_xp := v_xp + 100; end if;
  end if;
  return jsonb_build_object('entry_id',v_entry_id,'xp_awarded',v_xp,'weekly_days',v_days,'weekly_target',v_weekly_target);
end; $$;
create or replace function public.gti_missions_leaderboard() returns table(user_id uuid, display_name text, username text, xp bigint, rank bigint) language sql security definer set search_path = public, pg_temp as $$
  with totals as (
    select p.user_id, p.display_name, p.username, coalesce(sum(x.xp),0)::bigint as xp
    from public.gti_missions_profiles p
    left join public.gti_missions_xp_events x on x.user_id = p.user_id and (x.created_at at time zone 'America/Sao_Paulo') >= date_trunc('month', now() at time zone 'America/Sao_Paulo')
    group by p.user_id, p.display_name, p.username
  )
  select t.user_id, t.display_name, t.username, t.xp, row_number() over(order by t.xp desc, lower(t.username) asc)::bigint as rank from totals t order by rank limit 100;
$$;
revoke all on function public.gti_missions_set_updated_at() from public, anon;
revoke all on function public.gti_missions_log_water(integer) from public, anon;
revoke all on function public.gti_missions_log_exercise(text, integer) from public, anon;
revoke all on function public.gti_missions_leaderboard() from public, anon;
grant execute on function public.gti_missions_log_water(integer) to authenticated;
grant execute on function public.gti_missions_log_exercise(text, integer) to authenticated;
grant execute on function public.gti_missions_leaderboard() to authenticated;
grant select, insert, update on public.gti_missions_profiles to authenticated;
grant select on public.gti_missions_water_entries to authenticated;
grant select on public.gti_missions_exercise_entries to authenticated;
grant select on public.gti_missions_xp_events to authenticated;
grant select on public.gti_missions_weekly_badges to authenticated;
