begin;

-- First-party mission worlds reuse the existing challenge engine. This keeps
-- participation, daily progress, weekly badges and XP rules in one place.
insert into public.gti_missions_challenges (
  slug,title,description,icon,mode,unit_label,daily_target,
  weekly_target_days,xp_per_day,weekly_bonus_xp,starts_on,is_active,
  created_by,requires_photo
)
select
  'reading','Desafio da Leitura','Mais histórias. Grandes possibilidades.',
  '📖','quantity','páginas',20,5,25,100,
  (now() at time zone 'America/Sao_Paulo')::date,true,a.user_id,false
from public.gti_missions_admins a
order by case a.role when 'owner' then 0 else 1 end,a.created_at
limit 1
on conflict (slug) do update set
  title=excluded.title,
  description=excluded.description,
  icon=excluded.icon,
  mode=excluded.mode,
  unit_label=excluded.unit_label,
  daily_target=excluded.daily_target,
  weekly_target_days=excluded.weekly_target_days,
  xp_per_day=excluded.xp_per_day,
  weekly_bonus_xp=excluded.weekly_bonus_xp,
  is_active=true,
  requires_photo=false;

insert into public.gti_missions_challenges (
  slug,title,description,icon,mode,unit_label,daily_target,
  weekly_target_days,xp_per_day,weekly_bonus_xp,starts_on,is_active,
  created_by,requires_photo
)
select
  'screen-free','Desafio Sem Tela','Mais presença. Menos tela. Mais vida real.',
  '🌿','quantity','min offline',60,4,25,100,
  (now() at time zone 'America/Sao_Paulo')::date,true,a.user_id,false
from public.gti_missions_admins a
order by case a.role when 'owner' then 0 else 1 end,a.created_at
limit 1
on conflict (slug) do update set
  title=excluded.title,
  description=excluded.description,
  icon=excluded.icon,
  mode=excluded.mode,
  unit_label=excluded.unit_label,
  daily_target=excluded.daily_target,
  weekly_target_days=excluded.weekly_target_days,
  xp_per_day=excluded.xp_per_day,
  weekly_bonus_xp=excluded.weekly_bonus_xp,
  is_active=true,
  requires_photo=false;

create index if not exists gti_missions_xp_period_user_idx
  on public.gti_missions_xp_events(created_at,user_id);
create index if not exists gti_missions_water_period_user_idx
  on public.gti_missions_water_entries(logged_at,user_id);
create index if not exists gti_missions_exercise_period_user_idx
  on public.gti_missions_exercise_entries(logged_at,user_id);
create index if not exists gti_missions_challenge_period_user_idx
  on public.gti_missions_challenge_entries(challenge_id,entry_day,user_id);
create index if not exists gti_missions_challenge_badges_user_idx
  on public.gti_missions_challenge_badges(user_id);
create index if not exists gti_missions_challenge_participants_user_idx
  on public.gti_missions_challenge_participants(user_id);
create index if not exists gti_missions_challenges_created_by_idx
  on public.gti_missions_challenges(created_by);

