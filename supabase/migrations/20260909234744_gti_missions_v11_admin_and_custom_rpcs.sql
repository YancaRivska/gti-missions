create or replace function public.gti_missions_is_admin() returns boolean
language sql security definer set search_path=public,pg_temp stable as $$
  select auth.uid() is not null
    and coalesce((auth.jwt()->>'is_anonymous')::boolean,true) is false
    and exists(select 1 from public.gti_missions_admins a where a.user_id=auth.uid());
$$;

create or replace function public.gti_missions_admin_bootstrap_open() returns boolean
language sql security definer set search_path=public,pg_temp stable as $$
  select auth.uid() is not null
    and coalesce((auth.jwt()->>'is_anonymous')::boolean,true) is false
    and not exists(select 1 from public.gti_missions_admins);
$$;

create or replace function public.gti_missions_claim_admin(p_code text) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_hash text;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then raise exception 'Permanent account required'; end if;
  if exists(select 1 from public.gti_missions_admins) then raise exception 'Administration is already configured'; end if;
  if not exists(select 1 from public.gti_missions_profiles p where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.1') then raise exception 'Current terms must be accepted'; end if;
  select code_hash into v_hash from public.gti_missions_admin_bootstrap where id=1;
  if v_hash is null or encode(digest(coalesce(p_code,''),'sha256'),'hex')<>v_hash then raise exception 'Invalid administration code'; end if;
  insert into public.gti_missions_admins(user_id,role) values(v_uid,'owner') on conflict(user_id) do nothing;
  return true;
end; $$;

create or replace function public.gti_missions_admin_create_challenge(
  p_title text,p_description text,p_icon text,p_mode text,p_unit_label text,p_daily_target numeric,
  p_weekly_target_days integer,p_xp_per_day integer,p_weekly_bonus_xp integer,p_starts_on date,p_ends_on date
) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_id uuid:=gen_random_uuid(); v_slug text; v_start date:=coalesce(p_starts_on,(now() at time zone 'America/Sao_Paulo')::date);
begin
  if not public.gti_missions_is_admin() then raise exception 'Admin required'; end if;
  if char_length(trim(p_title))<3 or char_length(trim(p_title))>80 then raise exception 'Invalid title'; end if;
  if char_length(coalesce(p_description,''))>500 then raise exception 'Description too long'; end if;
  if p_mode not in ('checkin','quantity') then raise exception 'Invalid challenge mode'; end if;
  if p_mode='quantity' and (p_daily_target is null or p_daily_target<=0) then raise exception 'Daily target required'; end if;
  if p_weekly_target_days not between 1 and 7 then raise exception 'Weekly target must be 1 to 7 days'; end if;
  if p_xp_per_day not between 1 and 100 or p_weekly_bonus_xp not between 0 and 250 then raise exception 'Invalid XP configuration'; end if;
  if p_ends_on is not null and p_ends_on<v_start then raise exception 'Invalid date range'; end if;
  v_slug:='mission-'||substr(replace(v_id::text,'-',''),1,12);
  insert into public.gti_missions_challenges(id,slug,title,description,icon,mode,unit_label,daily_target,weekly_target_days,xp_per_day,weekly_bonus_xp,starts_on,ends_on,created_by)
  values(v_id,v_slug,trim(p_title),trim(coalesce(p_description,'')),left(coalesce(nullif(trim(p_icon),''),'🎯'),16),p_mode,
    case when p_mode='checkin' then 'check-in' else left(coalesce(nullif(trim(p_unit_label),''),'unidades'),30) end,
    case when p_mode='checkin' then null else p_daily_target end,p_weekly_target_days,p_xp_per_day,p_weekly_bonus_xp,v_start,p_ends_on,v_uid);
  return v_id;
end; $$;

create or replace function public.gti_missions_admin_toggle_challenge(p_challenge_id uuid,p_active boolean) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not public.gti_missions_is_admin() then raise exception 'Admin required'; end if;
  update public.gti_missions_challenges set is_active=p_active,updated_at=now() where id=p_challenge_id;
  if not found then raise exception 'Challenge not found'; end if;
  return true;
end; $$;

create or replace function public.gti_missions_join_challenge(p_challenge_id uuid) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_today date:=(now() at time zone 'America/Sao_Paulo')::date;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then raise exception 'Permanent account required'; end if;
  if not exists(select 1 from public.gti_missions_profiles p where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.1') then raise exception 'Current terms must be accepted'; end if;
  if not exists(select 1 from public.gti_missions_challenges c where c.id=p_challenge_id and c.is_active and c.starts_on<=v_today and (c.ends_on is null or c.ends_on>=v_today)) then raise exception 'Challenge unavailable'; end if;
  insert into public.gti_missions_challenge_participants(challenge_id,user_id) values(p_challenge_id,v_uid) on conflict do nothing;
  return true;
end; $$;

create or replace function public.gti_missions_log_custom_challenge(p_challenge_id uuid,p_value numeric default 1,p_note text default null) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_uid uuid:=auth.uid(); v_today date:=(now() at time zone 'America/Sao_Paulo')::date; v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_c public.gti_missions_challenges%rowtype; v_before numeric:=0; v_after numeric:=0; v_was_completed boolean:=false; v_now_completed boolean:=false;
  v_xp integer:=0; v_xp_id uuid; v_completed_days integer:=0; v_badge_id uuid;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then raise exception 'Permanent account required'; end if;
  if not exists(select 1 from public.gti_missions_profiles p where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.1') then raise exception 'Current terms must be accepted'; end if;
  select * into v_c from public.gti_missions_challenges where id=p_challenge_id and is_active and starts_on<=v_today and (ends_on is null or ends_on>=v_today);
  if not found then raise exception 'Challenge unavailable'; end if;
  if not exists(select 1 from public.gti_missions_challenge_participants where challenge_id=p_challenge_id and user_id=v_uid) then raise exception 'Join challenge first'; end if;
  if char_length(coalesce(p_note,''))>180 then raise exception 'Note too long'; end if;
  select value,completed_at is not null into v_before,v_was_completed from public.gti_missions_challenge_entries where challenge_id=p_challenge_id and user_id=v_uid and entry_day=v_today;
  if not found then v_before:=0; v_was_completed:=false; end if;
  if v_c.mode='checkin' then
    v_after:=1;
  else
    if p_value is null or p_value<=0 then raise exception 'Value must be positive'; end if;
    if p_value>greatest(v_c.daily_target*10,100000) then raise exception 'Value too high'; end if;
    v_after:=v_before+p_value;
  end if;
  v_now_completed:=case when v_c.mode='checkin' then true else v_after>=v_c.daily_target end;
  insert into public.gti_missions_challenge_entries(challenge_id,user_id,entry_day,value,note,completed_at)
  values(p_challenge_id,v_uid,v_today,v_after,nullif(trim(coalesce(p_note,'')),''),case when v_now_completed then now() else null end)
  on conflict(challenge_id,user_id,entry_day) do update set value=excluded.value,note=coalesce(excluded.note,public.gti_missions_challenge_entries.note),completed_at=case when public.gti_missions_challenge_entries.completed_at is not null then public.gti_missions_challenge_entries.completed_at when v_now_completed then now() else null end,updated_at=now();
  if v_now_completed and not v_was_completed then
    insert into public.gti_missions_xp_events(user_id,source,xp,event_key) values(v_uid,'custom_day',v_c.xp_per_day,'custom_day:'||p_challenge_id::text||':'||v_today::text) on conflict(user_id,event_key) do nothing returning id into v_xp_id;
    if v_xp_id is not null then v_xp:=v_xp+v_c.xp_per_day; end if;
  end if;
  select count(*) into v_completed_days from public.gti_missions_challenge_entries e where e.challenge_id=p_challenge_id and e.user_id=v_uid and e.entry_day between v_week and v_week+6 and e.completed_at is not null;
  if v_completed_days>=v_c.weekly_target_days then
    insert into public.gti_missions_challenge_badges(challenge_id,user_id,week_start,label) values(p_challenge_id,v_uid,v_week,v_c.title||' • Semana '||to_char(v_week,'IW')) on conflict(challenge_id,user_id,week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null and v_c.weekly_bonus_xp>0 then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key) values(v_uid,'custom_week',v_c.weekly_bonus_xp,'custom_week:'||p_challenge_id::text||':'||v_week::text) on conflict(user_id,event_key) do nothing;
      v_xp:=v_xp+v_c.weekly_bonus_xp;
    end if;
  end if;
  return jsonb_build_object('value',v_after,'completed_today',v_now_completed,'week_completed_days',v_completed_days,'weekly_target_days',v_c.weekly_target_days,'xp_awarded',v_xp);
end; $$;

create or replace function public.gti_missions_custom_challenge_statuses() returns jsonb
language sql security definer set search_path=public,pg_temp stable as $$
with ctx as (
  select auth.uid() uid,(now() at time zone 'America/Sao_Paulo')::date today,date_trunc('week',now() at time zone 'America/Sao_Paulo')::date week_start
), valid as (
  select c.* from public.gti_missions_challenges c,ctx where c.is_active and c.starts_on<=ctx.today and (c.ends_on is null or c.ends_on>=ctx.today)
), data as (
  select c.id,c.slug,c.title,c.description,c.icon,c.mode,c.unit_label,c.daily_target,c.weekly_target_days,c.xp_per_day,c.weekly_bonus_xp,c.starts_on,c.ends_on,c.created_at,
    exists(select 1 from public.gti_missions_challenge_participants p,ctx where p.challenge_id=c.id and p.user_id=ctx.uid) as joined,
    coalesce((select e.value from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day=ctx.today),0) as today_value,
    exists(select 1 from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day=ctx.today and e.completed_at is not null) as today_completed,
    (select count(*) from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day between ctx.week_start and ctx.week_start+6 and e.completed_at is not null) as week_completed_days
  from valid c
)
select case when auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then '[]'::jsonb
  when not exists(select 1 from public.gti_missions_profiles p where p.user_id=auth.uid() and p.accepted_terms_at is not null and p.terms_version='1.1') then '[]'::jsonb
  else coalesce(jsonb_agg(to_jsonb(data) order by data.created_at),'[]'::jsonb) end
from data;
$$;
