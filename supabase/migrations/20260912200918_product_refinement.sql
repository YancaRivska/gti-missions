-- Monthly results are derived from immutable dated events; lifetime progress is never reset.
create schema if not exists gti_private;
revoke all on schema gti_private from public, anon, authenticated;
create table public.gti_missions_seasons (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 80),
 slug text unique not null, start_date date unique not null, end_date date not null,
 created_at timestamptz not null default now(),
 check(start_date=date_trunc('month',start_date)::date),
 check(end_date=(start_date+interval '1 month - 1 day')::date)
);
create table gti_private.season_codes (season_id uuid primary key references public.gti_missions_seasons on delete cascade, code_hash text not null);
create table public.gti_missions_season_members (
 user_id uuid references public.gti_missions_profiles(user_id) on delete cascade,
 season_id uuid references public.gti_missions_seasons on delete cascade,
 joined_at timestamptz not null default now(), primary key(user_id,season_id)
);
create table gti_private.code_attempts(user_id uuid primary key references public.gti_missions_profiles(user_id) on delete cascade, tried_at timestamptz not null, attempts int not null);
create function gti_private.ensure_season(p_day date) returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid; d date:=date_trunc('month',p_day)::date;
begin
 insert into public.gti_missions_seasons(name,slug,start_date,end_date)
 values('MISSÃO — '||(array['JANEIRO','FEVEREIRO','MARÇO','ABRIL','MAIO','JUNHO','JULHO','AGOSTO','SETEMBRO','OUTUBRO','NOVEMBRO','DEZEMBRO'])[extract(month from d)::int]||' '||extract(year from d)::text,to_char(d,'YYYY-MM'),d,(d+interval '1 month - 1 day')::date)
 on conflict(start_date) do nothing;
 select id into sid from public.gti_missions_seasons where start_date=d; return sid;
end $$;
select gti_private.ensure_season((now() at time zone 'America/Sao_Paulo')::date);
select gti_private.ensure_season(d::date) from (select distinct date_trunc('month',created_at at time zone 'America/Sao_Paulo') d from public.gti_missions_xp_events) x;
insert into public.gti_missions_season_members(user_id,season_id)
select distinct x.user_id,s.id from public.gti_missions_xp_events x join public.gti_missions_seasons s on (x.created_at at time zone 'America/Sao_Paulo')::date between s.start_date and s.end_date on conflict do nothing;
create function gti_private.require_season() returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 if not public.gti_missions_is_permanent_user() then raise exception 'Permanent account required'; end if;
 perform 1 from public.gti_missions_profiles where user_id=auth.uid() and accepted_terms_at is not null and terms_version='1.2' for update;
 if not found then raise exception 'Current terms must be accepted'; end if;
 sid:=gti_private.ensure_season((now() at time zone 'America/Sao_Paulo')::date);
 if exists(select 1 from gti_private.season_codes where season_id=sid) and not exists(select 1 from public.gti_missions_season_members where user_id=auth.uid() and season_id=sid) then raise exception 'Season code required'; end if;
 insert into public.gti_missions_season_members(user_id,season_id) values(auth.uid(),sid) on conflict do nothing;
 return sid;
end $$;
create function public.gti_missions_current_season() returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid; result jsonb;
begin
 if not public.gti_missions_is_permanent_user() then raise exception 'Permanent account required'; end if;
 sid:=gti_private.ensure_season((now() at time zone 'America/Sao_Paulo')::date);
 select to_jsonb(s)||jsonb_build_object('status','active','requires_code',exists(select 1 from gti_private.season_codes where season_id=sid),'joined',exists(select 1 from public.gti_missions_season_members where season_id=sid and user_id=auth.uid())) into result from public.gti_missions_seasons s where id=sid;
 return result;
end $$;
create function public.gti_missions_join_season(p_code text default '') returns boolean language plpgsql security definer set search_path='' as $$
declare sid uuid; h text; n int;
begin
 if not public.gti_missions_is_permanent_user() then raise exception 'Permanent account required'; end if;
 perform 1 from public.gti_missions_profiles where user_id=auth.uid() for update;
 if not found then raise exception 'Profile required'; end if;
 sid:=gti_private.ensure_season((now() at time zone 'America/Sao_Paulo')::date);
 if exists(select 1 from public.gti_missions_season_members where user_id=auth.uid() and season_id=sid) then return true; end if;
 insert into gti_private.code_attempts values(auth.uid(),now(),1) on conflict(user_id) do update set attempts=case when gti_private.code_attempts.tried_at<now()-interval '15 minutes' then 1 else gti_private.code_attempts.attempts+1 end,tried_at=case when gti_private.code_attempts.tried_at<now()-interval '15 minutes' then now() else gti_private.code_attempts.tried_at end returning attempts into n;
 if n>10 then return false; end if;
 select code_hash into h from gti_private.season_codes where season_id=sid;
 if h is not null and h<>encode(extensions.digest(upper(trim(coalesce(p_code,''))),'sha256'),'hex') then return false; end if;
 insert into public.gti_missions_season_members(user_id,season_id) values(auth.uid(),sid) on conflict do nothing;
 return true;