create or replace function public.gti_missions_challenge_leaderboard(
  p_challenge text default 'global',
  p_period text default 'month'
)
returns table(
  user_id uuid,
  display_name text,
  username text,
  avatar_path text,
  xp bigint,
  score numeric,
  unit text,
  participating_challenges bigint,
  rank bigint
)
language plpgsql
stable
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  v_challenge text:=lower(coalesce(p_challenge,'global'));
  v_period text:=lower(coalesce(p_period,'month'));
  v_start date;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    return;
  end if;
  if not exists(
    select 1 from public.gti_missions_profiles p
    where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.2'
  ) then
    return;
  end if;
  if v_challenge not in ('global','aqua','rat-tech','reading','screen-free') then
    raise exception 'Invalid challenge ranking';
  end if;
  if v_period not in ('week','month','all') then
    raise exception 'Invalid ranking period';
  end if;

  v_start:=case v_period
    when 'week' then date_trunc('week',now() at time zone 'America/Sao_Paulo')::date
    when 'month' then date_trunc('month',now() at time zone 'America/Sao_Paulo')::date
    else date '2000-01-01'
  end;

  return query
  with challenge_ids as (
    select
      (select id from public.gti_missions_challenges where slug='reading' limit 1) as reading_id,
      (select id from public.gti_missions_challenges where slug='screen-free' limit 1) as screen_free_id
  ), profiles as (
    select p.user_id,p.display_name,p.username,p.avatar_path
    from public.gti_missions_profiles p
    where p.accepted_terms_at is not null and p.terms_version='1.2'
  ), global_metrics as (
    select p.user_id,p.display_name,p.username,p.avatar_path,
      coalesce(sum(x.xp),0)::bigint as xp,
      coalesce(sum(x.xp),0)::numeric as score,
      'XP'::text as unit,
      (
        (exists(select 1 from public.gti_missions_water_entries w where w.user_id=p.user_id))::int+
        (exists(select 1 from public.gti_missions_exercise_entries e where e.user_id=p.user_id))::int+
        (exists(select 1 from public.gti_missions_challenge_participants cp,challenge_ids ci where cp.user_id=p.user_id and cp.challenge_id=ci.reading_id))::int+
        (exists(select 1 from public.gti_missions_challenge_participants cp,challenge_ids ci where cp.user_id=p.user_id and cp.challenge_id=ci.screen_free_id))::int
      )::bigint as participating_challenges
    from profiles p
    join public.gti_missions_xp_events x on x.user_id=p.user_id
      and (x.created_at at time zone 'America/Sao_Paulo')::date>=v_start
    where v_challenge='global'
    group by p.user_id,p.display_name,p.username,p.avatar_path
  ), aqua_metrics as (
    select p.user_id,p.display_name,p.username,p.avatar_path,
      coalesce((select sum(x.xp) from public.gti_missions_xp_events x
        where x.user_id=p.user_id
          and (x.created_at at time zone 'America/Sao_Paulo')::date>=v_start
          and (x.source in ('water_log','water_goal') or x.event_key like 'badge:aqua:%')),0)::bigint as xp,
      sum(w.amount_ml)::numeric as score,'ml'::text as unit,1::bigint as participating_challenges
    from profiles p
    join public.gti_missions_water_entries w on w.user_id=p.user_id
      and (w.logged_at at time zone 'America/Sao_Paulo')::date>=v_start
    where v_challenge='aqua'
    group by p.user_id,p.display_name,p.username,p.avatar_path
  ), rat_metrics as (
    select p.user_id,p.display_name,p.username,p.avatar_path,
      coalesce((select sum(x.xp) from public.gti_missions_xp_events x
        where x.user_id=p.user_id
          and (x.created_at at time zone 'America/Sao_Paulo')::date>=v_start
          and (x.source='exercise_day' or x.event_key like 'badge:tech_rat:%')),0)::bigint as xp,
      sum(e.duration_minutes)::numeric as score,'min'::text as unit,1::bigint as participating_challenges
    from profiles p
    join public.gti_missions_exercise_entries e on e.user_id=p.user_id
      and (e.logged_at at time zone 'America/Sao_Paulo')::date>=v_start
    where v_challenge='rat-tech'
    group by p.user_id,p.display_name,p.username,p.avatar_path
  ), custom_metrics as (
    select p.user_id,p.display_name,p.username,p.avatar_path,
      coalesce((select sum(x.xp) from public.gti_missions_xp_events x
        where x.user_id=p.user_id
          and (x.created_at at time zone 'America/Sao_Paulo')::date>=v_start
          and x.source in ('custom_day','custom_week')
          and split_part(x.event_key,':',2)=c.id::text),0)::bigint as xp,
      sum(e.value)::numeric as score,c.unit_label::text as unit,1::bigint as participating_challenges
    from profiles p
    join public.gti_missions_challenge_participants cp on cp.user_id=p.user_id
    join public.gti_missions_challenges c on c.id=cp.challenge_id
      and c.slug=case v_challenge when 'reading' then 'reading' else 'screen-free' end
    join public.gti_missions_challenge_entries e on e.challenge_id=c.id and e.user_id=p.user_id
      and e.entry_day>=v_start
    where v_challenge in ('reading','screen-free')
    group by p.user_id,p.display_name,p.username,p.avatar_path,c.id,c.unit_label
  ), combined as (
    select gm.* from global_metrics gm where gm.xp>0
    union all select am.* from aqua_metrics am where am.score>0
    union all select rm.* from rat_metrics rm where rm.score>0
    union all select cm.* from custom_metrics cm where cm.score>0
  ), ranked as (
    select m.*,
      row_number() over(order by
        case when v_challenge='global' then m.xp::numeric else m.score end desc,
        m.xp desc,lower(m.username)
      )::bigint as position
    from combined m
  )
  select r.user_id,r.display_name,r.username,r.avatar_path,r.xp,r.score,r.unit,
    r.participating_challenges,r.position
  from ranked r
  order by r.position
  limit 100;
end;
$$;

