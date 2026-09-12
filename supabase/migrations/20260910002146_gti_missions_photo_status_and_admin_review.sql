create or replace function public.gti_missions_custom_challenge_statuses() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
with ctx as (
  select auth.uid() uid,(now() at time zone 'America/Sao_Paulo')::date today,date_trunc('week',now() at time zone 'America/Sao_Paulo')::date week_start
), valid as (
  select c.* from public.gti_missions_challenges c,ctx
  where c.is_active and c.starts_on<=ctx.today and (c.ends_on is null or c.ends_on>=ctx.today)
), data as (
  select c.id,c.slug,c.title,c.description,c.icon,c.mode,c.unit_label,c.daily_target,c.weekly_target_days,
    c.xp_per_day,c.weekly_bonus_xp,c.starts_on,c.ends_on,c.created_at,c.requires_photo,
    exists(select 1 from public.gti_missions_challenge_participants p,ctx where p.challenge_id=c.id and p.user_id=ctx.uid) as joined,
    coalesce((select e.value from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day=ctx.today),0) as today_value,
    exists(select 1 from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day=ctx.today and e.completed_at is not null) as today_completed,
    (select count(*) from public.gti_missions_challenge_entries e,ctx where e.challenge_id=c.id and e.user_id=ctx.uid and e.entry_day between ctx.week_start and ctx.week_start+6 and e.completed_at is not null) as week_completed_days
  from valid c
)
select case
  when auth.uid() is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then '[]'::jsonb
  when not exists(select 1 from public.gti_missions_profiles p where p.user_id=auth.uid() and p.accepted_terms_at is not null and p.terms_version='1.1') then '[]'::jsonb
  else coalesce(jsonb_agg(to_jsonb(data) order by data.created_at),'[]'::jsonb)
end
from data;
$$;
revoke all on function public.gti_missions_custom_challenge_statuses() from public,anon;
grant execute on function public.gti_missions_custom_challenge_statuses() to authenticated;

create or replace function public.gti_missions_admin_recent_proofs() returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
select case
  when not public.gti_missions_is_admin() then '[]'::jsonb
  else coalesce(jsonb_agg(to_jsonb(x) order by x.completed_at desc),'[]'::jsonb)
end
from (
  select e.id,e.challenge_id,c.title as challenge_title,c.icon,e.user_id,p.display_name,p.username,
    e.entry_day,e.completed_at,e.photo_path,e.photo_expires_at
  from public.gti_missions_challenge_entries e
  join public.gti_missions_challenges c on c.id=e.challenge_id
  join public.gti_missions_profiles p on p.user_id=e.user_id
  where e.photo_path is not null and e.photo_expires_at>now()
  order by e.completed_at desc
  limit 100
) x;
$$;
revoke all on function public.gti_missions_admin_recent_proofs() from public,anon;
grant execute on function public.gti_missions_admin_recent_proofs() to authenticated;
