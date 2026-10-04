-- CricScore live rooms — 002: the write capability.
--
-- Applied to the live project via the Supabase MCP (migration
-- `room_secret_capability`).
--
-- Why a secret and not Supabase Auth: anonymous sign-ins are DISABLED by
-- default on a fresh project, so the auth route would have made the scorer
-- depend on a dashboard toggle nobody remembers. A room is already a
-- capability (its code), so writes use a second unguessable secret held only
-- by the scoring phone. Same security property — the database decides who may
-- write — with no auth provider, no auth.users rows and no token refresh in a
-- scoring app.
--
-- The secret table has RLS enabled and NO policies, and is revoked from
-- anon/authenticated, so no client role can read it. Verified: reading
-- room_secrets as the anon role returns 401 permission denied.

create table if not exists public.room_secrets (
  code   text primary key references public.rooms (code) on delete cascade,
  secret text not null
);

alter table public.room_secrets enable row level security;
revoke all on table public.room_secrets from anon, authenticated;

-- Opens a room. Returns false if the code was taken, so the client draws a new
-- one rather than silently adopting someone else's room.
create or replace function public.room_create(
  p_code      text,
  p_secret    text,
  p_ttl_hours integer default 12
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_created boolean;
begin
  if p_code !~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]{5}$' then
    raise exception 'bad room code';
  end if;
  if p_secret is null or length(p_secret) < 32 then
    raise exception 'weak room secret';
  end if;

  insert into public.rooms (code, seq, payload, expires_at)
  values (p_code, 0, '{"v":1}'::jsonb, now() + make_interval(hours => p_ttl_hours))
  on conflict (code) do nothing
  returning true into v_created;

  if v_created then
    insert into public.room_secrets (code, secret) values (p_code, p_secret);
    return true;
  end if;
  return false;
end;
$$;

-- Publishes a new state. The whole update is conditional on the publish being
-- NEWER than what is stored, so a replay or an out-of-order delivery is a
-- complete no-op. Returns false when the secret is wrong (a forged write is
-- rejected) or when the publish is stale.
--
-- The first draft used `seq = greatest(r.seq, p_seq)` with an unconditional
-- payload assignment. That protected the seq column but still overwrote the
-- payload, so a stale publish rewound the score while seq stayed high -- and a
-- viewer joining mid-match would read a seq-0 payload and render nothing.
-- Caught by an end-to-end test against the live project.
create or replace function public.room_publish(
  p_code    text,
  p_secret  text,
  p_seq     bigint,
  p_payload jsonb
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.rooms r
     set seq         = p_seq,
         payload     = p_payload,
         updated_at  = now(),
         expires_at  = now() + interval '12 hours'
   where r.code = p_code
     and p_seq > r.seq
     and exists (
       select 1 from public.room_secrets s
       where s.code = r.code and s.secret = p_secret
     );
  return found;
end;
$$;

-- Closes a room. Cascades to room_secrets.
create or replace function public.room_end(
  p_code   text,
  p_secret text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.rooms r
   where r.code = p_code
     and exists (
       select 1 from public.room_secrets s
       where s.code = r.code and s.secret = p_secret
     );
  return found;
end;
$$;

-- Postgres grants EXECUTE on a new function to PUBLIC by default, so every
-- role could call these. Revoke from PUBLIC first, then grant only to the two
-- roles the app actually uses. search_path is pinned to '' because every table
-- reference in these bodies is schema-qualified; pg_catalog is searched
-- regardless, so the builtins still resolve.
revoke execute on function public.room_create(text, text, integer) from public;
revoke execute on function public.room_publish(text, text, bigint, jsonb) from public;
revoke execute on function public.room_end(text, text) from public;

grant execute on function public.room_create(text, text, integer) to anon, authenticated;
grant execute on function public.room_publish(text, text, bigint, jsonb) to anon, authenticated;
grant execute on function public.room_end(text, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Optional: purge expired rooms on a schedule.
--
-- Needs the pg_cron extension, which is not on every plan, so it is kept out
-- of the migration. Rooms expire correctly without it — the read policy checks
-- expires_at — and the app's "Stop sharing" deletes its own row immediately.
--
-- select cron.schedule('cricscore-purge-rooms', '*/10 * * * *',
--   $$delete from public.rooms where expires_at <= now()$$);
-- ---------------------------------------------------------------------------