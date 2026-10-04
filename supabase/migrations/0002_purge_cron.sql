-- Optional: automatic purging of expired rooms.
--
-- Run this ONLY after 0001_rooms.sql succeeds. It needs the pg_cron extension,
-- which Supabase exposes on paid plans and some free projects, so it is kept
-- separate: if it fails, rooms still expire (viewers simply stop being able to
-- read them) and the app's END ROOM button still deletes its own row.
--
-- Dashboard -> SQL Editor -> New query, run once.

create extension if not exists pg_cron with schema extensions;

-- Remove expired rows every 10 minutes.
select cron.schedule(
  'cricscore-purge-rooms',
  '*/10 * * * *',
  $$delete from public.rooms where expires_at <= now()$$
);

-- Verify:  select cronjob, schedule, command from cron.job;