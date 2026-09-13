-- Run inside BEGIN/ROLLBACK; identities are synthetic and never committed.
insert into auth.users(id,aud,role,is_anonymous) values('00000000-0000-4000-a000-000000000001','authenticated','authenticated',false),('00000000-0000-4000-a000-000000000002','authenticated','authenticated',false);
insert into public.gti_missions_profiles(user_id,display_name,username,water_target_ml,accepted_terms_at,terms_version) values('00000000-0000-4000-a000-000000000001','Test One','gti_test_one',1000,now(),'1.2'),('00000000-0000-4000-a000-000000000002','Test Two','gti_test_two',1000,now(),'1.2');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated","is_anonymous":false}',true);
do $$ declare r jsonb; n int; cid uuid; begin
 r:=public.gti_missions_current_season();
 if r->>'status'<>'active' then raise exception 'Season detection failed'; end if;
 r:=public.gti_missions_submit_water(500,'00000000-0000-4000-a000-000000000011');
 r:=public.gti_missions_submit_water(500,'00000000-0000-4000-a000-000000000011');
 if (r->>'today_ml')::int<>500 then raise exception 'Water replay duplicated'; end if;
 r:=public.gti_missions_submit_water(500,'00000000-0000-4000-a000-000000000012');
 if not (r->>'goal_met')::boolean or (r->>'xp_awarded')::int<>55 then raise exception 'Goal/XP failed: %',r; end if;
 if jsonb_array_length(r->'unlocked_badges')<>1 then raise exception 'Badge unlock failed'; end if;
 r:=public.gti_missions_submit_water(100,'00000000-0000-4000-a000-000000000013');
 if jsonb_array_length(r->'unlocked_badges')<>0 then raise exception 'Duplicate badge'; end if;
 r:=public.gti_missions_submit_exercise('Academia',30);
 if (r->>'xp_awarded')::int<>30 then raise exception 'Workout XP failed'; end if;
 r:=public.gti_missions_submit_exercise('Academia',30);
 if not (r->>'already_completed')::boolean then raise exception 'Workout duplicate'; end if;
 r:=public.gti_missions_my_stats();
 if (r->>'activity_streak')::int<>1 or (r->>'exercise_week_days')::int<>1 then raise exception 'Counters failed: %',r; end if;
 select id into cid from public.gti_missions_challenges where slug='reading';
 perform public.gti_missions_join_challenge(cid);
 r:=public.gti_missions_submit_custom(cid,20,'Livro','00000000-0000-4000-a000-000000000014');
 if not (r->>'completed_today')::boolean or (r->>'xp_awarded')::int=0 then raise exception 'Reading regression: %',r; end if;
 if not exists(select 1 from public.gti_missions_challenge_entries where challenge_id=cid and user_id=auth.uid() and value=20) then raise exception 'Reading not persisted'; end if;
 r:=public.gti_missions_submit_custom(cid,20,'Livro','00000000-0000-4000-a000-000000000014');
 if not exists(select 1 from public.gti_missions_challenge_entries where challenge_id=cid and user_id=auth.uid() and value=20) then raise exception 'Reading replay'; end if;
 if jsonb_array_length(public.gti_missions_collection('aqua'))<>30 then raise exception 'Water collection size'; end if;
 if jsonb_array_length(public.gti_missions_collection('tech'))<>30 then raise exception 'Tech collection size'; end if;
 if exists(select 1 from jsonb_array_elements(public.gti_missions_collection('aqua')) x where x->>'state'='secret' and x->>'name'<>'Emblema secreto') then raise exception 'Secret leaked'; end if;
 begin insert into public.gti_missions_xp_events(user_id,source,xp,event_key) values(auth.uid(),'water_goal',250,'cheat');raise exception 'XP write allowed'; exception when insufficient_privilege then null; end;
 begin insert into public.gti_missions_user_badges(user_id,badge_id) values(auth.uid(),'aqua-days-100');raise exception 'Badge write allowed'; exception when insufficient_privilege then null; end;
 begin perform public.gti_missions_admin_season(current_date,'hacker');raise exception 'Non-admin allowed'; exception when raise_exception then if sqlerrm='Non-admin allowed' then raise; end if; end;
