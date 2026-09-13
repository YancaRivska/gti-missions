begin;

drop policy if exists gti_missions_admins_select_self on public.gti_missions_admins;
create policy gti_missions_admins_select_self
on public.gti_missions_admins for select to authenticated
using (
  user_id=(select auth.uid())
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
);

drop policy if exists gti_missions_challenge_participants_select_own on public.gti_missions_challenge_participants;
create policy gti_missions_challenge_participants_select_own
on public.gti_missions_challenge_participants for select to authenticated
using (
  user_id=(select auth.uid())
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
);

drop policy if exists gti_missions_challenge_entries_select_own on public.gti_missions_challenge_entries;
create policy gti_missions_challenge_entries_select_own
on public.gti_missions_challenge_entries for select to authenticated
using (
  user_id=(select auth.uid())
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
);

drop policy if exists gti_missions_challenge_badges_select_own on public.gti_missions_challenge_badges;
create policy gti_missions_challenge_badges_select_own
on public.gti_missions_challenge_badges for select to authenticated
using (
  user_id=(select auth.uid())
  and coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
);

drop policy if exists gti_missions_challenges_select_players on public.gti_missions_challenges;
create policy gti_missions_challenges_select_players
on public.gti_missions_challenges for select to authenticated
using (
  coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true) is false
  and (
    exists(select 1 from public.gti_missions_admins a where a.user_id=(select auth.uid()))
    or (
      is_active
      and exists(
        select 1 from public.gti_missions_profiles p
        where p.user_id=(select auth.uid())
          and p.accepted_terms_at is not null
          and p.terms_version='1.2'
      )
    )
  )
);

commit;
