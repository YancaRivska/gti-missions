-- Preserve visibility rules; include genuinely joined active custom worlds.
create or replace function public.gti_missions_member(p_username text) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 result:=result||jsonb_build_object('streak',streak,'challenges',jsonb_build_array(jsonb_build_object('name','AquaXP League','days',(select count(*) from public.gti_missions_water_days where user_id=p.user_id and goal_completed_at is not null and day>=date_trunc('month',now() at time zone 'America/Sao_Paulo')::date)),jsonb_build_object('name','RAT Tech','days',(select count(*) from public.gti_missions_exercise_days where user_id=p.user_id and total_minutes>=5 and day>=date_trunc('month',now() at time zone 'America/Sao_Paulo')::date))));
 result:=jsonb_set(result,'{challenges}',(result->'challenges')||(
 select coalesce(jsonb_agg(jsonb_build_object('name',c.title,'days',(
 select count(*) from public.gti_missions_challenge_entries e
 where e.user_id=p.user_id and e.challenge_id=c.id and e.completed_at is not null
 and e.entry_day>=date_trunc('month',now() at time zone 'America/Sao_Paulo')::date
 )) order by c.created_at),'[]'::jsonb)
 from public.gti_missions_challenge_participants cp
 join public.gti_missions_challenges c on c.id=cp.challenge_id
 where cp.user_id=p.user_id and c.is_active
 and c.starts_on<=(now() at time zone 'America/Sao_Paulo')::date
 and (c.ends_on is null or c.ends_on>=(now() at time zone 'America/Sao_Paulo')::date)
 ));
 end if;
 if public.gti_missions_can_view(p.user_id,'badges') then
 result:=result||jsonb_build_object('badges',(select coalesce(jsonb_agg(x),'[]') from (select b.name,b.icon,u.unlocked_at from public.gti_missions_user_badges u join public.gti_missions_badge_definitions b on b.id=u.badge_id where u.user_id=p.user_id order by u.unlocked_at desc limit 6)x));
 end if;
 if public.gti_missions_can_view(p.user_id,'notes') then
 result:=result||jsonb_build_object('notes',(select coalesce(jsonb_agg(x),'[]') from (select id,title,content,created_at from public.gti_missions_notes where user_id=p.user_id and visibility='public' order by created_at desc,id desc limit 3)x));
 end if; return result;
end $$;
