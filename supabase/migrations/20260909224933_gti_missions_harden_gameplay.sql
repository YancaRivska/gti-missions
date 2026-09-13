alter table public.gti_missions_profiles add column if not exists water_container_ml integer not null default 500;
alter table public.gti_missions_profiles add column if not exists water_container_label text not null default 'Garrafa';
alter table public.gti_missions_profiles add column if not exists accepted_terms_at timestamptz;
alter table public.gti_missions_profiles add column if not exists terms_version text;
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_water_target_ml_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_water_target_ml_check check (water_target_ml between 1000 and 4000);
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_water_container_ml_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_water_container_ml_check check (water_container_ml between 50 and 2000);
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_water_container_label_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_water_container_label_check check (char_length(water_container_label) between 1 and 20);
alter table public.gti_missions_profiles drop constraint if exists gti_missions_profiles_terms_version_check;
alter table public.gti_missions_profiles add constraint gti_missions_profiles_terms_version_check check (terms_version is null or terms_version = '1.0');

create table if not exists public.gti_missions_water_days (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  target_ml integer not null check (target_ml between 1000 and 4000),
  total_ml integer not null default 0 check (total_ml >= 0),
  log_count integer not null default 0 check (log_count between 0 and 20),
  goal_completed_at timestamptz,
  primary key (user_id, day)
);

create table if not exists public.gti_missions_exercise_weeks (
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  target_days integer not null check (target_days between 1 and 7),
  primary key (user_id, week_start)
);

alter table public.gti_missions_water_days enable row level security;
alter table public.gti_missions_exercise_weeks enable row level security;

drop policy if exists gti_missions_water_days_select_own on public.gti_missions_water_days;
create policy gti_missions_water_days_select_own on public.gti_missions_water_days for select to authenticated
using ((select auth.uid()) = user_id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), true) is false);

drop policy if exists gti_missions_exercise_weeks_select_own on public.gti_missions_exercise_weeks;
create policy gti_missions_exercise_weeks_select_own on public.gti_missions_exercise_weeks for select to authenticated
using ((select auth.uid()) = user_id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), true) is false);

grant select on public.gti_missions_water_days to authenticated;
grant select on public.gti_missions_exercise_weeks to authenticated;
revoke insert, update, delete on public.gti_missions_water_days from authenticated, anon;
revoke insert, update, delete on public.gti_missions_exercise_weeks from authenticated, anon;

