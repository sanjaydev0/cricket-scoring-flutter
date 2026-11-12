---
name: CricScore
description: Offline gully-cricket umpire scorer — glare-first arcade scoring for a phone held in one hand in the sun.
---

# Design System: CricScore

## 0. How to read this

This document names **roles**, not hex values. Every role is a real field on
`DesignTokens` in `lib/core/theme/app_tokens.dart`, registered as a
`ThemeExtension` on both `UmpireTheme.light()` and `UmpireTheme.dark()`, and read
as `context.tokens.<role>`. Spacing and radii are `context.spacing.*`
(`AppSpacing`). The seven style presets and ten score fonts live in
`lib/theme.dart`.

The rule that follows from that: **if a screen needs a colour that is not a
role, add the role** (light and dark values, in `app_tokens.dart`) — do not
write `Color(0x…)` in a screen. `lib/screens` has a raw-colour budget of 64 and
sits at 62; `tool/check-master.sh` fails the release if it grows. Raw hex is
legal only in `theme.dart` (preset registry) and `app_tokens.dart` (role
definitions).

Both themes ship. Dark mode is a user setting (`store.themeId`), so every role
carries a light and a dark value and every widget must read the role. A rule
that only works on paper is a broken rule.

## 1. Core mandate: the umpire's scoreboard, in direct sunlight

CricScore is an offline-first outdoor utility, operated one-handed, at 10,000+
lux, by someone who is also watching a cricket match. The design exists to make
one glance sufficient.

**Operate, not Persuade.** No marketing chrome, no hero padding, no drop
shadows, no gradients, no backdrop blur, no hover lifts, no runtime font or CDN
fetch. Nothing in this app sells anything. There is no network layer at all:
the live-rooms/viewer feature was removed in 2.27.0 and must not return without
a design review.

**The Sunlight Rule.** Every fill is a solid, saturated colour carrying white or
near-black text. No pastels, no low-alpha tint as the only signal, no
grey-on-grey. If a state can only be read by a subtle shade change, it is wrong.

**The Locked-Not-Faded Rule.** Never express "disabled", "locked", "already
played" or "just bowled" with opacity. A 45%-alpha name is a smudge in daylight.
Locked rows get a solid `lockedFill`, full-contrast `lockedInk`, and an explicit
lock glyph; the subtitle says why in words.

**The Ink-Not-Tint Rule.** Body copy, captions and subtitles use a real ink
(`onSurface`, `onSurfaceVariant`, `lockedInk`), never `onSurface` with an alpha
multiplier. Opacity on white ink over a saturated fill (hierarchy inside a hero
tile) is allowed; opacity on dark ink over a light surface is not.

## 2. Colour roles

### Structure

| Role | Means | Paper | Night |
|---|---|---|---|
| `primaryFill` | the "chosen / go" fill: primary buttons, selected rows | near-black | near-white |
| `onPrimaryFill` | ink on `primaryFill` | white | near-black |
| `surfaceOutline` | 1.5px structural border on a card, tile, section or outline button | near-black | near-white |
| `borderRow` | 1px divider between rows of one table/list, 100% opacity | slate | graphite |
| `lockedFill` | solid fill behind a locked/disabled row or key | pale slate | charcoal |
| `lockedInk` | ink on `lockedFill` — always full contrast | deep slate | light grey |

Selection is a **filled slab**, never a tint and never a checkmark alone. An
outline button is an outline (`surfaceOutline`, 1.5px) over the surface fill,
not a lighter version of the primary.

### Derived figures

| Role | Means |
|---|---|
| `statGoodInk` | a positive derived figure as text — wickets in a bowling row, an active club/profile, a completed XI slot |
| `statGoodFill` | the pill fill when such a figure must sit on a surface |
| `statWarnInk` | an advisory figure as text — economy, a result line |

Bright green and bright amber are **never** bare text on white: `#22C55E` on
white is 2.2:1 and `#F59E0B` is 2.1:1, both unreadable outdoors. Use
`statGoodInk` / `statWarnInk`, or a `statGoodFill` pill carrying `statGoodInk`.

### Cricket events

These carry meaning and nothing else. They are not decoration, not headings, not
generic emphasis:

