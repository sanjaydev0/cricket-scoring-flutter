# Live rooms — setup & how it works

Live rooms let another phone watch your score read-only, using a 5-character
code. Scoring is unaffected: everything is **opt-in at build time**, and a build
without credentials is the offline app it always was.

**Status: the schema is already applied to your project** (`uhoghzqrsfxvvhwbrfbo`)
and verified end-to-end. There is nothing left to paste into the dashboard.

---

## Build with your keys

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://uhoghzqrsfxvvhwbrfbo.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_stWZgYcHnv9TtZkb-Yu3vA_knLLpVZz
```

Omit them and the app builds and runs exactly as before, with no network path
reachable.

Use the **publishable** key (`sb_publishable_…`). Never `service_role`: it
bypasses row level security, and anything that bypasses RLS has no business
inside a distributed app.

---

## What you do

1. **Share** (icon in the scoring app bar) → a 5-char code appears.
2. **Watch live** on the other phone → type the code → read-only score, updating
   per ball.
3. **Stop sharing** → the row is deleted immediately.

---

## How the security works

There is **no login, no account, and no Supabase Auth** — including anonymous
sign-ins, which are disabled by default on a fresh project and would have made
the scorer depend on a dashboard toggle.

Instead, a room has two capabilities:

| Capability | Held by | Grants |
|---|---|---|
| the **code** (33,554,432 possibilities) | anyone you tell | read the score |
| a 160-bit **secret** | the scoring phone only | write the score |

The secret is stored in `room_secrets`, a table with RLS enabled and **no
policies at all**, revoked from `anon` and `authenticated`. No client role can
read it. Writes go through `security definer` functions that check the secret.

Verified against the live project:

| Attempt (as the `anon` role) | Result |
|---|---|
| `SELECT * FROM room_secrets` | **401** permission denied |
| `PATCH /rest/v1/rooms?code=eq.X` with `seq: 999` | **204, zero rows affected** — row unchanged |
| `DELETE /rest/v1/rooms?code=eq.X` | **204, zero rows affected** — row still there |
| `SELECT /rest/v1/rooms?code=eq.X` | **200** — reads are meant to work |
| `room_publish` with a wrong secret | returns `false`, nothing written |
| `room_create` with a weak secret | refused |
| `room_create` with code `TEST1` | refused — `1` is not in the alphabet |

---

## Data model

```
public.rooms         code PK, seq, payload jsonb, created_at, updated_at, expires_at
public.room_secrets  code PK -> rooms, secret          (no client can read this)
room_create          (code, secret, ttl_hours) -> bool   false if code taken
room_publish         (code, secret, seq, payload) -> bool
room_end             (code, secret) -> bool
```

Every publish carries the **whole match**, not a delta. A viewer that misses a
packet just reads the next full snapshot, so there is no delta reconciliation
to get wrong. `greatest(seq, new_seq)` makes a replayed or out-of-order publish a
no-op rather than a rewind.

Rooms expire after 12 hours (refreshed on every publish). Optionally, purge them
on a schedule — see the commented `cron.schedule` at the bottom of
`migrations/0002_room_secret_capability.sql`.

---

## What still needs a human

Only one thing, and it is optional:

**Automatic purging** of expired rows. Needs the `pg_cron` extension. Without
it nothing breaks — the read policy checks `expires_at`, so an expired room
becomes unreadable, and *Stop sharing* deletes its row on demand.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| "Live sharing unavailable" | No `--dart-define` values in this build |
| Row appears, `seq` stuck at 0 | Sharing opened before any ball — score one |
| Viewer sits on "Waiting for the scorer" | Room code wrong, or expired, or the scorer is offline |
| Viewer frozen on an old score | The grey chip shows how stale it is; check the scorer is online |