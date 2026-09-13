create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.unschedule(jobid) from cron.job where jobname='gti-missions-cleanup-checkins-hourly';
select cron.schedule(
  'gti-missions-cleanup-checkins-hourly',
  '17 * * * *',
  $$
    select net.http_post(
      url:='https://nfuzjklrluhninqybfhx.supabase.co/functions/v1/cleanup-gti-missions-checkins',
      headers:='{"Content-Type":"application/json"}'::jsonb,
      body:='{"source":"pg_cron"}'::jsonb,
      timeout_milliseconds:=5000
    );
  $$
);