- **Wicket crimson** — wickets and `W+n` run-out badges.
- **Six magenta** — a six.
- **Four green** — a four.
- **Wide amber** — wides, and the armed no-ball keypad state.
- **No-ball purple** — no-balls and the `NB ARMED` caption.
- **Bye cyan** — byes and leg-byes.

**The Event Colour Rule.** If a colour from that list appears anywhere that is
not a ball event, its badge or its celebration tint, the design is wrong.

### Team identity

Team A is blue, Team B is red (`MatchStore.teamAColor` / `teamBColor`), always
rendered as a solid dot, a solid header band, or a solid pill fill. A team colour
is never used as a 5%-alpha page wash.

## 3. Typography

**Display font:** the user's chosen score face — ten bundled OFL families
exposed through `ScoreFonts` (Stadium Sans, Condensed Punch, Block Heavy, Mono
Ledger, Tech Board, Tall Ticket, Ultra Slab, Wide Circuit, Broadcast, Narrow
Board).
**Body font:** platform default (Roboto on Android), bundled and offline.
**Label font:** the same default, forced to w900 with wide tracking.

Character: a heavy grotesque for structure, an outsized tabular numeral face for
the score. The UI never competes with the numerals — labels are small, tracked
and uppercase; the score is the largest thing on any screen.

### Hierarchy

- **Display score** — w900, 68px, line-height 1.05, tabular figures, the chosen
  face. Never below 52px, never wrapped, never animated in size.
- **Headline** — w900, 16px, uppercase: sheet titles, empty-state headlines.
- **Title** — w800, 15px: a person's name in a row, a team name.
- **Body** — w400–w700, 13px; list subtitles at 11–12px w600.
- **Label** — w900, 9–11px, 1.2–2px tracking, uppercase: stat captions, section
  bands, `OV` / `ECON` / `MATCHES` micro-labels, keypad key subtitles.

### Named rules

**The One Numeral Rule.** `FontFeature.tabularFigures()` on every number that can
change while it is on screen, so a live score, over count or economy never
jitters.

**The Smaller-Than-Content Ban.** A section heading is never smaller or lighter
than the rows it introduces. Group labels are uppercase w900 with tracking or a
filled colour band — never an 11px grey line above 14px bold names.

## 4. Layout

Portrait, one-handed. Content is a single column centred in `ResponsiveCenter`
(560dp, 640dp on scoring and scorecard) so a tablet or the Linux desktop preview
shows the same phone-shaped column instead of a stretched grid.

**The Single-Column-Of-Content Rule.** Reading order is one column, top to
bottom. That is not a ban on a 2-up arrangement of *controls*: two stepper tiles,
two rule columns or two XI columns may sit side by side, and should, when the
alternative is a scroll. Side-by-side content must stack under 360dp rather than
crush a name or a 44dp target.

- Spacing scale: `context.spacing` — 4 / 8 / 16 / 24 / 32. Hand-tuned 6 and 10
  gaps are allowed inside a row; page padding is 12dp on dense live screens,
  16dp on home/history, 20dp inside sheets.
- Cards stack with 8–10dp between them. Rows inside a card use a 1px solid
  `borderRow` and no outer margin.
- The keypad is a fixed 3-column grid at 1.5 aspect ratio; keys are 72dp tall so
  a thumb can hit them without looking, at the bottom of the screen.
- The over strip is a fixed **246dp** window showing exactly six balls — never a
  half-peeking seventh — with the over summary scaling beside it.
- Long text never forces a layout change: names ellipsize first, figures use
  `FittedBox`.

## 5. Elevation and depth

Depth is border-led, not shadow-led. Every card carries Material elevation **2**
with a **1.5px solid `surfaceOutline`** border and no visible drop shadow: a soft
shadow disappears in sunlight while a border still reads. A 1px 50%-alpha
hairline does not read either — that is why structural borders are 1.5px at full
opacity and row rules are 1px at full opacity. A rule drawn *inside* a saturated
fill (the hairline under the hero numerals) follows that fill's ink instead of
`borderRow`, because `borderRow` is a surface-level role.

Sheets are the only surfaces that float, and they float by scrim and position,
not by blur or translucency. There is no glassmorphism, no gradient, and no tonal
ladder beyond scaffold → card → inverted card.

**The Border-Not-Shadow Rule.** A new surface gets a border before it gets a
shadow. Nothing in this app is distinguished by blur.

