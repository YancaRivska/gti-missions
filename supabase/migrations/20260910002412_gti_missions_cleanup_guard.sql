create table if not exists public.gti_missions_cleanup_state(
  singleton boolean primary key default true check(singleton),
  last_run_at timestamptz
);
alter table public.gti_missions_cleanup_state enable row level security;
revoke all on public.gti_missions_cleanup_state from anon,authenticated;
insert into public.gti_missions_cleanup_state(singleton,last_run_at) values(true,null) on conflict(singleton) do nothing;
