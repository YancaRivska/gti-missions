drop function if exists public.gti_missions_admin_create_challenge(text,text,text,text,text,numeric,integer,integer,integer,date,date);
create function public.gti_missions_admin_create_challenge(
  p_title text,
  p_description text,
  p_icon text,
  p_mode text,
  p_unit_label text,
  p_daily_target numeric,
  p_weekly_target_days integer,
  p_xp_per_day integer,
  p_weekly_bonus_xp integer,
  p_starts_on date,
  p_ends_on date,
  p_requires_photo boolean default false
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
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
    p_weekly_target_days,p_xp_per_day,p_weekly_bonus_xp,v_start,p_ends_on,v_uid,coalesce(p_requires_photo,false)
  );
  return v_id;
end;
$$;
revoke all on function public.gti_missions_admin_create_challenge(text,text,text,text,text,numeric,integer,integer,integer,date,date,boolean) from public,anon;
grant execute on function public.gti_missions_admin_create_challenge(text,text,text,text,text,numeric,integer,integer,integer,date,date,boolean) to authenticated;