create or replace function public.gti_missions_log_water(p_amount_ml integer) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (now() at time zone 'America/Sao_Paulo')::date;
  v_week date := date_trunc('week', now() at time zone 'America/Sao_Paulo')::date;
  v_target integer;
  v_total integer;
  v_log_count integer;
  v_entry_id uuid;
  v_goal_new boolean := false;
  v_goal_id uuid;
  v_badge_id uuid;
  v_completed_days integer := 0;
  v_xp integer := 0;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, true) then
    raise exception 'Permanent account required';
  end if;
  if p_amount_ml < 50 or p_amount_ml > 2000 then
    raise exception 'Amount must be between 50 and 2000 ml';
  end if;

  select water_target_ml into v_target from public.gti_missions_profiles where user_id = v_uid;
  if v_target is null then raise exception 'Complete your profile first'; end if;

  insert into public.gti_missions_water_days(user_id, day, target_ml, total_ml, log_count)
  values (v_uid, v_day, v_target, p_amount_ml, 1)
  on conflict (user_id, day) do update
    set total_ml = public.gti_missions_water_days.total_ml + excluded.total_ml,
        log_count = public.gti_missions_water_days.log_count + 1
    where public.gti_missions_water_days.log_count < 20
  returning total_ml, log_count, target_ml into v_total, v_log_count, v_target;

  if v_total is null then raise exception 'Daily logging limit reached'; end if;

  insert into public.gti_missions_water_entries(user_id, amount_ml)
  values (v_uid, p_amount_ml) returning id into v_entry_id;

  if v_log_count <= 5 then
    insert into public.gti_missions_xp_events(user_id, source, xp, event_key)
    values (v_uid, 'water_log', 5, 'water_log:' || v_day::text || ':' || v_log_count::text)
    on conflict do nothing;
    v_xp := v_xp + 5;
  end if;

  if v_total >= v_target then
    update public.gti_missions_water_days
      set goal_completed_at = coalesce(goal_completed_at, now())
      where user_id = v_uid and day = v_day and goal_completed_at is null
      returning true into v_goal_new;

    if coalesce(v_goal_new, false) then
      insert into public.gti_missions_xp_events(user_id, source, xp, event_key)
      values (v_uid, 'water_goal', 50, 'water_goal:' || v_day::text)
      on conflict (user_id, event_key) do nothing returning id into v_goal_id;
      if v_goal_id is not null then v_xp := v_xp + 50; end if;
    end if;
  end if;

  select count(*) into v_completed_days
  from public.gti_missions_water_days
  where user_id = v_uid and day between v_week and v_week + 6 and goal_completed_at is not null;

  if v_completed_days >= 5 then
    insert into public.gti_missions_weekly_badges(user_id, mission, week_start, label)
    values (v_uid, 'aqua', v_week, 'AquaXP • Semana ' || to_char(v_week, 'IW'))
    on conflict (user_id, mission, week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then
      insert into public.gti_missions_xp_events(user_id, source, xp, event_key)
      values (v_uid, 'weekly_badge', 100, 'badge:aqua:' || v_week::text)
      on conflict do nothing;
      v_xp := v_xp + 100;
    end if;
  end if;

  return jsonb_build_object('entry_id', v_entry_id, 'today_ml', v_total, 'target_ml', v_target, 'xp_awarded', v_xp, 'goal_met', v_total >= v_target, 'week_completed_days', v_completed_days);
end; $$;

create or replace function public.gti_missions_log_exercise(p_exercise_name text, p_duration_minutes integer) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (now() at time zone 'America/Sao_Paulo')::date;
  v_week date := date_trunc('week', now() at time zone 'America/Sao_Paulo')::date;
  v_weekly_target integer;
  v_daily_count integer;
  v_days integer;
  v_day_xp integer;
  v_entry_id uuid;
  v_xp_id uuid;
  v_badge_id uuid;
  v_xp integer := 0;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, true) then
    raise exception 'Permanent account required';
  end if;
  if char_length(trim(p_exercise_name)) < 1 or char_length(trim(p_exercise_name)) > 80 then raise exception 'Invalid exercise'; end if;
  if p_duration_minutes < 1 or p_duration_minutes > 300 then raise exception 'Duration must be between 1 and 300 minutes'; end if;

  select count(*) into v_daily_count from public.gti_missions_exercise_entries
  where user_id = v_uid and (logged_at at time zone 'America/Sao_Paulo')::date = v_day;
  if v_daily_count >= 10 then raise exception 'Daily exercise logging limit reached'; end if;

  select exercise_weekly_target into v_weekly_target from public.gti_missions_profiles where user_id = v_uid;
  if v_weekly_target is null then raise exception 'Complete your profile first'; end if;

  insert into public.gti_missions_exercise_weeks(user_id, week_start, target_days)
  values (v_uid, v_week, v_weekly_target)
  on conflict (user_id, week_start) do nothing;
  select target_days into v_weekly_target from public.gti_missions_exercise_weeks where user_id = v_uid and week_start = v_week;

  insert into public.gti_missions_exercise_entries(user_id, exercise_name, duration_minutes)
  values (v_uid, trim(p_exercise_name), p_duration_minutes) returning id into v_entry_id;

  if p_duration_minutes >= 5 then
    v_day_xp := case when p_duration_minutes >= 20 then 30 else 15 end;
    insert into public.gti_missions_xp_events(user_id, source, xp, event_key)
    values (v_uid, 'exercise_day', v_day_xp, 'exercise_day:' || v_day::text)
    on conflict (user_id, event_key) do nothing returning id into v_xp_id;
    if v_xp_id is not null then v_xp := v_xp + v_day_xp; end if;
  end if;

  select count(distinct (logged_at at time zone 'America/Sao_Paulo')::date) into v_days
  from public.gti_missions_exercise_entries
  where user_id = v_uid and duration_minutes >= 5
    and (logged_at at time zone 'America/Sao_Paulo')::date between v_week and v_week + 6;

  if v_days >= v_weekly_target then
    insert into public.gti_missions_weekly_badges(user_id, mission, week_start, label)
    values (v_uid, 'tech_rat', v_week, 'Tech Rat • Semana ' || to_char(v_week, 'IW'))
    on conflict (user_id, mission, week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then
      insert into public.gti_missions_xp_events(user_id, source, xp, event_key)
      values (v_uid, 'weekly_badge', 100, 'badge:tech_rat:' || v_week::text)
      on conflict do nothing;
      v_xp := v_xp + 100;
    end if;
  end if;

  return jsonb_build_object('entry_id', v_entry_id, 'xp_awarded', v_xp, 'weekly_days', v_days, 'weekly_target', v_weekly_target);
end; $$;

create or replace function public.gti_missions_my_stats() returns jsonb
language plpgsql security invoker set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_week date := date_trunc('week', now() at time zone 'America/Sao_Paulo')::date;
  v_target integer := 2000;
  v_today_ml integer := 0;
  v_streak integer := 0;
  v_exercise_days integer := 0;
  v_exercise_target integer := 3;
  v_total_xp bigint := 0;
  v_monthly_xp bigint := 0;
  v_badges integer := 0;
  v_anchor date;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, true) then raise exception 'Permanent account required'; end if;

  select water_target_ml, exercise_weekly_target into v_target, v_exercise_target
  from public.gti_missions_profiles where user_id = v_uid;

  select coalesce(total_ml,0), target_ml into v_today_ml, v_target
  from public.gti_missions_water_days where user_id = v_uid and day = v_today;
  if not found then
    select water_target_ml into v_target from public.gti_missions_profiles where user_id = v_uid;
    v_today_ml := 0;
  end if;

  v_anchor := case when exists(select 1 from public.gti_missions_water_days where user_id=v_uid and day=v_today and goal_completed_at is not null) then v_today else v_today - 1 end;

  with completed as (
    select day, row_number() over(order by day desc) as rn
    from public.gti_missions_water_days
    where user_id = v_uid and goal_completed_at is not null and day <= v_anchor
  )
  select count(*) into v_streak from completed where day = v_anchor - ((rn - 1)::integer);

  select target_days into v_exercise_target from public.gti_missions_exercise_weeks where user_id=v_uid and week_start=v_week;
  if not found then select exercise_weekly_target into v_exercise_target from public.gti_missions_profiles where user_id=v_uid; end if;

  select count(distinct (logged_at at time zone 'America/Sao_Paulo')::date) into v_exercise_days
  from public.gti_missions_exercise_entries
  where user_id=v_uid and duration_minutes >= 5 and (logged_at at time zone 'America/Sao_Paulo')::date between v_week and v_week+6;

  select coalesce(sum(xp),0) into v_total_xp from public.gti_missions_xp_events where user_id=v_uid;
  select coalesce(sum(xp),0) into v_monthly_xp from public.gti_missions_xp_events
  where user_id=v_uid and (created_at at time zone 'America/Sao_Paulo') >= date_trunc('month', now() at time zone 'America/Sao_Paulo');
  select count(*) into v_badges from public.gti_missions_weekly_badges where user_id=v_uid;

  return jsonb_build_object(
    'water_today_ml', coalesce(v_today_ml,0),
    'water_target_ml', coalesce(v_target,2000),
    'water_streak', coalesce(v_streak,0),
    'exercise_week_days', coalesce(v_exercise_days,0),
    'exercise_week_target', coalesce(v_exercise_target,3),
    'total_xp', coalesce(v_total_xp,0),
    'monthly_xp', coalesce(v_monthly_xp,0),
    'badges', coalesce(v_badges,0)
  );
