-- CricScore live rooms — Phase 1
-- A room is one live match snapshot that viewers can read. The scoring phone
-- is the only writer; the database enforces that with RLS, so a leaked code
-- grants read access and nothing else.
--
-- Run this in the Supabase SQL editor (Dashboard -> SQL Editor -> New query),
-- or with `supabase db push` if you link a CLI project.

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------
create table if not exists public.rooms (
  code        text primary key,
  owner_id    uuid        not null references auth.users (id) on delete cascade,
  seq         bigint      not null default 0,
  payload     jsonb       not null default '{"v":1}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  -- Guards against a fat-fingered or malicious loop hammering the same room.
  constraint rooms_code_shape check (code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ2-9]{5}$')
);

comment on table public.rooms is
  'Live match snapshots shared with viewers. Scorer device owns the row; viewers are read-only.';

-- Purge scans hit expires_at; the owner lookup hits owner_id.
create index if not exists rooms_expires_at_idx on public.rooms (expires_at);
create index if not exists rooms_owner_idx      on public.rooms (owner_id);

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------
alter table public.rooms enable row level security;

-- Viewer read: the code IS the capability, so any caller may read a live room.
-- Nothing but the owner can write.
drop policy if exists "rooms read while live" on public.rooms;
create policy "rooms read while live"
  on public.rooms
  for select
  to anon, authenticated
  using (expires_at > now());

drop policy if exists "rooms owner inserts" on public.rooms;
create policy "rooms owner inserts"
  on public.rooms
  for insert
  to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists "rooms owner updates" on public.rooms;
create policy "rooms owner updates"
  on public.rooms
  for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "rooms owner deletes" on public.rooms;
create policy "rooms owner deletes"
  on public.rooms
  for delete
  to authenticated
  using (auth.uid() = owner_id);

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
-- Viewers get pushed every score. Postgres changes (not broadcast) because the
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