## 6. Shapes

Rectangular and decisive. Controls are **8px** rectangles (`radiusSm`); cards and
sheet sections are **16px** (`radiusLg`); the style preset carries its own keypad
radius (6–14px) so the arcade presets can read as CRT or cabinet hardware. The
registry ships seven presets (Umpire Pro, Solar Flare, Pure White, Crimson Court,
Nothing Mono, Game Boy, Pro Red); `StylePreset.ids` is the only list to iterate.

Full-round shapes are reserved for **36dp ball badges**, **team dots** and
**initials avatars**. Nothing else is a pill — not names, not tabs, not filters.
The one sanctioned slab is the innings switcher (12px), because it is a
segmented control, not a chip.

## 7. Components

### Buttons — `RectBtn`

- **Shape:** 8px rectangle, min 64×52, 12/16 padding.
- **Primary:** `primaryFill` fill, `onPrimaryFill` w800 text.
- **Secondary:** surface fill with a **1.5px `surfaceOutline` border** and
  `onSurface` text — an outline, not a tint. (The border is 1.5px, not 2px: it
  has to match the card border and stay crisp at 1× DPI.)
- **Danger:** `error` fill, `onPrimaryFill` text. Exactly one meaning: this
  destroys something.
- **Press:** feedback lands on pointer-down with an immediate 75–80% black
  overlay, not a ripple. A ripple is invisible in direct sun.
- **Disabled:** `lockedFill` fill, `lockedInk` text, and the reason in words in
  the subtitle ("XI full (11)", "just bowled"). Never an opacity.

### Bento tiles and rule chips

The compact mid-match control language, used where an umpire must see state
without scrolling:

- **Tile:** surface fill, 1.5px `surfaceOutline`, `radiusMd`, label at 10px w900
  `onSurfaceVariant`, control beneath. Two tiles may sit side by side.
- **Rule chip:** two-state, min height 44dp. **Active** = saturated `primary`
  fill with `onPrimary` ink (a strip of near-black chips is unreadable in sun).
  **Inactive** = surface fill with a 1.5px `surfaceOutline` border and
  `onSurface` ink. The chip always shows its state in words (`ON` / `OFF`,
  `+1` / `+0`, `ONE` / `NONE`), never by colour alone.

### Cards and containers

Corner 16px, border 1.5px `surfaceOutline`, elevation 2, no visible shadow,
padding 12dp on live screens and 16–20dp elsewhere. Inverted cards
(`primaryFill` + `onPrimaryFill`) are reserved for the live "act now" strip:
innings-break countdown, match-over countdown.

### Inputs and fields

Outline border, 8px radius, dense where it sits in a row. Every field carries a
**persistent** `labelText` or a standalone heading immediately above it — a
placeholder is never the only label, because it vanishes the moment the user
types. Sheet fields add `viewInsets.bottom` padding so the keyboard never covers
the field or its confirm button.

### Name rows — `PlayerRow` / `DetailRow`

- `PlayerRow` 48dp min, `DetailRow` 54dp min: name left in w800, subtitle
  beneath in w600 `onSurfaceVariant`, the value or affordance right.
- **Selected** = solid `primaryFill` slab with `onPrimaryFill` text and a filled
  radio. Not a tint, not a checkmark alone.
