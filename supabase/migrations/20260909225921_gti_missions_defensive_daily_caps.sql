create or replace function public.gti_missions_log_water(p_amount_ml integer) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (now() at time zone 'America/Sao_Paulo')::date;
  v_week date := date_trunc('week', now() at time zone 'America/Sao_Paulo')::date;
  v_target integer;
  v_existing_total integer := 0;
  v_total integer;
  v_log_count integer;
  v_entry_id uuid;
  v_goal_new boolean := false;
  v_goal_id uuid;
  v_badge_id uuid;
  v_completed_days integer := 0;
  v_xp integer := 0;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, true) then raise exception 'Permanent account required'; end if;
  if p_amount_ml < 50 or p_amount_ml > 2000 then raise exception 'Amount must be between 50 and 2000 ml'; end if;

  select water_target_ml into v_target from public.gti_missions_profiles where user_id = v_uid;
  if v_target is null then raise exception 'Complete your profile first'; end if;
  select coalesce(total_ml,0) into v_existing_total from public.gti_missions_water_days where user_id=v_uid and day=v_day;
  if v_existing_total + p_amount_ml > 6000 then raise exception 'Daily logging limit reached'; end if;

  insert into public.gti_missions_water_days(user_id, day, target_ml, total_ml, log_count)
  values (v_uid, v_day, v_target, p_amount_ml, 1)
  on conflict (user_id, day) do update
    set total_ml = public.gti_missions_water_days.total_ml + excluded.total_ml,
        log_count = public.gti_missions_water_days.log_count + 1
    where public.gti_missions_water_days.log_count < 20
  returning total_ml, log_count, target_ml into v_total, v_log_count, v_target;
  if v_total is null then raise exception 'Daily logging limit reached'; end if;

  insert into public.gti_missions_water_entries(user_id, amount_ml) values (v_uid, p_amount_ml) returning id into v_entry_id;
  if v_log_count <= 5 then
    insert into public.gti_missions_xp_events(user_id, source, xp, event_key)
    values (v_uid, 'water_log', 5, 'water_log:' || v_day::text || ':' || v_log_count::text) on conflict do nothing;
    v_xp := v_xp + 5;
  end if;
  if v_total >= v_target then
    update public.gti_missions_water_days set goal_completed_at=coalesce(goal_completed_at,now())
    where user_id=v_uid and day=v_day and goal_completed_at is null returning true into v_goal_new;
    if coalesce(v_goal_new,false) then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
      values(v_uid,'water_goal',50,'water_goal:'||v_day::text)
      on conflict(user_id,event_key) do nothing returning id into v_goal_id;
      if v_goal_id is not null then v_xp:=v_xp+50; end if;
    end if;
  end if;
  select count(*) into v_completed_days from public.gti_missions_water_days
  where user_id=v_uid and day between v_week and v_week+6 and goal_completed_at is not null;
  if v_completed_days>=5 then
    insert into public.gti_missions_weekly_badges(user_id,mission,week_start,label)
    values(v_uid,'aqua',v_week,'AquaXP • Semana '||to_char(v_week,'IW'))
    on conflict(user_id,mission,week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
      values(v_uid,'weekly_badge',100,'badge:aqua:'||v_week::text) on conflict do nothing;
      v_xp:=v_xp+100;
    end if;
  end if;
  return jsonb_build_object('entry_id',v_entry_id,'today_ml',v_total,'target_ml',v_target,'xp_awarded',v_xp,'goal_met',v_total>=v_target,'week_completed_days',v_completed_days);
end; $$;

create or replace function public.gti_missions_log_exercise(p_exercise_name text,p_duration_minutes integer) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_uid uuid:=auth.uid();
  v_day date:=(now() at time zone 'America/Sao_Paulo')::date;
  v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_weekly_target integer; v_daily_count integer; v_daily_minutes integer:=0; v_days integer; v_day_xp integer;
  v_entry_id uuid; v_xp_id uuid; v_badge_id uuid; v_xp integer:=0;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then raise exception 'Permanent account required'; end if;
  if char_length(trim(p_exercise_name))<1 or char_length(trim(p_exercise_name))>80 then raise exception 'Invalid exercise'; end if;
  if p_duration_minutes<1 or p_duration_minutes>300 then raise exception 'Duration must be between 1 and 300 minutes'; end if;
  select count(*),coalesce(sum(duration_minutes),0) into v_daily_count,v_daily_minutes from public.gti_missions_exercise_entries
  where user_id=v_uid and (logged_at at time zone 'America/Sao_Paulo')::date=v_day;
  if v_daily_count>=10 or v_daily_minutes+p_duration_minutes>300 then raise exception 'Daily exercise logging limit reached'; end if;
  select exercise_weekly_target into v_weekly_target from public.gti_missions_profiles where user_id=v_uid;
  if v_weekly_target is null then raise exception 'Complete your profile first'; end if;
  insert into public.gti_missions_exercise_weeks(user_id,week_start,target_days) values(v_uid,v_week,v_weekly_target) on conflict(user_id,week_start) do nothing;
  select target_days into v_weekly_target from public.gti_missions_exercise_weeks where user_id=v_uid and week_start=v_week;
  insert into public.gti_missions_exercise_entries(user_id,exercise_name,duration_minutes) values(v_uid,trim(p_exercise_name),p_duration_minutes) returning id into v_entry_id;
  if p_duration_minutes>=5 then
    v_day_xp:=case when p_duration_minutes>=20 then 30 else 15 end;
    insert into public.gti_missions_xp_events(user_id,source,xp,event_key) values(v_uid,'exercise_day',v_day_xp,'exercise_day:'||v_day::text)
    on conflict(user_id,event_key) do nothing returning id into v_xp_id;
    if v_xp_id is not null then v_xp:=v_xp+v_day_xp; end if;
  end if;
  select count(distinct(logged_at at time zone 'America/Sao_Paulo')::date) into v_days from public.gti_missions_exercise_entries
  where user_id=v_uid and duration_minutes>=5 and (logged_at at time zone 'America/Sao_Paulo')::date between v_week and v_week+6;
  if v_days>=v_weekly_target then
    insert into public.gti_missions_weekly_badges(user_id,mission,week_start,label) values(v_uid,'tech_rat',v_week,'Tech Rat • Semana '||to_char(v_week,'IW'))
    on conflict(user_id,mission,week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key) values(v_uid,'weekly_badge',100,'badge:tech_rat:'||v_week::text) on conflict do nothing;
      v_xp:=v_xp+100;
    end if;
  end if;
  return jsonb_build_object('entry_id',v_entry_id,'xp_awarded',v_xp,'weekly_days',v_days,'weekly_target',v_weekly_target);
end; $$;
revoke all on function public.gti_missions_log_water(integer) from public,anon;
revoke all on function public.gti_missions_log_exercise(text,integer) from public,anon;
grant execute on function public.gti_missions_log_water(integer) to authenticated;
grant execute on function public.gti_missions_log_exercise(text,integer) to authenticated;