end $$;
insert into public.gti_missions_notes(title,content,visibility) values('Private','DO NOT EXPOSE','private'),('Public','Shared note','public');
update public.gti_missions_notes set content='EDITED PRIVATE' where title='Private';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated","is_anonymous":false}',true);
do $$ declare n int; r jsonb; begin
 select count(*) into n from public.gti_missions_notes;
 if n<>1 then raise exception 'Private notes leaked: %',n; end if;
 update public.gti_missions_notes set content='stolen'; get diagnostics n=row_count; if n<>0 then raise exception 'Foreign update allowed'; end if;
 delete from public.gti_missions_notes; get diagnostics n=row_count; if n<>0 then raise exception 'Foreign delete allowed'; end if;
 r:=public.gti_missions_member('gti_test_one');
 if r::text like '%EDITED PRIVATE%' or r ? 'user_id' or r ? 'email' then raise exception 'Profile leak'; end if;
end $$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated","is_anonymous":false}',true);
update public.gti_missions_profiles set profile_visibility='private' where user_id=auth.uid();
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated","is_anonymous":false}',true);
do $$ begin
 if public.gti_missions_member('gti_test_one') is not null then raise exception 'Private profile exposed'; end if;
 if exists(select 1 from public.gti_missions_notes) then raise exception 'Private profile notes exposed'; end if;
 if jsonb_array_length(public.gti_missions_collection('aqua','gti_test_one'))<>0 then raise exception 'Private badges exposed'; end if;
end $$;
reset role;
select 'PASS: water, exercise, reading, XP, badges, notes CRUD isolation, profile privacy' as result;
-- Calendar boundaries, preserved history, access-code enforcement and privacy toggles.
reset role;
do $$ declare a uuid; b uuid; begin
 a:=gti_private.ensure_season('2028-02-15');b:=gti_private.ensure_season('2028-03-01');
 if a=b or (select end_date from public.gti_missions_seasons where id=a)<>'2028-02-29' then raise exception 'Leap month boundary'; end if;
 if gti_private.ensure_season('2028-02-28')<>a then raise exception 'Season not idempotent'; end if;
end $$;
insert into public.gti_missions_xp_events(user_id,source,xp,event_key,created_at) values('00000000-0000-4000-a000-000000000001','water_goal',50,'historical-test',date_trunc('month',now())-interval '2 days');
insert into public.gti_missions_season_members(user_id,season_id) values('00000000-0000-4000-a000-000000000001',gti_private.ensure_season((date_trunc('month',now())-interval '2 days')::date)) on conflict do nothing;
insert into gti_private.season_codes(season_id,code_hash) values(gti_private.ensure_season((now() at time zone 'America/Sao_Paulo')::date),encode(extensions.digest('TEST-CODE-ONLY','sha256'),'hex')) on conflict(season_id) do update set code_hash=excluded.code_hash;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated","is_anonymous":false}',true);
do $$ begin
 begin perform public.gti_missions_submit_exercise('Academia',30);raise exception 'Code bypass'; exception when raise_exception then if sqlerrm<>'Season code required' then raise;end if;end;
 if public.gti_missions_join_season('wrong') then raise exception 'Wrong code accepted';end if;
 if not public.gti_missions_join_season('TEST-CODE-ONLY') then raise exception 'Correct code rejected';end if;
 perform public.gti_missions_submit_exercise('Academia',30);
end $$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000001","role":"authenticated","is_anonymous":false}',true);
update public.gti_missions_profiles set profile_visibility='community',show_progress=false,show_badges=false,show_notes=false where user_id=auth.uid();
do $$ declare r jsonb; begin
 r:=public.gti_missions_my_stats();if (r->>'total_xp')::int-(r->>'monthly_xp')::int<>50 then raise exception 'Historical XP reset';end if;
 if jsonb_array_length(public.gti_missions_history())<>2 then raise exception 'History lost';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-a000-000000000002","role":"authenticated","is_anonymous":false}',true);
do $$ declare r jsonb; begin
 r:=public.gti_missions_member('gti_test_one');if r ? 'challenges' or r ? 'badges' or r ? 'notes' then raise exception 'Section privacy bypass';end if;
 if exists(select 1 from jsonb_array_elements(public.gti_missions_ranking_page('aqua','month',0))x where x->>'username'='gti_test_one') then raise exception 'Ranking exposes hidden progress';end if;
 if exists(select 1 from jsonb_array_elements(public.gti_missions_ranking_page('global','month',0))x where x ? 'user_id') then raise exception 'Ranking leaks auth identifier';end if;
end $$;
reset role;
select 'PASS: calendar, season code, historical XP, section privacy, compact ranking' as result;
