begin;

alter table public.gti_missions_water_entries
  add column if not exists photo_path text,
  add column if not exists photo_expires_at timestamptz;

alter table public.gti_missions_exercise_entries
  add column if not exists photo_path text,
  add column if not exists photo_expires_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'gti_missions_water_photo_pair'
  ) then
    alter table public.gti_missions_water_entries
      add constraint gti_missions_water_photo_pair
      check ((photo_path is null) = (photo_expires_at is null));
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'gti_missions_exercise_photo_pair'
  ) then
    alter table public.gti_missions_exercise_entries
      add constraint gti_missions_exercise_photo_pair
      check ((photo_path is null) = (photo_expires_at is null));
  end if;
end $$;

create unique index if not exists gti_missions_water_photo_unique
  on public.gti_missions_water_entries(photo_path)
  where photo_path is not null;

create unique index if not exists gti_missions_exercise_photo_unique
  on public.gti_missions_exercise_entries(photo_path)
  where photo_path is not null;

create index if not exists gti_missions_water_photo_expiry_idx
  on public.gti_missions_water_entries(photo_expires_at)
  where photo_path is not null;

create index if not exists gti_missions_exercise_photo_expiry_idx
  on public.gti_missions_exercise_entries(photo_expires_at)
  where photo_path is not null;

create or replace function public.gti_missions_log_water(p_amount_ml integer)
returns jsonb
language plpgsql
security invoker
set search_path = 'public', 'pg_temp'
as $$
begin
  raise exception 'Camera proof required';
end;
$$;