- **Locked/disabled** = solid `lockedFill`, `lockedInk`, and a lock glyph (or the
  caller's `trailing`). The subtitle carries the reason.
- Divider: 1px solid `borderRow`, full opacity, bottom edge only.
- A person is always a row. Never a chip, never a pill.

### Navigation

AppBar: uppercase w900 15px title, icon actions only, each with a tooltip. Tabs
are underlined text (`UnderlineTabs`): the label reads as a heading, a 2.5px rule
marks the open one, and nothing moves when selection changes.

Page transitions are intentionally **instant** so route changes never animate
against a live scoreboard, celebration or strip glide. Sheets use a 280ms
ease-out settle, collapsing to 120ms when reduced motion is requested.

### Scoreboard (signature)

The hero tile is the product. Solid preset fill, four hairline registration
crosses in the corners, team dot + uppercase team name in a 20px chip, then the
68px runs/wickets pair, a hairline, then a three-up stat row (OVERS / CRR /
EXTRAS). Tapping swaps the stat row for the chase line (TARGET / NEED n OFF n ·
RRR) for four seconds, in place, with no layout shift outside the card.

For assistive technology the whole tile is **one** semantic node announcing team,
score, overs, run rate, free-hit state and chase requirement, with a hint that
the tile can be double-tapped.

### Ball badges (signature)

36dp circles, solid fill, white or black numeral, **no borders, no glow, no
scale, no corner markers** — all six balls in an over look structurally
identical so the *colour* carries the meaning. Ordered by impact: wicket crimson
> six magenta > four green > no-ball purple > wide amber > bye cyan > dot carbon
> runs by cyan depth.

### Tables (scorecard, bowling figures, squad lists)

- **One header band per table**, preset/`primaryFill` fill with `onPrimaryFill`
  w900 11px uppercase labels. Batting and bowling tables in the same sheet use
  the same band, so the sheet reads as one grid.
- **Numeric columns are right-aligned, tabular, and the same width across
  tables** (batting `R | B | 4s | 6s`, bowling `O | M | R | W`). A figure that
  does not align with the figure above it is a bug.
- Unplayed squad members are listed after played ones, with `did not bat` /
  `did not bowl` in `onSurfaceVariant` — dimmed by *ink choice*, never by
  opacity on the whole row.
- Undefined figures render `—`, never `0`.

## 8. Sheet contracts

`sheet.settings` (mid-match config) — bento, not a form:

1. Two stepper tiles: `OVERS`, `PLAYERS / SIDE`.
2. A rule-chip strip: `DOUBLE`, `WIDE`, `NO-BALL`, `FREE HIT`, `LAST MAN`.
3. Both XIs as side-by-side columns, each with a solid team-colour header band
   and `n/cap`; locked members show a lock at full contrast.
4. One shared bench pool with a search field, `＋ NEW`, and one-tap `+TEAM`
   assignment; `BOTH` appears only when double-side is `ONE`.
5. `DECLARE WINNER` (two team keys) and `ABANDON MATCH` at the bottom, always
   visible. Rule edits stay pending behind an `UNSAVED` badge and a save prompt
   on every exit path — including the ✕, CANCEL and system back. Squad ticks
   commit immediately (each is its own undo snapshot).

`sheet.openers` (innings start) — three answers, one list:

1. Header band in the batting side's team colour: `OPENERS + BOWLER`, the team,
   `n/3`, and the ✕.
2. Three slots (`STRIKER`, `NON-STRIKER`, `BOWLER`) at 56dp, 8px corners, 6dp
   gutter. The active slot is a `primaryFill` slab with `onPrimaryFill` ink; a
   filled inactive slot is `surface` with a 1.5px `surfaceOutline` and a
   `statGoodInk` check; an empty slot writes `TAP TO PICK` in
   `onSurfaceVariant`, so no state is colour-only. No cricket-event colour
   here — the bowler slot is structural, not a wicket.
3. One search field, then one name list (`PlayerRow`, names only — no role or
   style tags). The pool is the batting XI for the two batter slots and the
   bowling XI for the bowler, minus every assigned name.
4. Sticky footer: `CLEAR ALL` and the primary key, which reads `PICK ALL THREE`
   on a `lockedFill` slab until all three are in, then `START INNINGS`.
   Committing pushes ONE undo snapshot for the three, not three snapshots.

Assigned names leave the pool entirely: a picked player appears in its slot and
nowhere else — never twice, never as a locked row. The slots are the only
picker: tapping a filled slot takes the answer back and makes that role active,
and a pick auto-advances to the next empty slot and clears the search.

The sheet is offered by itself before the first ball of each innings. Once all
three are set and before ball one, the over strip's `0r • 0w ›` tail becomes an
`EDIT` key (`scoring.strip.edit`) that reopens it; after the first ball the tail
is the overs tap-through again and mid-innings changes stay in PLAYERS. The key
never appears beside the blue `SET BATTERS + BOWLER TO START` card.

`sheet.playerstats` (active matchup) — one aligned grid: batter rows with
`R | B | 4s | 6s`, bowler rows with `O | M | R | W`, the striker marked with a
filled badge, partnership strip below, then two equal-width actions
(`SWAP ENDS`, `CHANGE BOWLER`) and `FULL SCORECARD`.

`sheet.runout` — two sheets, because a run-out has two questions. Sheet 1 asks
runs completed (`W`, `W+1`, `W+2` — **no `W+3`**), who was dismissed, and which
end; it records nothing. Sheet 2 names the next batter and commits the ball
atomically with him. A back gesture from either sheet records nothing.

## 9. Motion

Layout-frozen by rule. Celebrations may only use `Transform`, `Opacity`,
`ShaderMask`, `TextStyle` colour/shadow, or `Positioned` overlays — nothing may
change a layout size. Runs and wickets numerals animate independently, never the
score tile.

The over strip glides 900ms on a forward rollover and never fades on undo. Honour
`MediaQuery.disableAnimationsOf` everywhere. Battery Saver forces celebrations
`off`; it never dims a glare-first visual.

## 10. Accessibility

- Every interactive target is at least 48dp; every icon-only control has a
  `tooltip`, which is also its screen-reader label.
- One coherent screen-reader sentence per scoreboard, not a pile of bare
  numerals.
- Never encode state in colour alone: a chip says `ON`, a locked row says why, a
  badge carries its numeral.
- `FittedBox(fit: BoxFit.scaleDown)` around any fixed-size text block so a 2×
  system text size shrinks instead of overflowing.

## 11. Do and Don't

### Do

- **Do** read every colour through `context.tokens` / `context.colors` and every
  gap through `context.spacing`.
- **Do** express selection as a solid fill with `onPrimaryFill` text at w800+.
- **Do** express locked/disabled as `lockedFill` + `lockedInk` + a lock glyph and
  a written reason.
- **Do** use `statGoodInk` / `statWarnInk` for derived figures.
- **Do** keep names as rows and controls as 8px rectangles; circles only for
  badges, dots and avatars.
- **Do** align numeric columns across every table in a sheet.
- **Do** let control pairs sit 2-up and stack them under 360dp.
- **Do** confirm every destructive action, and name what is *not* deleted.
- **Do** keep celebrations inside Transform/Opacity/ShaderMask/text colour and
  honour reduced motion.

### Don't

- **Don't** write `Color(0x…)` in `lib/screens`, or add a role-less colour.
- **Don't** dim text with opacity — not 0.45, not 0.4, not 0.3.
- **Don't** draw a structural border thinner than 1.5px or a row rule at partial
  alpha.
- **Don't** put bright green or bright amber as bare text on a surface.
- **Don't** introduce a pastel, a low-alpha tint state, or grey-on-grey body
  copy: that is the Sunlight Rule failing.
- **Don't** use crimson, magenta, green, amber, purple or cyan for anything that
  is not a cricket event.
- **Don't** add a page transition, hero animation or layout-size change to
  anything that moves on a live score.
- **Don't** hide a destructive action behind a collapsed trigger, or let a swipe
  dismiss a sheet with unsaved edits.
- **Don't** use a hint as a label, or hide the only explanation of a format in a
  placeholder that disappears while typing.
- **Don't** add a style preset, celebration or score font without wiring it into
  `StylePreset.presets` / `MatchStore.celebIds` / `ScoreFonts.ids` and the
  settings sheet in the same change.
- **Don't** add a network call, a live-room viewer, a runtime font fetch or a CDN
  asset.

## 12. Enforcement

`tool/check-master.sh` (runs inside `tool/release.sh`) is the gate, not a
suggestion. It fails on:

- `APP.md` missing, over 1000 words, or its `Version:` disagreeing with
  `pubspec.yaml`;
- raw `Color(0x` in `lib/screens/home.dart` or `break_result.dart`;
- `lib/screens` raw-colour count above its baseline;
- text dimming via `withValues(alpha: 0.4x)` / `0.45`;
- bare `#22C55E` / `#F59E0B` as a colour in `lib/screens`;
- a `design-system/` directory reappearing.

`tool/check-ux.sh` enforces single-line labels (`overflow: ellipsis`) so no
button wraps. `tool/ui-inventory.sh` verifies that every `file:line` reference in
`docs/ui-inventory.html` still resolves; the inventory is the component ID index
(`sheet.settings`, `scoring.keypad.grid`, `widget.playerrow`) you paste back when
requesting a change.