create or replace function public.gti_missions_my_progress()
returns jsonb
language plpgsql
stable
security invoker
set search_path = 'public', 'pg_temp'
as $$
declare
  v_uid uuid:=auth.uid();
  v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_today date:=(now() at time zone 'America/Sao_Paulo')::date;
  v_reading_id uuid;
  v_screen_id uuid;
  v_stats jsonb;
  v_read_anchor date;
  v_screen_anchor date;
  v_read_streak integer:=0;
  v_screen_streak integer:=0;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    raise exception 'Permanent account required';
  end if;
  if not exists(
    select 1 from public.gti_missions_profiles p
    where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.2'
  ) then
    raise exception 'Current terms must be accepted';
  end if;

  select id into v_reading_id from public.gti_missions_challenges where slug='reading' limit 1;
  select id into v_screen_id from public.gti_missions_challenges where slug='screen-free' limit 1;
  v_stats:=public.gti_missions_my_stats();

  v_read_anchor:=case when exists(
    select 1 from public.gti_missions_challenge_entries
    where challenge_id=v_reading_id and user_id=v_uid and entry_day=v_today and completed_at is not null
  ) then v_today else v_today-1 end;
  with completed as (
    select entry_day,row_number() over(order by entry_day desc) as rn
    from public.gti_missions_challenge_entries
    where challenge_id=v_reading_id and user_id=v_uid and completed_at is not null and entry_day<=v_read_anchor
  ) select count(*) into v_read_streak from completed
    where entry_day=v_read_anchor-((rn-1)::integer);

  v_screen_anchor:=case when exists(
    select 1 from public.gti_missions_challenge_entries
    where challenge_id=v_screen_id and user_id=v_uid and entry_day=v_today and completed_at is not null
  ) then v_today else v_today-1 end;
  with completed as (
    select entry_day,row_number() over(order by entry_day desc) as rn
    from public.gti_missions_challenge_entries
    where challenge_id=v_screen_id and user_id=v_uid and completed_at is not null and entry_day<=v_screen_anchor
  ) select count(*) into v_screen_streak from completed
    where entry_day=v_screen_anchor-((rn-1)::integer);

  return v_stats || jsonb_build_object(
    'missions_completed',
      (select count(*) from public.gti_missions_water_days where user_id=v_uid and goal_completed_at is not null)+
      (select count(distinct(logged_at at time zone 'America/Sao_Paulo')::date) from public.gti_missions_exercise_entries where user_id=v_uid and duration_minutes>=5)+
      (select count(*) from public.gti_missions_challenge_entries where user_id=v_uid and completed_at is not null),
    'water_total_ml',(select coalesce(sum(amount_ml),0) from public.gti_missions_water_entries where user_id=v_uid),
    'exercise_total_minutes',(select coalesce(sum(duration_minutes),0) from public.gti_missions_exercise_entries where user_id=v_uid),
    'exercise_total_sessions',(select count(*) from public.gti_missions_exercise_entries where user_id=v_uid),
    'reading_id',v_reading_id,
    'reading_joined',exists(select 1 from public.gti_missions_challenge_participants where user_id=v_uid and challenge_id=v_reading_id),
    'reading_today_pages',(select coalesce(value,0) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_reading_id and entry_day=v_today),
    'reading_total_pages',(select coalesce(sum(value),0) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_reading_id),
    'reading_total_days',(select count(*) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_reading_id and completed_at is not null),
    'reading_week_days',(select count(*) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_reading_id and entry_day between v_week and v_week+6 and completed_at is not null),
    'reading_week_target',(select weekly_target_days from public.gti_missions_challenges where id=v_reading_id),
    'reading_daily_target',(select daily_target from public.gti_missions_challenges where id=v_reading_id),
    'reading_streak',v_read_streak,
    'screen_free_id',v_screen_id,
    'screen_free_joined',exists(select 1 from public.gti_missions_challenge_participants where user_id=v_uid and challenge_id=v_screen_id),
    'screen_free_today_minutes',(select coalesce(value,0) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_screen_id and entry_day=v_today),
    'screen_free_total_minutes',(select coalesce(sum(value),0) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_screen_id),
    'screen_free_total_days',(select count(*) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_screen_id and completed_at is not null),
    'screen_free_week_days',(select count(*) from public.gti_missions_challenge_entries where user_id=v_uid and challenge_id=v_screen_id and entry_day between v_week and v_week+6 and completed_at is not null),
    'screen_free_week_target',(select weekly_target_days from public.gti_missions_challenges where id=v_screen_id),
    'screen_free_daily_target',(select daily_target from public.gti_missions_challenges where id=v_screen_id),
    'screen_free_streak',v_screen_streak,
    'aqua_xp',(select coalesce(sum(xp),0) from public.gti_missions_xp_events where user_id=v_uid and (source in ('water_log','water_goal') or event_key like 'badge:aqua:%')),
    'rat_xp',(select coalesce(sum(xp),0) from public.gti_missions_xp_events where user_id=v_uid and (source='exercise_day' or event_key like 'badge:tech_rat:%')),
    'reading_xp',(select coalesce(sum(xp),0) from public.gti_missions_xp_events where user_id=v_uid and source in ('custom_day','custom_week') and split_part(event_key,':',2)=v_reading_id::text),
    'screen_free_xp',(select coalesce(sum(xp),0) from public.gti_missions_xp_events where user_id=v_uid and source in ('custom_day','custom_week') and split_part(event_key,':',2)=v_screen_id::text)
  );
end;
$$;

revoke all on function public.gti_missions_challenge_leaderboard(text,text) from public,anon;
revoke all on function public.gti_missions_my_progress() from public,anon;
grant execute on function public.gti_missions_challenge_leaderboard(text,text) to authenticated,service_role;
grant execute on function public.gti_missions_my_progress() to authenticated,service_role;

commit;
