create or replace function public.gti_missions_my_stats() returns jsonb
language plpgsql security invoker set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_week date := date_trunc('week', now() at time zone 'America/Sao_Paulo')::date;
  v_target integer := 2000;
  v_today_ml integer := 0;
  v_streak integer := 0;
  v_water_week_days integer := 0;
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

  select count(*) into v_water_week_days from public.gti_missions_water_days
  where user_id=v_uid and day between v_week and v_week+6 and goal_completed_at is not null;

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
    'water_week_days', coalesce(v_water_week_days,0),
    'exercise_week_days', coalesce(v_exercise_days,0),
    'exercise_week_target', coalesce(v_exercise_target,3),
    'total_xp', coalesce(v_total_xp,0),
    'monthly_xp', coalesce(v_monthly_xp,0),
    'badges', coalesce(v_badges,0)
  );
end; $$;
revoke all on function public.gti_missions_my_stats() from public, anon;
grant execute on function public.gti_missions_my_stats() to authenticated;