end $$;
create function public.gti_missions_admin_season(p_month date,p_code text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 if not public.gti_missions_is_admin() then raise exception 'Admin required'; end if;
 if p_month is null or length(p_code)>80 then raise exception 'Invalid season'; end if;
 sid:=gti_private.ensure_season(p_month);
 if nullif(trim(p_code),'') is null then delete from gti_private.season_codes where season_id=sid;
 else
 if length(trim(p_code))<6 then raise exception 'Code too short'; end if;
 insert into gti_private.season_codes values(sid,encode(extensions.digest(upper(trim(p_code)),'sha256'),'hex')) on conflict(season_id) do update set code_hash=excluded.code_hash;
 end if; return sid;
end $$;

alter table public.gti_missions_profiles add column profile_visibility text not null default 'community' check(profile_visibility in ('community','private')),
 add column show_progress boolean not null default true, add column show_badges boolean not null default true,
 add column show_notes boolean not null default true, add column show_history boolean not null default false,
 add column tagline text not null default '' check(length(tagline)<=120);
create function public.gti_missions_can_view(p_user uuid,p_section text default 'profile') returns boolean language sql stable security definer set search_path='' as $$
 select public.gti_missions_is_permanent_user() and exists(select 1 from public.gti_missions_profiles p where p.user_id=p_user and (p.user_id=auth.uid() or (p.profile_visibility='community' and case p_section when 'notes' then p.show_notes when 'badges' then p.show_badges when 'progress' then p.show_progress when 'history' then p.show_history else true end)))
$$;
create table public.gti_missions_notes (
 id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references public.gti_missions_profiles(user_id) on delete cascade,
 title text not null default '' check(length(title)<=100), content text not null check(length(trim(content)) between 1 and 3000),
 visibility text not null default 'private' check(visibility in ('private','public')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index gti_notes_user_cursor on public.gti_missions_notes(user_id,created_at desc,id desc);
create trigger notes_updated before update on public.gti_missions_notes for each row execute function public.gti_missions_set_updated_at();
alter table public.gti_missions_notes enable row level security;
revoke all on public.gti_missions_notes from anon,authenticated;
grant select,delete on public.gti_missions_notes to authenticated;
grant insert(user_id,title,content,visibility),update(title,content,visibility) on public.gti_missions_notes to authenticated;
create policy notes_read on public.gti_missions_notes for select to authenticated using(public.gti_missions_is_permanent_user() and (user_id=auth.uid() or (visibility='public' and public.gti_missions_can_view(user_id,'notes'))));
create policy notes_insert on public.gti_missions_notes for insert to authenticated with check(user_id=auth.uid() and public.gti_missions_is_permanent_user());
create policy notes_update on public.gti_missions_notes for update to authenticated using(user_id=auth.uid() and public.gti_missions_is_permanent_user()) with check(user_id=auth.uid() and public.gti_missions_is_permanent_user());
create policy notes_delete on public.gti_missions_notes for delete to authenticated using(user_id=auth.uid() and public.gti_missions_is_permanent_user());

create table public.gti_missions_badge_definitions (
 id text primary key, challenge_type text not null check(challenge_type in ('aqua','tech')), name text not null, description text not null,
 icon text not null, rule_type text not null check(rule_type in ('days','streak','week','season','perfect')), rule_value int not null check(rule_value>0),
 is_secret boolean not null default false, sort_order int not null
);
create table public.gti_missions_user_badges (
 user_id uuid references public.gti_missions_profiles(user_id) on delete cascade, badge_id text references public.gti_missions_badge_definitions,
 season_id uuid references public.gti_missions_seasons, unlocked_at timestamptz not null default now(), primary key(user_id,badge_id)
);
create table gti_private.submissions(user_id uuid references public.gti_missions_profiles(user_id) on delete cascade, request_id uuid, payload jsonb not null, result jsonb,created_at timestamptz not null default now(),primary key(user_id,request_id));
create index gti_badges_recent on public.gti_missions_user_badges(user_id,unlocked_at desc,badge_id);
create index gti_profiles_discovery on public.gti_missions_profiles(username) where profile_visibility='community';
create function gti_private.badge_metrics(p_user uuid,p_type text,p_day date) returns jsonb language sql stable set search_path='' as $$
 with days as (
 select day from public.gti_missions_water_days where p_type='aqua' and user_id=p_user and goal_completed_at is not null and day<=p_day
 union select day from public.gti_missions_exercise_days where p_type='tech' and user_id=p_user and total_minutes>=5 and day<=p_day
 ), islands as(select day,day-row_number() over(order by day)::int as grp from days),
 runs as(select count(*) n from islands group by grp), weeks as(select count(*) n from days group by date_trunc('week',day)),
 perfect as(select count(*) n,date_trunc('month',day)::date m from days group by date_trunc('month',day))
 select jsonb_build_object('days',(select count(*) from days),'streak',coalesce((select max(n) from runs),0),'week',coalesce((select max(n) from weeks),0),'season',coalesce((select max(n) from perfect),0),'perfect',(select count(*) from perfect where n=extract(day from m+interval '1 month - 1 day')))
$$;
create function gti_private.evaluate_badges(p_type text) returns jsonb language plpgsql security definer set search_path='' as $$
declare m jsonb; unlocked jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 m:=gti_private.badge_metrics(auth.uid(),p_type,(now() at time zone 'America/Sao_Paulo')::date);
 with granted as (
 insert into public.gti_missions_user_badges(user_id,badge_id,season_id)
 select auth.uid(),b.id,case when rule_type in ('season','perfect') then gti_private.ensure_season((now() at time zone 'America/Sao_Paulo')::date) end from public.gti_missions_badge_definitions b
 where b.challenge_type=p_type and (m->>b.rule_type)::int>=b.rule_value on conflict do nothing returning badge_id
 ) select coalesce(jsonb_agg(to_jsonb(b)),'[]') into unlocked from granted g join public.gti_missions_badge_definitions b on b.id=g.badge_id;
 return unlocked;
end $$;
create function public.gti_missions_collection(p_type text default 'aqua',p_username text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid; result jsonb;
begin
 if not public.gti_missions_is_permanent_user() then raise exception 'Permanent account required'; end if;
 if p_username is null then uid:=auth.uid(); else select user_id into uid from public.gti_missions_profiles where username=p_username; end if;
 if not public.gti_missions_can_view(uid,'badges') then return '[]'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'challenge_type',b.challenge_type,'name',case when b.is_secret and u.badge_id is null then 'Emblema secreto' else b.name end,'description',case when b.is_secret and u.badge_id is null then 'Continue sua missão para descobrir.' else b.description end,'icon',case when b.is_secret and u.badge_id is null then '✦' else b.icon end,'state',case when u.badge_id is not null then 'unlocked' when b.is_secret then 'secret' else 'locked' end,'unlocked_at',u.unlocked_at) order by b.sort_order),'[]') into result
 from public.gti_missions_badge_definitions b left join public.gti_missions_user_badges u on u.badge_id=b.id and u.user_id=uid where b.challenge_type=p_type;
 return result;
end $$;

alter table public.gti_missions_seasons enable row level security;
alter table public.gti_missions_season_members enable row level security;
alter table public.gti_missions_badge_definitions enable row level security;
alter table public.gti_missions_user_badges enable row level security;
revoke all on public.gti_missions_seasons,public.gti_missions_season_members,public.gti_missions_badge_definitions,public.gti_missions_user_badges from anon,authenticated;
grant select on public.gti_missions_seasons,public.gti_missions_season_members,public.gti_missions_user_badges to authenticated;
create policy seasons_read on public.gti_missions_seasons for select to authenticated using(public.gti_missions_is_permanent_user());
create policy season_members_read on public.gti_missions_season_members for select to authenticated using(user_id=auth.uid() and public.gti_missions_is_permanent_user());
create policy badges_read on public.gti_missions_user_badges for select to authenticated using(user_id=auth.uid() and public.gti_missions_is_permanent_user());
-- Secret badge definitions are never directly exposed; collection RPC redacts locked secrets.

insert into public.gti_missions_badge_definitions values('aqua-days-1','aqua','Primeira Gota','Conclua a missão em 1 dias no total.','💧','days',1,false,0);

insert into public.gti_missions_badge_definitions values('aqua-days-3','aqua','3 metas concluídas','Conclua a missão em 3 dias no total.','💧','days',3,false,1);

insert into public.gti_missions_badge_definitions values('aqua-days-7','aqua','7 metas concluídas','Conclua a missão em 7 dias no total.','💧','days',7,false,2);

insert into public.gti_missions_badge_definitions values('aqua-days-10','aqua','10 metas concluídas','Conclua a missão em 10 dias no total.','💧','days',10,false,3);

insert into public.gti_missions_badge_definitions values('aqua-days-14','aqua','14 metas concluídas','Conclua a missão em 14 dias no total.','💧','days',14,false,4);

insert into public.gti_missions_badge_definitions values('aqua-days-21','aqua','21 metas concluídas','Conclua a missão em 21 dias no total.','💧','days',21,false,5);

insert into public.gti_missions_badge_definitions values('aqua-days-25','aqua','25 metas concluídas','Conclua a missão em 25 dias no total.','💧','days',25,false,6);

insert into public.gti_missions_badge_definitions values('aqua-days-30','aqua','30 metas concluídas','Conclua a missão em 30 dias no total.','💧','days',30,false,7);

insert into public.gti_missions_badge_definitions values('aqua-days-50','aqua','50 metas concluídas','Conclua a missão em 50 dias no total.','💧','days',50,false,8);

insert into public.gti_missions_badge_definitions values('aqua-days-75','aqua','75 metas concluídas','Conclua a missão em 75 dias no total.','💧','days',75,false,9);

insert into public.gti_missions_badge_definitions values('aqua-days-100','aqua','100 metas concluídas','Conclua a missão em 100 dias no total.','💧','days',100,true,10);

insert into public.gti_missions_badge_definitions values('aqua-days-150','aqua','150 metas concluídas','Conclua a missão em 150 dias no total.','💧','days',150,true,11);

insert into public.gti_missions_badge_definitions values('aqua-streak-3','aqua','Sequência 3','Conclua a missão por 3 dias consecutivos.','💧','streak',3,false,12);

insert into public.gti_missions_badge_definitions values('aqua-streak-5','aqua','Sequência 5','Conclua a missão por 5 dias consecutivos.','💧','streak',5,false,13);

insert into public.gti_missions_badge_definitions values('aqua-streak-7','aqua','Sequência 7','Conclua a missão por 7 dias consecutivos.','💧','streak',7,false,14);

insert into public.gti_missions_badge_definitions values('aqua-streak-10','aqua','Sequência 10','Conclua a missão por 10 dias consecutivos.','💧','streak',10,false,15);

insert into public.gti_missions_badge_definitions values('aqua-streak-15','aqua','Sequência 15','Conclua a missão por 15 dias consecutivos.','💧','streak',15,false,16);

insert into public.gti_missions_badge_definitions values('aqua-streak-20','aqua','Sequência 20','Conclua a missão por 20 dias consecutivos.','💧','streak',20,false,17);

insert into public.gti_missions_badge_definitions values('aqua-streak-25','aqua','Sequência 25','Conclua a missão por 25 dias consecutivos.','💧','streak',25,false,18);

insert into public.gti_missions_badge_definitions values('aqua-streak-30','aqua','Sequência 30','Conclua a missão por 30 dias consecutivos.','💧','streak',30,false,19);

insert into public.gti_missions_badge_definitions values('aqua-week-3','aqua','Semana 3/7','Conclua a missão em 3 dias de uma mesma semana.','💧','week',3,false,20);

insert into public.gti_missions_badge_definitions values('aqua-week-5','aqua','Semana 5/7','Conclua a missão em 5 dias de uma mesma semana.','💧','week',5,false,21);

insert into public.gti_missions_badge_definitions values('aqua-week-7','aqua','Semana 7/7','Conclua a missão em 7 dias de uma mesma semana.','💧','week',7,false,22);

insert into public.gti_missions_badge_definitions values('aqua-season-7','aqua','7 dias na temporada','Conclua a missão em 7 dias da mesma temporada.','💧','season',7,false,23);

insert into public.gti_missions_badge_definitions values('aqua-season-10','aqua','10 dias na temporada','Conclua a missão em 10 dias da mesma temporada.','💧','season',10,false,24);

insert into public.gti_missions_badge_definitions values('aqua-season-14','aqua','14 dias na temporada','Conclua a missão em 14 dias da mesma temporada.','💧','season',14,false,25);

insert into public.gti_missions_badge_definitions values('aqua-season-20','aqua','20 dias na temporada','Conclua a missão em 20 dias da mesma temporada.','💧','season',20,false,26);

insert into public.gti_missions_badge_definitions values('aqua-season-25','aqua','25 dias na temporada','Conclua a missão em 25 dias da mesma temporada.','💧','season',25,false,27);

insert into public.gti_missions_badge_definitions values('aqua-season-28','aqua','28 dias na temporada','Conclua a missão em 28 dias da mesma temporada.','💧','season',28,false,28);

insert into public.gti_missions_badge_definitions values('aqua-perfect-1','aqua','Temporada Perfeita','Conclua a missão em todos os dias de um mês.','💧','perfect',1,true,29);

insert into public.gti_missions_badge_definitions values('tech-days-1','tech','Primeiro Treino','Conclua a missão em 1 dias no total.','🏋️','days',1,false,0);

insert into public.gti_missions_badge_definitions values('tech-days-3','tech','3 treinos','Conclua a missão em 3 dias no total.','🏋️','days',3,false,1);

insert into public.gti_missions_badge_definitions values('tech-days-7','tech','7 treinos','Conclua a missão em 7 dias no total.','🏋️','days',7,false,2);

insert into public.gti_missions_badge_definitions values('tech-days-10','tech','10 treinos','Conclua a missão em 10 dias no total.','🏋️','days',10,false,3);

insert into public.gti_missions_badge_definitions values('tech-days-14','tech','14 treinos','Conclua a missão em 14 dias no total.','🏋️','days',14,false,4);

insert into public.gti_missions_badge_definitions values('tech-days-21','tech','21 treinos','Conclua a missão em 21 dias no total.','🏋️','days',21,false,5);

insert into public.gti_missions_badge_definitions values('tech-days-25','tech','25 treinos','Conclua a missão em 25 dias no total.','🏋️','days',25,false,6);

insert into public.gti_missions_badge_definitions values('tech-days-30','tech','30 treinos','Conclua a missão em 30 dias no total.','🏋️','days',30,false,7);

insert into public.gti_missions_badge_definitions values('tech-days-50','tech','50 treinos','Conclua a missão em 50 dias no total.','🏋️','days',50,false,8);

insert into public.gti_missions_badge_definitions values('tech-days-75','tech','75 treinos','Conclua a missão em 75 dias no total.','🏋️','days',75,false,9);

insert into public.gti_missions_badge_definitions values('tech-days-100','tech','100 treinos','Conclua a missão em 100 dias no total.','🏋️','days',100,true,10);

insert into public.gti_missions_badge_definitions values('tech-days-150','tech','150 treinos','Conclua a missão em 150 dias no total.','🏋️','days',150,true,11);

insert into public.gti_missions_badge_definitions values('tech-streak-3','tech','Sequência 3','Conclua a missão por 3 dias consecutivos.','🏋️','streak',3,false,12);

insert into public.gti_missions_badge_definitions values('tech-streak-5','tech','Sequência 5','Conclua a missão por 5 dias consecutivos.','🏋️','streak',5,false,13);

insert into public.gti_missions_badge_definitions values('tech-streak-7','tech','Sequência 7','Conclua a missão por 7 dias consecutivos.','🏋️','streak',7,false,14);

insert into public.gti_missions_badge_definitions values('tech-streak-10','tech','Sequência 10','Conclua a missão por 10 dias consecutivos.','🏋️','streak',10,false,15);

insert into public.gti_missions_badge_definitions values('tech-streak-15','tech','Sequência 15','Conclua a missão por 15 dias consecutivos.','🏋️','streak',15,false,16);

insert into public.gti_missions_badge_definitions values('tech-streak-20','tech','Sequência 20','Conclua a missão por 20 dias consecutivos.','🏋️','streak',20,false,17);

insert into public.gti_missions_badge_definitions values('tech-streak-25','tech','Sequência 25','Conclua a missão por 25 dias consecutivos.','🏋️','streak',25,false,18);

insert into public.gti_missions_badge_definitions values('tech-streak-30','tech','Sequência 30','Conclua a missão por 30 dias consecutivos.','🏋️','streak',30,false,19);

insert into public.gti_missions_badge_definitions values('tech-week-3','tech','Semana 3/7','Conclua a missão em 3 dias de uma mesma semana.','🏋️','week',3,false,20);

insert into public.gti_missions_badge_definitions values('tech-week-5','tech','Semana 5/7','Conclua a missão em 5 dias de uma mesma semana.','🏋️','week',5,false,21);

insert into public.gti_missions_badge_definitions values('tech-week-7','tech','Semana 7/7','Conclua a missão em 7 dias de uma mesma semana.','🏋️','week',7,false,22);

insert into public.gti_missions_badge_definitions values('tech-season-7','tech','7 dias na temporada','Conclua a missão em 7 dias da mesma temporada.','🏋️','season',7,false,23);

insert into public.gti_missions_badge_definitions values('tech-season-10','tech','10 dias na temporada','Conclua a missão em 10 dias da mesma temporada.','🏋️','season',10,false,24);

insert into public.gti_missions_badge_definitions values('tech-season-14','tech','14 dias na temporada','Conclua a missão em 14 dias da mesma temporada.','🏋️','season',14,false,25);

insert into public.gti_missions_badge_definitions values('tech-season-20','tech','20 dias na temporada','Conclua a missão em 20 dias da mesma temporada.','🏋️','season',20,false,26);

insert into public.gti_missions_badge_definitions values('tech-season-25','tech','25 dias na temporada','Conclua a missão em 25 dias da mesma temporada.','🏋️','season',25,false,27);

insert into public.gti_missions_badge_definitions values('tech-season-28','tech','28 dias na temporada','Conclua a missão em 28 dias da mesma temporada.','🏋️','season',28,false,28);

insert into public.gti_missions_badge_definitions values('tech-perfect-1','tech','Temporada Perfeita','Conclua a missão em todos os dias de um mês.','🏋️','perfect',1,true,29);

CREATE OR REPLACE FUNCTION gti_private.log_water(p_amount_ml integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'storage', 'pg_temp'
AS $function$
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
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    raise exception 'Permanent account required';
  end if;
  if p_amount_ml is null or p_amount_ml<50 or p_amount_ml>2000 then
    raise exception 'Amount must be between 50 and 2000 ml';
  end if;

  select water_target_ml into v_target
  from public.gti_missions_profiles
  where user_id=v_uid and accepted_terms_at is not null and terms_version='1.2';
  if v_target is null then raise exception 'Current terms must be accepted'; end if;


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
    user_id,amount_ml
  ) values(
    v_uid,p_amount_ml
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
    'week_completed_days',v_completed_days
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION gti_private.log_exercise(p_exercise_name text, p_duration_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'storage', 'pg_temp'
AS $function$
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
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    raise exception 'Permanent account required';
  end if;
  if p_exercise_name is null or char_length(trim(p_exercise_name))<1 or char_length(trim(p_exercise_name))>80 then
    raise exception 'Invalid exercise';
  end if;
  if p_duration_minutes is null or p_duration_minutes<5 or p_duration_minutes>300 then
    raise exception 'Duration must be between 5 and 300 minutes';
  end if;

  select exercise_weekly_target into v_weekly_target
  from public.gti_missions_profiles
  where user_id=v_uid and accepted_terms_at is not null and terms_version='1.2';
  if v_weekly_target is null then raise exception 'Current terms must be accepted'; end if;
  v_weekly_target:=greatest(3,least(7,v_weekly_target));


  if exists(select 1 from public.gti_missions_exercise_days where user_id=v_uid and day=v_day and total_minutes>=5) then return jsonb_build_object('xp_awarded',0,'already_completed',true); end if;

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
    user_id,exercise_name,duration_minutes
  ) values(
    v_uid,trim(p_exercise_name),p_duration_minutes
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
    'today_minutes',v_daily_minutes
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION gti_private.log_custom(p_challenge_id uuid, p_value numeric DEFAULT 1, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'storage', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_today date:=(now() at time zone 'America/Sao_Paulo')::date;
  v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_c public.gti_missions_challenges%rowtype;
  v_before numeric:=0;
  v_after numeric:=0;
  v_was_completed boolean:=false;
  v_now_completed boolean:=false;
  v_xp integer:=0;
  v_xp_id uuid;
  v_completed_days integer:=0;
  v_badge_id uuid;
  v_entry_cap numeric;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then raise exception 'Permanent account required'; end if;
  if not exists(select 1 from public.gti_missions_profiles p where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.2') then raise exception 'Current terms must be accepted'; end if;
  select * into v_c from public.gti_missions_challenges where id=p_challenge_id and is_active and starts_on<=v_today and (ends_on is null or ends_on>=v_today);
  if not found then raise exception 'Challenge unavailable'; end if;
  if not exists(select 1 from public.gti_missions_challenge_participants where challenge_id=p_challenge_id and user_id=v_uid) then raise exception 'Join challenge first'; end if;
  if char_length(coalesce(p_note,''))>180 then raise exception 'Note too long'; end if;
  select value,completed_at is not null into v_before,v_was_completed
    from public.gti_missions_challenge_entries
    where challenge_id=p_challenge_id and user_id=v_uid and entry_day=v_today;
  if not found then v_before:=0; v_was_completed:=false; end if;

  if v_c.mode='checkin' then
    v_after:=1;
  else
    if p_value is null or p_value<=0 then raise exception 'Value must be positive'; end if;
    v_entry_cap:=least(greatest(v_c.daily_target*10,10),100000);
    if p_value>v_entry_cap then raise exception 'Value too high'; end if;
    v_after:=v_before+p_value;
    if v_after>least(greatest(v_c.daily_target*20,v_c.daily_target),1000000) then raise exception 'Daily value limit reached'; end if;
  end if;
  v_now_completed:=case when v_c.mode='checkin' then true else v_after>=v_c.daily_target end;

  insert into public.gti_missions_challenge_entries(
    challenge_id,user_id,entry_day,value,note,completed_at
  ) values(
    p_challenge_id,v_uid,v_today,v_after,nullif(trim(coalesce(p_note,'')),''),
    case when v_now_completed then now() else null end
  )
  on conflict(challenge_id,user_id,entry_day) do update set
    value=excluded.value,
    note=coalesce(excluded.note,public.gti_missions_challenge_entries.note),
    completed_at=case
      when public.gti_missions_challenge_entries.completed_at is not null then public.gti_missions_challenge_entries.completed_at
      when v_now_completed then now() else null end,
    updated_at=now();

  if v_now_completed and not v_was_completed then
    insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
    values(v_uid,'custom_day',v_c.xp_per_day,'custom_day:'||p_challenge_id::text||':'||v_today::text)
    on conflict(user_id,event_key) do nothing returning id into v_xp_id;
    if v_xp_id is not null then v_xp:=v_xp+v_c.xp_per_day; end if;
  end if;

  select count(*) into v_completed_days
  from public.gti_missions_challenge_entries e
  where e.challenge_id=p_challenge_id and e.user_id=v_uid
    and e.entry_day between v_week and v_week+6 and e.completed_at is not null;

  if v_completed_days>=v_c.weekly_target_days then
    insert into public.gti_missions_challenge_badges(challenge_id,user_id,week_start,label)
    values(p_challenge_id,v_uid,v_week,v_c.title||' • Semana '||to_char(v_week,'IW'))
    on conflict(challenge_id,user_id,week_start) do nothing returning id into v_badge_id;
    if v_badge_id is not null and v_c.weekly_bonus_xp>0 then
      insert into public.gti_missions_xp_events(user_id,source,xp,event_key)
      values(v_uid,'custom_week',v_c.weekly_bonus_xp,'custom_week:'||p_challenge_id::text||':'||v_week::text)
      on conflict(user_id,event_key) do nothing;
      v_xp:=v_xp+v_c.weekly_bonus_xp;
    end if;
  end if;

  return jsonb_build_object(
    'value',v_after,
    'completed_today',v_now_completed,
    'week_completed_days',v_completed_days,
    'weekly_target_days',v_c.weekly_target_days,
    'xp_awarded',v_xp
  );
end;
$function$
;

create function public.gti_missions_submit_water(p_amount_ml integer, p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$ declare r jsonb; begin perform gti_private.require_season();
if p_request_id is null then raise exception 'Request ID required'; end if;
if exists(select 1 from gti_private.submissions where user_id=auth.uid() and request_id=p_request_id and payload<>jsonb_build_array('water',p_amount_ml)) then raise exception 'Request ID reused with different payload';end if;
select result into r from gti_private.submissions where user_id=auth.uid() and request_id=p_request_id; if FOUND then return r; end if;
r:=gti_private.log_water(p_amount_ml);
r:=r||jsonb_build_object('unlocked_badges',gti_private.evaluate_badges('aqua'));
insert into gti_private.submissions(user_id,request_id,payload,result) values(auth.uid(),p_request_id,jsonb_build_array('water',p_amount_ml),r);
 return r; end $$;

create function public.gti_missions_submit_exercise(p_exercise_name text, p_duration_minutes integer) returns jsonb language plpgsql security definer set search_path='' as $$ declare r jsonb; begin perform gti_private.require_season();
r:=gti_private.log_exercise(p_exercise_name,p_duration_minutes);
r:=r||jsonb_build_object('unlocked_badges',gti_private.evaluate_badges('tech'));
 return r; end $$;

create function public.gti_missions_submit_custom(p_challenge_id uuid, p_value numeric, p_note text, p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$ declare r jsonb; begin perform gti_private.require_season();
if p_request_id is null then raise exception 'Request ID required'; end if;
if exists(select 1 from gti_private.submissions where user_id=auth.uid() and request_id=p_request_id and payload<>jsonb_build_array('custom',p_challenge_id,p_value,p_note)) then raise exception 'Request ID reused with different payload';end if;
select result into r from gti_private.submissions where user_id=auth.uid() and request_id=p_request_id; if FOUND then return r; end if;
r:=gti_private.log_custom(p_challenge_id,p_value,p_note);
insert into gti_private.submissions(user_id,request_id,payload,result) values(auth.uid(),p_request_id,jsonb_build_array('custom',p_challenge_id,p_value,p_note),r);
 return r; end $$;

create or replace function public.gti_missions_log_water(p_amount_ml integer) returns jsonb language sql security invoker set search_path='' as $$ select public.gti_missions_submit_water(p_amount_ml,gen_random_uuid()) $$;

create or replace function public.gti_missions_log_water(p_amount_ml integer,p_photo_path text) returns jsonb language sql security invoker set search_path='' as $$ select public.gti_missions_submit_water(p_amount_ml,gen_random_uuid()) $$;

create or replace function public.gti_missions_log_exercise(p_exercise_name text,p_duration_minutes integer) returns jsonb language sql security invoker set search_path='' as $$ select public.gti_missions_submit_exercise(p_exercise_name,p_duration_minutes) $$;

create or replace function public.gti_missions_log_exercise(p_exercise_name text,p_duration_minutes integer,p_photo_path text) returns jsonb language sql security invoker set search_path='' as $$ select public.gti_missions_submit_exercise(p_exercise_name,p_duration_minutes) $$;

create or replace function public.gti_missions_log_custom_challenge(p_challenge_id uuid,p_value numeric default 1,p_note text default null,p_photo_path text default null) returns jsonb language sql security invoker set search_path='' as $$ select public.gti_missions_submit_custom(p_challenge_id,p_value,p_note,gen_random_uuid()) $$;

CREATE OR REPLACE FUNCTION public.gti_missions_admin_create_challenge(p_title text, p_description text, p_icon text, p_mode text, p_unit_label text, p_daily_target numeric, p_weekly_target_days integer, p_xp_per_day integer, p_weekly_bonus_xp integer, p_starts_on date, p_ends_on date, p_requires_photo boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_id uuid:=gen_random_uuid();
  v_slug text;
  v_start date:=coalesce(p_starts_on,(now() at time zone 'America/Sao_Paulo')::date);
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
  insert into public.gti_missions_challenges(
    id,slug,title,description,icon,mode,unit_label,daily_target,weekly_target_days,
    xp_per_day,weekly_bonus_xp,starts_on,ends_on,created_by,requires_photo
  ) values(
    v_id,v_slug,trim(p_title),trim(coalesce(p_description,'')),left(coalesce(nullif(trim(p_icon),''),'🎯'),16),p_mode,
    case when p_mode='checkin' then 'check-in' else left(coalesce(nullif(trim(p_unit_label),''),'unidades'),30) end,
    case when p_mode='checkin' then null else p_daily_target end,
    p_weekly_target_days,p_xp_per_day,p_weekly_bonus_xp,v_start,p_ends_on,v_uid,false
  );
  return v_id;
end;
$function$
;
update public.gti_missions_challenges set requires_photo=false;

CREATE OR REPLACE FUNCTION public.gti_missions_challenge_leaderboard(p_challenge text DEFAULT 'global'::text, p_period text DEFAULT 'month'::text)
 RETURNS TABLE(user_id uuid, display_name text, username text, avatar_path text, xp bigint, score numeric, unit text, participating_challenges bigint, rank bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.2' and p.profile_visibility='community'
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
    where p.accepted_terms_at is not null and p.terms_version='1.2' and p.profile_visibility='community' and (v_challenge='global' or p.show_progress)
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
$function$
;

CREATE OR REPLACE FUNCTION public.gti_missions_leaderboard()
 RETURNS TABLE(user_id uuid, display_name text, username text, avatar_path text, xp bigint, rank bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with monthly as (
    select x.user_id,sum(x.xp)::bigint as xp from public.gti_missions_xp_events x
    where (x.created_at at time zone 'America/Sao_Paulo')>=date_trunc('month',now() at time zone 'America/Sao_Paulo') group by x.user_id
  ), ranked as (
    select p.user_id,p.display_name,p.username,p.avatar_path,m.xp,row_number() over(order by m.xp desc,lower(p.username) asc)::bigint as rank
    from monthly m join public.gti_missions_profiles p on p.user_id=m.user_id
    where m.xp>0 and p.accepted_terms_at is not null and p.terms_version='1.2' and p.profile_visibility='community'
  )
  select r.user_id,r.display_name,r.username,r.avatar_path,r.xp,r.rank from ranked r
  where auth.uid() is not null and coalesce((auth.jwt()->>'is_anonymous')::boolean,true) is false
    and exists(select 1 from public.gti_missions_profiles me where me.user_id=auth.uid() and me.accepted_terms_at is not null and me.terms_version='1.2')
  order by r.rank limit 100;
$function$
;
create function public.gti_missions_member(p_username text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p public.gti_missions_profiles; result jsonb; v_xp bigint; streak int; anchor date;
begin
 if not public.gti_missions_is_permanent_user() then raise exception 'Permanent account required'; end if;
 select * into p from public.gti_missions_profiles where username=p_username;
 if not found or not public.gti_missions_can_view(p.user_id) then return null; end if;
 select coalesce(sum(x.xp),0) into v_xp from public.gti_missions_xp_events x where x.user_id=p.user_id;
 anchor:=(now() at time zone 'America/Sao_Paulo')::date;
 if not exists(select 1 from public.gti_missions_xp_events where user_id=p.user_id and (created_at at time zone 'America/Sao_Paulo')::date=anchor and xp>0) then anchor:=anchor-1; end if;
 with days as(select distinct (created_at at time zone 'America/Sao_Paulo')::date d from public.gti_missions_xp_events where user_id=p.user_id and xp>0), numbered as(select d,row_number() over(order by d desc) n from days where d<=anchor)
 select count(*) into streak from numbered where d=anchor-(n-1)::int;
 result:=jsonb_build_object('display_name',p.display_name,'username',p.username,'avatar_path',p.avatar_path,'tagline',p.tagline,'total_xp',v_xp,'level',floor(v_xp/500)+1,'show_progress',p.show_progress,'show_badges',p.show_badges,'show_notes',p.show_notes,'show_history',p.show_history);
 if public.gti_missions_can_view(p.user_id,'progress') then
 result:=result||jsonb_build_object('streak',streak,'challenges',jsonb_build_array(jsonb_build_object('name','AquaXP','days',(select count(*) from public.gti_missions_water_days where user_id=p.user_id and goal_completed_at is not null and day>=date_trunc('month',now() at time zone 'America/Sao_Paulo')::date)),jsonb_build_object('name','Tech Ret','days',(select count(*) from public.gti_missions_exercise_days where user_id=p.user_id and total_minutes>=5 and day>=date_trunc('month',now() at time zone 'America/Sao_Paulo')::date))));
 end if;
 if public.gti_missions_can_view(p.user_id,'badges') then
 result:=result||jsonb_build_object('badges',(select coalesce(jsonb_agg(x),'[]') from (select b.name,b.icon,u.unlocked_at from public.gti_missions_user_badges u join public.gti_missions_badge_definitions b on b.id=u.badge_id where u.user_id=p.user_id order by u.unlocked_at desc limit 6)x));
 end if;
 if public.gti_missions_can_view(p.user_id,'notes') then
 result:=result||jsonb_build_object('notes',(select coalesce(jsonb_agg(x),'[]') from (select id,title,content,created_at from public.gti_missions_notes where user_id=p.user_id and visibility='public' order by created_at desc,id desc limit 3)x));
 end if; return result;
end $$;
create function public.gti_missions_members(p_search text default '',p_after text default '',p_limit int default 20) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(x),'[]') from (
 select p.display_name,p.username from public.gti_missions_profiles p
 where public.gti_missions_is_permanent_user() and p.profile_visibility='community' and p.accepted_terms_at is not null and p.username>coalesce(p_after,'')
 and (coalesce(p_search,'')='' or p.display_name ilike '%'||left(p_search,60)||'%')
 order by p.username limit greatest(1,least(coalesce(p_limit,20),30)))x
$$;
create function public.gti_missions_history(p_before date default null,p_username text default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare uid uuid; result jsonb;
begin
 if p_username is null then uid:=auth.uid(); else select user_id into uid from public.gti_missions_profiles where username=p_username; end if;
 if not public.gti_missions_can_view(uid,'history') then return '[]'; end if;
 select coalesce(jsonb_agg(x order by x.start_date desc),'[]') into result from (
 select s.id,s.name,s.start_date,s.end_date,case when s.end_date<(now() at time zone 'America/Sao_Paulo')::date then 'completed' when s.start_date>(now() at time zone 'America/Sao_Paulo')::date then 'upcoming' else 'active' end status,
 (select coalesce(sum(e.xp),0) from public.gti_missions_xp_events e where e.user_id=uid and e.created_at>=s.start_date::timestamp at time zone 'America/Sao_Paulo' and e.created_at<(s.end_date+1)::timestamp at time zone 'America/Sao_Paulo') xp,
 (select count(*) from public.gti_missions_water_days where user_id=uid and day between s.start_date and s.end_date and goal_completed_at is not null) water_days,
 (select count(*) from public.gti_missions_exercise_days where user_id=uid and day between s.start_date and s.end_date and total_minutes>=5) workout_days
 from public.gti_missions_season_members m join public.gti_missions_seasons s on s.id=m.season_id
 where m.user_id=uid and (p_before is null or s.start_date<p_before) order by s.start_date desc limit 12)x;
 return result;
end $$;
-- Compact monthly ranking; no per-entry profile or avatar fetches.
create function public.gti_missions_ranking(p_offset int default 0,p_limit int default 20) returns jsonb language sql stable security definer set search_path='' as $$
 with totals as(select user_id,sum(xp)::bigint xp from public.gti_missions_xp_events where created_at>=date_trunc('month',now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo' group by user_id),
 ranked as(select p.username,p.display_name,t.xp,row_number() over(order by t.xp desc,p.username) rank from totals t join public.gti_missions_profiles p using(user_id) where p.profile_visibility='community' and t.xp>0)
 select case when public.gti_missions_is_permanent_user() then coalesce((select jsonb_agg(x) from (select * from ranked order by rank limit greatest(1,least(coalesce(p_limit,20),30)) offset greatest(0,least(coalesce(p_offset,0),10000))) x),'[]') else '[]' end
$$;
-- Close mission evidence uploads while the existing cleanup job drains already-uploaded files.
drop policy if exists "GTI Missions users can upload checkin proof" on storage.objects;
-- Avatar visibility now follows profile privacy; owning account retains access.
create or replace function public.gti_missions_can_view_avatar(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.gti_missions_profiles p where p.avatar_path=p_path and public.gti_missions_can_view(p.user_id))
$$;
drop policy if exists "GTI Missions players can view avatars" on storage.objects;
create policy "GTI Missions players can view avatars" on storage.objects for select to authenticated using(bucket_id='gti-missions-avatars' and public.gti_missions_is_permanent_user() and ((storage.foldername(name))[1]=auth.uid()::text or public.gti_missions_can_view_avatar(name)));
-- Privileged helpers are callable only through explicitly granted, authenticated RPCs.
revoke all on all functions in schema gti_private from public,anon,authenticated;
revoke all on all tables in schema gti_private from public,anon,authenticated;
do $$ declare f record; begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on p.pronamespace=n.oid where n.nspname='public' and p.proname in ('gti_missions_admin_season','gti_missions_can_view','gti_missions_collection','gti_missions_current_season','gti_missions_history','gti_missions_join_season','gti_missions_member','gti_missions_members','gti_missions_public_notes','gti_missions_ranking','gti_missions_ranking_page','gti_missions_submit_custom','gti_missions_submit_exercise','gti_missions_submit_water') loop
 execute format('revoke all on function %s from public,anon',f.signature);
 execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end $$;

CREATE OR REPLACE FUNCTION gti_private.my_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_today date:=(now() at time zone 'America/Sao_Paulo')::date;
  v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_target integer:=2000;
  v_today_ml integer:=0;
  v_water_streak integer:=0;
  v_activity_streak integer:=0;
  v_water_week_days integer:=0;
  v_exercise_days integer:=0;
  v_exercise_target integer:=3;
  v_total_xp bigint:=0;
  v_monthly_xp bigint:=0;
  v_badges integer:=0;
  v_custom_badges integer:=0;
  v_water_anchor date;
  v_activity_anchor date;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    raise exception 'Permanent account required';
  end if;

  select water_target_ml,exercise_weekly_target
  into v_target,v_exercise_target
  from public.gti_missions_profiles
  where user_id=v_uid and accepted_terms_at is not null and terms_version='1.2';

  if not found then raise exception 'Current terms must be accepted'; end if;

  select coalesce(total_ml,0),target_ml
  into v_today_ml,v_target
  from public.gti_missions_water_days
  where user_id=v_uid and day=v_today;

  if not found then
    select water_target_ml into v_target
    from public.gti_missions_profiles
    where user_id=v_uid;
    v_today_ml:=0;
  end if;

  v_water_anchor:=case when exists(
    select 1 from public.gti_missions_water_days
    where user_id=v_uid and day=v_today and goal_completed_at is not null
  ) then v_today else v_today-1 end;

  with completed as (
    select day,row_number() over(order by day desc) as rn
    from public.gti_missions_water_days
    where user_id=v_uid and goal_completed_at is not null and day<=v_water_anchor
  )
  select count(*) into v_water_streak
  from completed
  where day=v_water_anchor-((rn-1)::integer);

  v_activity_anchor:=case when exists(
    select 1 from public.gti_missions_xp_events
    where user_id=v_uid and xp>0
      and (created_at at time zone 'America/Sao_Paulo')::date=v_today
  ) then v_today else v_today-1 end;

  with active_days as (
    select distinct (created_at at time zone 'America/Sao_Paulo')::date as day
    from public.gti_missions_xp_events
    where user_id=v_uid and xp>0
      and (created_at at time zone 'America/Sao_Paulo')::date<=v_activity_anchor
  ), numbered as (
    select day,row_number() over(order by day desc) as rn
    from active_days
  )
  select count(*) into v_activity_streak
  from numbered
  where day=v_activity_anchor-((rn-1)::integer);

  select count(*) into v_water_week_days
  from public.gti_missions_water_days
  where user_id=v_uid and day between v_week and v_week+6
    and goal_completed_at is not null;

  select target_days into v_exercise_target
  from public.gti_missions_exercise_weeks
  where user_id=v_uid and week_start=v_week;

  if not found then
    select exercise_weekly_target into v_exercise_target
    from public.gti_missions_profiles
    where user_id=v_uid;
  end if;

  v_exercise_target:=greatest(3,least(7,coalesce(v_exercise_target,3)));

  select count(distinct(logged_at at time zone 'America/Sao_Paulo')::date)
  into v_exercise_days
  from public.gti_missions_exercise_entries
  where user_id=v_uid and duration_minutes>=5
    and (logged_at at time zone 'America/Sao_Paulo')::date between v_week and v_week+6;

  select coalesce(sum(xp),0) into v_total_xp
  from public.gti_missions_xp_events
  where user_id=v_uid;

  select coalesce(sum(xp),0) into v_monthly_xp
  from public.gti_missions_xp_events
  where user_id=v_uid
    and (created_at at time zone 'America/Sao_Paulo')>=date_trunc('month',now() at time zone 'America/Sao_Paulo');

  select count(*) into v_badges
  from public.gti_missions_weekly_badges
  where user_id=v_uid;

  select count(*) into v_custom_badges
  from public.gti_missions_challenge_badges
  where user_id=v_uid;

  return jsonb_build_object(
    'water_today_ml',coalesce(v_today_ml,0),
    'water_target_ml',coalesce(v_target,2000),
    'water_streak',coalesce(v_water_streak,0),
    'activity_streak',coalesce(v_activity_streak,0),
    'water_week_days',coalesce(v_water_week_days,0),
    'water_week_target',7,
    'exercise_week_days',coalesce(v_exercise_days,0),
    'exercise_week_target',v_exercise_target,
    'total_xp',coalesce(v_total_xp,0),
    'monthly_xp',coalesce(v_monthly_xp,0),
    'badges',coalesce(v_badges,0)+coalesce(v_custom_badges,0)+(select count(*) from public.gti_missions_user_badges where user_id=v_uid),
    'monthly_rank',(select r.rank from (select p.user_id,row_number() over(order by sum(x.xp) desc,p.username) rank from public.gti_missions_xp_events x join public.gti_missions_profiles p using(user_id) where p.profile_visibility='community' and x.created_at>=date_trunc('month',now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo' group by p.user_id,p.username)r where r.user_id=v_uid),
    'exercise_today_completed',exists(select 1 from public.gti_missions_exercise_days where user_id=v_uid and day=v_today and total_minutes>=5),
    'next_badge',(select b.name from public.gti_missions_badge_definitions b where not b.is_secret and not exists(select 1 from public.gti_missions_user_badges u where u.user_id=v_uid and u.badge_id=b.id) order by b.sort_order,b.id limit 1)
  );
end;
$function$
;
create or replace function public.gti_missions_my_stats() returns jsonb language plpgsql security definer set search_path='' as $$ begin if not public.gti_missions_is_permanent_user() then raise exception 'Permanent account required'; end if; return gti_private.my_stats(); end $$;
revoke all on function gti_private.my_stats() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION gti_private.challenge_ranking(p_challenge text DEFAULT 'global'::text, p_period text DEFAULT 'month'::text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 20)
 RETURNS TABLE(user_id uuid, display_name text, username text, avatar_path text, xp bigint, score numeric, unit text, participating_challenges bigint, rank bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    where p.user_id=v_uid and p.accepted_terms_at is not null and p.terms_version='1.2' and p.profile_visibility='community' and (v_challenge='global' or p.show_progress)
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
    where p.accepted_terms_at is not null and p.terms_version='1.2' and p.profile_visibility='community' and (v_challenge='global' or p.show_progress)
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
  limit greatest(1,least(coalesce(p_limit,20),30)) offset greatest(0,least(coalesce(p_offset,0),10000));
end;
$function$
;

create function public.gti_missions_ranking_page(p_challenge text default 'global',p_period text default 'month',p_offset integer default 0) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('username',r.username,'display_name',r.display_name,'avatar_path',r.avatar_path,'xp',r.xp,'score',r.score,'unit',r.unit,'participating_challenges',r.participating_challenges,'rank',r.rank)),'[]') from gti_private.challenge_ranking(p_challenge,p_period,p_offset,20) r
$$;
revoke all on function gti_private.challenge_ranking(text,text,integer,integer) from public,anon,authenticated;
revoke all on function public.gti_missions_ranking_page(text,text,integer) from public,anon;
grant execute on function public.gti_missions_ranking_page(text,text,integer) to authenticated;

insert into public.gti_missions_user_badges(user_id,badge_id,season_id,unlocked_at)
select p.user_id,b.id,
 case when b.rule_type in ('season','perfect') then earned.id else null end,
 case when earned.end_date<(now() at time zone 'America/Sao_Paulo')::date then (earned.end_date::timestamp at time zone 'America/Sao_Paulo') else now() end
from public.gti_missions_profiles p cross join public.gti_missions_badge_definitions b
cross join lateral (select gti_private.badge_metrics(p.user_id,b.challenge_type,(now() at time zone 'America/Sao_Paulo')::date) m) metrics
left join lateral (
 select s.id,s.end_date from public.gti_missions_seasons s where s.start_date<=(now() at time zone 'America/Sao_Paulo')::date and (
 select count(*) from (
 select day from public.gti_missions_water_days where b.challenge_type='aqua' and user_id=p.user_id and goal_completed_at is not null and day between s.start_date and s.end_date
 union select day from public.gti_missions_exercise_days where b.challenge_type='tech' and user_id=p.user_id and total_minutes>=5 and day between s.start_date and s.end_date
 ) d)>=case when b.rule_type='perfect' then s.end_date-s.start_date+1 else b.rule_value end order by s.start_date limit 1
) earned on b.rule_type in ('season','perfect')
where (metrics.m->>b.rule_type)::int>=b.rule_value
on conflict do nothing;

create function public.gti_missions_public_notes(p_username text,p_before timestamptz default null,p_before_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare uid uuid; result jsonb;
begin
 select user_id into uid from public.gti_missions_profiles where username=p_username;
 if not public.gti_missions_can_view(uid,'notes') then return '[]'; end if;
 select coalesce(jsonb_agg(x),'[]') into result from (select id,title,content,created_at from public.gti_missions_notes where user_id=uid and visibility='public' and (p_before is null or (created_at,id)<(p_before,p_before_id)) order by created_at desc,id desc limit 10)x;return result;
end $$;
revoke all on function public.gti_missions_public_notes(text,timestamptz,uuid) from public,anon;
grant execute on function public.gti_missions_public_notes(text,timestamptz,uuid) to authenticated;

CREATE OR REPLACE FUNCTION public.gti_missions_custom_challenge_statuses()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
with ctx as (
  select auth.uid() uid,(now() at time zone 'America/Sao_Paulo')::date today,date_trunc('week',now() at time zone 'America/Sao_Paulo')::date week_start
), valid as (
  select c.* from public.gti_missions_challenges c,ctx
  where c.is_active and c.starts_on<=ctx.today and (c.ends_on is null or c.ends_on>=ctx.today)
), data as (
  select c.id,c.slug,c.title,c.description,c.icon,c.mode,c.unit_label,c.daily_target,c.weekly_target_days,
    c.xp_per_day,c.weekly_bonus_xp,c.starts_on,c.ends_on,c.created_at,
    exists(select 1 from public.gti_missions_challenge_participants p,ctx where p.challenge_id=c.id and p.user_id=ctx.uid) as joined,
    coalesce((select e.value from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day=ctx.today),0) as today_value,
    exists(select 1 from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day=ctx.today and e.completed_at is not null) as today_completed,
    (select count(*) from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day between ctx.week_start and ctx.week_start+6 and e.completed_at is not null) as week_completed_days
  from valid c
)
select case
  when auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then '[]'::jsonb
  when not exists(select 1 from public.gti_missions_profiles p where p.user_id=auth.uid() and p.accepted_terms_at is not null and p.terms_version='1.2') then '[]'::jsonb
  else coalesce(jsonb_agg(to_jsonb(data) order by data.created_at),'[]'::jsonb)
end
from data;
$function$
;

drop function public.gti_missions_admin_create_challenge(text,text,text,text,text,numeric,integer,integer,integer,date,date,boolean);
CREATE OR REPLACE FUNCTION public.gti_missions_admin_create_challenge(p_title text, p_description text, p_icon text, p_mode text, p_unit_label text, p_daily_target numeric, p_weekly_target_days integer, p_xp_per_day integer, p_weekly_bonus_xp integer, p_starts_on date, p_ends_on date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_id uuid:=gen_random_uuid();
  v_slug text;
  v_start date:=coalesce(p_starts_on,(now() at time zone 'America/Sao_Paulo')::date);
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
  insert into public.gti_missions_challenges(
    id,slug,title,description,icon,mode,unit_label,daily_target,weekly_target_days,
    xp_per_day,weekly_bonus_xp,starts_on,ends_on,created_by
  ) values(
    v_id,v_slug,trim(p_title),trim(coalesce(p_description,'')),left(coalesce(nullif(trim(p_icon),''),'🎯'),16),p_mode,
    case when p_mode='checkin' then 'check-in' else left(coalesce(nullif(trim(p_unit_label),''),'unidades'),30) end,
    case when p_mode='checkin' then null else p_daily_target end,
    p_weekly_target_days,p_xp_per_day,p_weekly_bonus_xp,v_start,p_ends_on,v_uid
  );
  return v_id;
end;
$function$
;

-- Bucket was verified empty before this migration; abort cleanup if a late legacy upload exists.
do $$ begin if exists(select 1 from storage.objects where bucket_id='gti-missions-checkins') then raise exception 'Evidence bucket must be drained through Storage API before cleanup'; end if; end $$;
select cron.unschedule(jobid) from cron.job where jobname='gti-missions-cleanup-checkins-hourly';
drop function if exists public.gti_missions_admin_recent_proofs();
drop policy if exists "GTI Missions users and admins can view checkin proof" on storage.objects;
drop policy if exists "GTI Missions users can delete unlinked checkin proof" on storage.objects;
alter table public.gti_missions_water_entries drop column photo_path, drop column photo_expires_at;
alter table public.gti_missions_exercise_entries drop column photo_path, drop column photo_expires_at;
alter table public.gti_missions_challenge_entries drop column photo_path, drop column photo_expires_at;
alter table public.gti_missions_challenges drop column requires_photo;
drop table if exists public.gti_missions_cleanup_state;
revoke all on function public.gti_missions_admin_create_challenge(text,text,text,text,text,numeric,integer,integer,integer,date,date) from public,anon;
grant execute on function public.gti_missions_admin_create_challenge(text,text,text,text,text,numeric,integer,integer,integer,date,date) to authenticated;