end; $$;

create or replace function public.gti_missions_leaderboard() returns table(user_id uuid, display_name text, username text, xp bigint, rank bigint)
language sql security definer set search_path = public, pg_temp as $$
  with monthly as (
    select x.user_id, sum(x.xp)::bigint as xp
    from public.gti_missions_xp_events x
    where (x.created_at at time zone 'America/Sao_Paulo') >= date_trunc('month', now() at time zone 'America/Sao_Paulo')
    group by x.user_id
  ), ranked as (
    select p.user_id, p.display_name, p.username, m.xp,
      row_number() over(order by m.xp desc, lower(p.username) asc)::bigint as rank
    from monthly m join public.gti_missions_profiles p on p.user_id=m.user_id
    where m.xp > 0
  )
  select r.user_id, r.display_name, r.username, r.xp, r.rank
  from ranked r
  where auth.uid() is not null and coalesce((auth.jwt()->>'is_anonymous')::boolean, true) is false
  order by r.rank limit 100;
$$;

create or replace function public.gti_missions_delete_my_data() returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, true) then raise exception 'Permanent account required'; end if;
  delete from public.gti_missions_weekly_badges where user_id=v_uid;
  delete from public.gti_missions_xp_events where user_id=v_uid;
  delete from public.gti_missions_water_entries where user_id=v_uid;
  delete from public.gti_missions_exercise_entries where user_id=v_uid;
  delete from public.gti_missions_water_days where user_id=v_uid;
  delete from public.gti_missions_exercise_weeks where user_id=v_uid;
  delete from public.gti_missions_profiles where user_id=v_uid;
  return true;
end; $$;

revoke all on function public.gti_missions_log_water(integer) from public, anon;
revoke all on function public.gti_missions_log_exercise(text, integer) from public, anon;
revoke all on function public.gti_missions_leaderboard() from public, anon;
revoke all on function public.gti_missions_my_stats() from public, anon;
revoke all on function public.gti_missions_delete_my_data() from public, anon;
grant execute on function public.gti_missions_log_water(integer) to authenticated;
grant execute on function public.gti_missions_log_exercise(text, integer) to authenticated;
grant execute on function public.gti_missions_leaderboard() to authenticated;
grant execute on function public.gti_missions_my_stats() to authenticated;
grant execute on function public.gti_missions_delete_my_data() to authenticated;
