-- CricScore live rooms — 001: the room row and who may read it.
--
-- A room is one live match snapshot. This file creates the table and allows
-- reads; 002 adds the write capability. Nothing here trusts the app: reads are
-- open because the code is the capability, and writes do not exist yet at all.
--
-- Applied to the live project via the Supabase MCP (migration `create_rooms`).

create table if not exists public.rooms (
  code        text primary key,
  seq         bigint      not null default 0,
  payload     jsonb       not null default '{"v":1}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  -- 32 symbols, no 0/O or 1/I: 33,554,432 codes, and none of them misread aloud.
  constraint rooms_code_shape check (code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]{5}$')
);

comment on table public.rooms is
  'Live match snapshots shared with viewers. Writes go only through the room_* functions in 002.';

-- Purge scans hit expires_at.
create index if not exists rooms_expires_at_idx on public.rooms (expires_at);

alter table public.rooms enable row level security;

-- Reads are open while the room is alive. There is deliberately no INSERT,
-- UPDATE or DELETE policy: with RLS on and no policy for an operation, the
-- database rejects it. Verified: an anon PATCH returns 204 with zero rows
-- affected, and the row is unchanged.
drop policy if exists "rooms read while live" on public.rooms;
create policy "rooms read while live"
  on public.rooms
  for select
  to anon, authenticated
  using (expires_at > now());

-- Viewers get pushed every ball. Postgres changes (not broadcast) because the
-- row is already the source of truth: one write, one event, no second copy.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rooms'
  ) then
    alter publication supabase_realtime add table public.rooms;
  end if;
end
$$;