# Live rooms — Phase 1 setup

Live rooms let another phone watch your score read-only, using a 5-character
code. Scoring is unaffected: everything below is **opt-in at build time**, and
a build without these values is the offline app it always was.

Supabase holds one row per live match. Your phone is the only writer — enforced
by the database, not by the app — and viewers only ever read.

---

## 1. Enable anonymous sign-ins (2 min)

Your phone signs in anonymously so the database has an owner identity to
compare writes against.

1. Supabase dashboard → **Authentication** → **Sign In / Providers**
2. Turn **Anonymous Sign-Ins** on → **Save**

Without this, sharing fails with an auth error; scoring is unaffected.

---

## 2. Create the table and its security policies (2 min)

1. Dashboard → **SQL Editor** → **New query**
2. Paste the entire contents of `migrations/0001_rooms.sql`
3. **Run**. You should see `Success. No rows returned`

That file creates the `rooms` table, enables row level security, and adds four
policies:

| Policy | Who | What |
|---|---|---|
| `rooms read while live` | anyone | read a room that has not expired |
| `rooms owner inserts` | authenticated | only when `owner_id` is you |
| `rooms owner updates` | authenticated | only your own room |
| `rooms owner deletes` | authenticated | only your own room |

Also add the table to the realtime publication, so viewers get pushed updates.

**Optional, afterwards:** run `migrations/0002_purge_cron.sql` to have Supabase
delete expired rooms every 10 minutes. It needs the `pg_cron` extension, which
is not available on every plan. Rooms expire correctly without it — the app's
**Stop sharing** button also deletes its own row.

---

## 3. Get your keys (1 min)

Dashboard → **Settings** → **API**.

You need two values:

- **Project URL** — looks like `https://abcdefgh.supabase.co`
- **Publishable key** (newer projects) or the legacy **anon** public key

Do **not** use the `service_role` key. It bypasses row level security, and
anything that bypasses RLS has no reason to be inside a distributed app.

---

## 4. Build with your keys

Pass them as `--dart-define` values, so nothing secret enters git:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://abcdefgh.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Omit them and the app builds and runs exactly as before.

---

## Verify it worked

1. Start a match, tap the **share** icon in the scoring app bar.
2. A banner in the app bar shows a code, e.g. `K7M2P`.
3. Dashboard → **Table Editor** → `rooms`: one row, your code, a `seq` that
   **increases every time you score**, and a `payload` column holding the match.
4. Tap **Stop sharing** — the row disappears.

`seq` climbing as you score is the whole mechanism: each update carries the
complete match, so a viewer that misses a packet just reads the next full
snapshot rather than replaying a delta.

---

## The security model in one paragraph

The join code **is** the capability. It has 33,554,432 possible values, because
digits-only would be 100,000 — seconds to brute-force, so not a real secret. A
leaked code therefore grants read access and nothing else: writes require a
row whose `owner_id` matches the anonymous signed-in user on your phone. Rooms
expire after 12 hours and are deleted when you stop sharing.

Player names leave your device when you share. For a club with players that may
include children, that is the one thing worth being deliberate about.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| "Live sharing unavailable" | No keys in this build, or sign-in failed |
| `Anonymous sign-ins` error | Step 1 not done |
| `new row violates row-level security` | Table not created, or policies missing (step 2) |
| Row appears, `seq` stuck at 0 | Sharing was opened before scoring; score a ball and re-check |
| Viewer sees nothing | Table not added to `supabase_realtime` (step 2) |