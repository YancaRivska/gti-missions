create or replace function public.gti_missions_log_custom_challenge(p_challenge_id uuid,p_value numeric default 1,p_note text default null) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_uid uuid:=auth.uid(); v_today date:=(now() at time zone 'America/Sao_Paulo')::date; v_week date:=date_trunc('week',now() at time zone 'America/Sao_Paulo')::date;
  v_c public.gti_missions_challenges%rowtype; v_before numeric:=0; v_after numeric:=0; v_was_completed boolean:=false; v_now_completed boolean:=false;
  v_xp integer:=0; v_xp_id uuid; v_completed_days integer:=0; v_badge_id uuid; v_entry_cap numeric;
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
    v_entry_cap:=least(greatest(v_c.daily_target*10,10),100000);
    if p_value>v_entry_cap then raise exception 'Value too high'; end if;
    v_after:=v_before+p_value;
    if v_after>least(greatest(v_c.daily_target*20,v_c.daily_target),1000000) then raise exception 'Daily value limit reached'; end if;
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
revoke all on function public.gti_missions_log_custom_challenge(uuid,numeric,text) from public,anon;
grant execute on function public.gti_missions_log_custom_challenge(uuid,numeric,text) to authenticated;
