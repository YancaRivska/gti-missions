create or replace function public.gti_missions_is_permanent_user() returns boolean
language sql stable security invoker set search_path = public, pg_temp as $$
  select auth.uid() is not null and coalesce((auth.jwt()->>'is_anonymous')::boolean, true) is false;
$$;
revoke all on function public.gti_missions_is_permanent_user() from public, anon;
grant execute on function public.gti_missions_is_permanent_user() to authenticated;

drop policy if exists gti_missions_profiles_select_own on public.gti_missions_profiles;
create policy gti_missions_profiles_select_own on public.gti_missions_profiles for select to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
drop policy if exists gti_missions_profiles_insert_own on public.gti_missions_profiles;
create policy gti_missions_profiles_insert_own on public.gti_missions_profiles for insert to authenticated
with check ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
drop policy if exists gti_missions_profiles_update_own on public.gti_missions_profiles;
create policy gti_missions_profiles_update_own on public.gti_missions_profiles for update to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()))
with check ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));

drop policy if exists gti_missions_water_select_own on public.gti_missions_water_entries;
create policy gti_missions_water_select_own on public.gti_missions_water_entries for select to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
drop policy if exists gti_missions_exercise_select_own on public.gti_missions_exercise_entries;
create policy gti_missions_exercise_select_own on public.gti_missions_exercise_entries for select to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
drop policy if exists gti_missions_xp_select_own on public.gti_missions_xp_events;
create policy gti_missions_xp_select_own on public.gti_missions_xp_events for select to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
drop policy if exists gti_missions_badges_select_own on public.gti_missions_weekly_badges;
create policy gti_missions_badges_select_own on public.gti_missions_weekly_badges for select to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
drop policy if exists gti_missions_water_days_select_own on public.gti_missions_water_days;
create policy gti_missions_water_days_select_own on public.gti_missions_water_days for select to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
drop policy if exists gti_missions_exercise_weeks_select_own on public.gti_missions_exercise_weeks;
create policy gti_missions_exercise_weeks_select_own on public.gti_missions_exercise_weeks for select to authenticated
using ((select auth.uid()) = user_id and (select public.gti_missions_is_permanent_user()));