create or replace function public.gti_missions_log_water(
  p_amount_ml integer,
  p_photo_path text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'storage', 'pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  v_day date:=(now() at time zone 'America/Sao_Paulo')::date;
  v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_target integer;
  v_total integer;
  v_log_count integer;
  v_entry_id uuid;
  v_goal_new boolean:=false;
  v_goal_id uuid;
  v_badge_id uuid;
  v_completed_days integer:=0;
  v_xp integer:=0;
  v_valid_photo boolean:=false;
  v_photo_expires_at timestamptz:=now()+interval '24 hours';
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    raise exception 'Permanent account required';
  end if;
  if p_amount_ml<50 or p_amount_ml>2000 then
    raise exception 'Amount must be between 50 and 2000 ml';
  end if;
  if p_photo_path is null or p_photo_path='' then
    raise exception 'Camera proof required';
  end if;

  select water_target_ml into v_target
  from public.gti_missions_profiles
  where user_id=v_uid and accepted_terms_at is not null and terms_version='1.2';
  if v_target is null then raise exception 'Current terms must be accepted'; end if;

  select exists(
    select 1
    from storage.objects o
    where o.bucket_id='gti-missions-checkins'
      and o.name=p_photo_path
      and (storage.foldername(o.name))[1]=v_uid::text
      and (storage.foldername(o.name))[2]='aqua'
      and o.created_at>=now()-interval '15 minutes'
      and not exists(
        select 1 from public.gti_missions_water_entries e where e.photo_path=p_photo_path
      )
  ) into v_valid_photo;
  if not v_valid_photo then raise exception 'Invalid or expired camera proof'; end if;

  insert into public.gti_missions_water_days(user_id,day,target_ml,total_ml,log_count)
  values(v_uid,v_day,v_target,p_amount_ml,1)
  on conflict(user_id,day) do update set
    total_ml=public.gti_missions_water_days.total_ml+excluded.total_ml,
    log_count=public.gti_missions_water_days.log_count+1
  where public.gti_missions_water_days.log_count<20
    and public.gti_missions_water_days.total_ml+excluded.total_ml<=6000
  returning total_ml,log_count,target_ml into v_total,v_log_count,v_target;
  if v_total is null then raise exception 'Daily logging limit reached'; end if;

  insert into public.gti_missions_water_entries(
    user_id,amount_ml,photo_path,photo_expires_at
  ) values(
    v_uid,p_amount_ml,p_photo_path,v_photo_expires_at
  ) returning id into v_entry_id;

  if v_log_count<=5 then
    insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
    values(v_uid,'water_log',5,'water_log:'||v_day::text||':'||v_log_count::text)
    on conflict do nothing;
    v_xp:=v_xp+5;
  end if;

  if v_total>=v_target then
    update public.gti_missions_water_days
      set goal_completed_at=coalesce(goal_completed_at,now())
      where user_id=v_uid and day=v_day and goal_completed_at is null
      returning true into v_goal_new;
    if coalesce(v_goal_new,false) then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
      values(v_uid,'water_goal',50,'water_goal:'||v_day::text)
      on conflict(user_id,event_key) do nothing returning id into v_goal_id;
      if v_goal_id is not null then v_xp:=v_xp+50; end if;
    end if;
  end if;

  select count(*) into v_completed_days
  from public.gti_missions_water_days
  where user_id=v_uid and day between v_week and v_week+6 and goal_completed_at is not null;

  if v_completed_days>=7 then
    insert into public.gti_missions_weekly_badges(user_id,mission,week_start,label)
    values(v_uid,'aqua',v_week,'AquaXP 7/7 • Semana '||to_char(v_week,'IW'))
    on conflict(user_id,mission,week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
      values(v_uid,'weekly_badge',100,'badge:aqua:'||v_week::text)
      on conflict do nothing;
      v_xp:=v_xp+100;
    end if;
  end if;

  return jsonb_build_object(
    'entry_id',v_entry_id,
    'today_ml',v_total,
    'target_ml',v_target,
    'xp_awarded',v_xp,
    'goal_met',v_total>=v_target,
    'week_completed_days',v_completed_days,
    'photo_expires_at',v_photo_expires_at
  );
end;
$$;

create or replace function public.gti_missions_log_exercise(
  p_exercise_name text,
  p_duration_minutes integer
)
returns jsonb
language plpgsql
security invoker
set search_path = 'public', 'pg_temp'
as $$
begin
  raise exception 'Camera proof required';
end;
$$;

create or replace function public.gti_missions_log_exercise(
  p_exercise_name text,
  p_duration_minutes integer,
  p_photo_path text
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'storage', 'pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  v_day date:=(now() at time zone 'America/Sao_Paulo')::date;
  v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_weekly_target integer;
  v_daily_minutes integer;
  v_daily_count integer;
  v_days integer;
  v_day_xp integer;
  v_entry_id uuid;
  v_xp_id uuid;
  v_badge_id uuid;
  v_xp integer:=0;
  v_valid_photo boolean:=false;
  v_photo_expires_at timestamptz:=now()+interval '24 hours';
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    raise exception 'Permanent account required';
  end if;
  if char_length(trim(p_exercise_name))<1 or char_length(trim(p_exercise_name))>80 then
    raise exception 'Invalid exercise';
  end if;
  if p_duration_minutes<1 or p_duration_minutes>300 then
    raise exception 'Duration must be between 1 and 300 minutes';
  end if;
  if p_photo_path is null or p_photo_path='' then
    raise exception 'Camera proof required';
  end if;

  select exercise_weekly_target into v_weekly_target
  from public.gti_missions_profiles
  where user_id=v_uid and accepted_terms_at is not null and terms_version='1.2';
  if v_weekly_target is null then raise exception 'Current terms must be accepted'; end if;
  v_weekly_target:=greatest(3,least(7,v_weekly_target));

  select exists(
    select 1
    from storage.objects o
    where o.bucket_id='gti-missions-checkins'
      and o.name=p_photo_path
      and (storage.foldername(o.name))[1]=v_uid::text
      and (storage.foldername(o.name))[2]='tech'
      and o.created_at>=now()-interval '15 minutes'
      and not exists(
        select 1 from public.gti_missions_exercise_entries e where e.photo_path=p_photo_path
      )
  ) into v_valid_photo;
  if not v_valid_photo then raise exception 'Invalid or expired camera proof'; end if;

  insert into public.gti_missions_exercise_days(user_id,day,total_minutes,log_count)
  values(v_uid,v_day,p_duration_minutes,1)
  on conflict(user_id,day) do update set
    total_minutes=public.gti_missions_exercise_days.total_minutes+excluded.total_minutes,
    log_count=public.gti_missions_exercise_days.log_count+1
  where public.gti_missions_exercise_days.log_count<10
    and public.gti_missions_exercise_days.total_minutes+excluded.total_minutes<=300
  returning total_minutes,log_count into v_daily_minutes,v_daily_count;
  if v_daily_minutes is null then raise exception 'Daily exercise logging limit reached'; end if;

  insert into public.gti_missions_exercise_weeks(user_id,week_start,target_days)
  values(v_uid,v_week,v_weekly_target)
  on conflict(user_id,week_start) do nothing;
  select target_days into v_weekly_target
  from public.gti_missions_exercise_weeks
  where user_id=v_uid and week_start=v_week;

  insert into public.gti_missions_exercise_entries(
    user_id,exercise_name,duration_minutes,photo_path,photo_expires_at
  ) values(
    v_uid,trim(p_exercise_name),p_duration_minutes,p_photo_path,v_photo_expires_at
  ) returning id into v_entry_id;

  if p_duration_minutes>=5 then
    v_day_xp:=case when p_duration_minutes>=20 then 30 else 15 end;
    insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
    values(v_uid,'exercise_day',v_day_xp,'exercise_day:'||v_day::text)
    on conflict(user_id,event_key) do nothing returning id into v_xp_id;
    if v_xp_id is not null then v_xp:=v_xp+v_day_xp; end if;
  end if;

  select count(distinct(logged_at at time zone 'America/Sao_Paulo')::date) into v_days
  from public.gti_missions_exercise_entries
  where user_id=v_uid and duration_minutes>=5
    and (logged_at at time zone 'America/Sao_Paulo')::date between v_week and v_week+6;

  if v_days>=v_weekly_target then
    insert into public.gti_missions_weekly_badges(user_id,mission,week_start,label)
    values(v_uid,'tech_rat',v_week,'Tech Rat • Semana '||to_char(v_week,'IW'))
    on conflict(user_id,mission,week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
      values(v_uid,'weekly_badge',100,'badge:tech_rat:'||v_week::text)
      on conflict do nothing;
      v_xp:=v_xp+100;
    end if;
  end if;

  return jsonb_build_object(
    'entry_id',v_entry_id,
    'xp_awarded',v_xp,
    'weekly_days',v_days,
    'weekly_target',v_weekly_target,
    'today_minutes',v_daily_minutes,
    'photo_expires_at',v_photo_expires_at
  );
end;
$$;

create or replace function public.gti_missions_admin_recent_proofs()
returns jsonb
language sql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
select case
  when not public.gti_missions_is_admin() then '[]'::jsonb
  else coalesce(jsonb_agg(to_jsonb(x) order by x.completed_at desc),'[]'::jsonb)
end
from (
  select * from (
    select e.id,e.challenge_id,c.title as challenge_title,c.icon,e.user_id,
      p.display_name,p.username,e.entry_day,e.completed_at,e.photo_path,e.photo_expires_at
    from public.gti_missions_challenge_entries e
    join public.gti_missions_challenges c on c.id=e.challenge_id
    join public.gti_missions_profiles p on p.user_id=e.user_id
    where e.photo_path is not null and e.photo_expires_at>now()
    union all
    select e.id,null::uuid,'AquaXP League'::text,'💧'::text,e.user_id,
      p.display_name,p.username,(e.logged_at at time zone 'America/Sao_Paulo')::date,
      e.logged_at,e.photo_path,e.photo_expires_at
    from public.gti_missions_water_entries e
    join public.gti_missions_profiles p on p.user_id=e.user_id
    where e.photo_path is not null and e.photo_expires_at>now()
    union all
    select e.id,null::uuid,'Tech Rat'::text,'⚡'::text,e.user_id,
      p.display_name,p.username,(e.logged_at at time zone 'America/Sao_Paulo')::date,
      e.logged_at,e.photo_path,e.photo_expires_at
    from public.gti_missions_exercise_entries e
    join public.gti_missions_profiles p on p.user_id=e.user_id
    where e.photo_path is not null and e.photo_expires_at>now()
  ) proofs
  order by completed_at desc
  limit 100
) x;
$$;

revoke all on function public.gti_missions_log_water(integer) from public, anon;
revoke all on function public.gti_missions_log_water(integer,text) from public, anon;
revoke all on function public.gti_missions_log_exercise(text,integer) from public, anon;
revoke all on function public.gti_missions_log_exercise(text,integer,text) from public, anon;
grant execute on function public.gti_missions_log_water(integer) to authenticated, service_role;
grant execute on function public.gti_missions_log_water(integer,text) to authenticated, service_role;
grant execute on function public.gti_missions_log_exercise(text,integer) to authenticated, service_role;
grant execute on function public.gti_missions_log_exercise(text,integer,text) to authenticated, service_role;

drop policy if exists "GTI Missions users and admins can view checkin proof" on storage.objects;
create policy "GTI Missions users and admins can view checkin proof"
on storage.objects for select to authenticated
using (
  bucket_id='gti-missions-checkins'
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and (
    exists(select 1 from public.gti_missions_admins a where a.user_id=(select auth.uid()))
    or (
      (storage.foldername(name))[1]=(select auth.uid())::text
      and (
        exists(select 1 from public.gti_missions_challenge_entries e where e.photo_path=name and e.photo_expires_at>now())
        or exists(select 1 from public.gti_missions_water_entries e where e.photo_path=name and e.photo_expires_at>now())
        or exists(select 1 from public.gti_missions_exercise_entries e where e.photo_path=name and e.photo_expires_at>now())
      )
    )
  )
);

drop policy if exists "GTI Missions users can delete unlinked checkin proof" on storage.objects;
create policy "GTI Missions users can delete unlinked checkin proof"
on storage.objects for delete to authenticated
using (
  bucket_id='gti-missions-checkins'
  and (storage.foldername(name))[1]=(select auth.uid())::text
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and not exists(select 1 from public.gti_missions_challenge_entries e where e.photo_path=name)
  and not exists(select 1 from public.gti_missions_water_entries e where e.photo_path=name)
  and not exists(select 1 from public.gti_missions_exercise_entries e where e.photo_path=name)
);

commit;