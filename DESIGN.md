---
name: CricScore
description: Offline gully-cricket umpire scorer — daylight-first instrument UI for a phone held one-handed in direct sun.
---

# Design System: CricScore

## 0. How to read this

This document names **roles**, not raw hex values in screens. Every role is a
real field on `DesignTokens` or `EventTokens` in `lib/core/theme/app_tokens.dart`,
registered as a `ThemeExtension` on both `UmpireTheme.light()` and
`UmpireTheme.dark()`, and read as `context.tokens.<role>` /
`context.events.<role>.fill`. Spacing and radii are `context.spacing.*`
(`AppSpacing`). The seven style presets and ten score fonts live in
`lib/theme.dart`.

The rule that follows: **if a screen needs a colour that is not a role, add the
role** (both light and dark values, in `app_tokens.dart`) — never write
`Color(0x…)` in a screen. `lib/screens` has a raw-colour budget of 10 and sits
at 7 (press overlays and celebration tints only); `tool/check-master.sh` fails
the release if it grows. Raw hex is legal only in `theme.dart` (preset registry)
and `app_tokens.dart` (role definitions).

Both themes ship. Dark mode is a user setting (`store.themeId`), so every role
carries a light and a dark value and every widget must read the role. A rule
that only works on paper is a broken rule.

**The preset boundary.** A `StylePreset` may own exactly six things: `heroBg`,
`heroFg`, `keyDefault`, `keyFg`, `keyRadius`, `stripBg`. Nothing outside
`scoreboard.dart` and the keypad may read a preset — plus the settings style
picker, which has to show a swatch of the preset it selects. Picking *Game Boy*
recolours the score tile and the keys; it never turns the club roster green. This
is what keeps seven arcade presets compatible with one calm, modern chrome.

## 1. Core mandate: an instrument, in direct sunlight

CricScore is an offline-first outdoor utility, operated one-handed, at 10,000+
lux, by someone who is also watching a cricket match. The design exists to make
one glance sufficient.

**Operate, not Persuade.** No marketing chrome, no hero padding, no drop
shadows, no gradients, no backdrop blur, no hover lifts, no runtime font or CDN
fetch. Nothing in this app sells anything. There is no network layer at all:
the live-rooms/viewer feature was removed in 2.27.0 and must not return without
a design review.

**The Bright-Neutral Sunlight Rule.** Pure white everywhere halates in midday
sun, and grey-on-grey disappears. Light mode therefore pairs a **bright neutral
scaffold** (`scaffoldBg`, `#F3F4F6`) with **pure white cards** (`surface`,
`#FFFFFF`). Cards separate by luminance first and border second. Every active
fill is a solid, saturated colour carrying white or near-black ink — no pastels,
no low-alpha tint as the only signal.

**The Locked-Not-Faded Rule.** Never express "disabled", "locked", "already
played" or "just bowled" with opacity. A 45%-alpha name is a smudge in daylight.
Locked rows get a solid `lockedFill`, full-contrast `lockedInk`, an explicit
lock glyph, and the subtitle says why in words.

**The Ink-Not-Tint Rule.** Body copy, captions and subtitles use a real ink
(`onSurface`, `mutedInk`, `lockedInk`), never `onSurface` with an alpha
multiplier. Opacity on white ink over a saturated fill (hierarchy inside a hero
tile) is allowed; opacity on dark ink over a light surface is not.

**The Hierarchy Rule.** Passive containers and interactive controls never carry
the same visual weight. Cards frame content quietly — surface fill, 1.5px
border, generous padding. Buttons, keys and active chips look tactile — solid
fill, full-contrast ink, decisive radius.

## 2. Colour roles

### Structure

| Role | Means | Paper | Night |
|---|---|---|---|
| `scaffoldBg` | the app canvas behind cards | `#F3F4F6` | `#09090B` |
| `surface` | card, sheet and uncommitted-control fill | `#FFFFFF` | `#141417` |
| `primaryFill` | the "chosen / go" fill: primary buttons, selected rows | `#131316` | `#F2F2F2` |
| `onPrimaryFill` | ink on `primaryFill` | white | near-black |
| `onSurface` | primary body ink: names, titles, values | `#0A0A0A` | `#FAFAFA` |
| `mutedInk` | secondary ink: subtitles, reasons, captions | `#475569` | `#A1A1AA` |
| `surfaceOutline` | 1.5px structural border on a card, tile, section or outline button | near-black | near-white |
| `borderRow` | 1px divider between rows of one table/list, 100% opacity | slate | graphite |
| `lockedFill` | solid fill behind a locked/disabled row or key | pale slate | charcoal |
| `lockedInk` | ink on `lockedFill` — always full contrast | deep slate | light grey |

Selection is a **filled slab**, never a tint and never a checkmark alone. An
outline button is an outline (`surfaceOutline`, 1.5px) over the surface fill,
not a lighter version of the primary.

`mutedInk` is wired into `ColorScheme.onSurfaceVariant`, so a screen may keep
reading `context.colors.onSurfaceVariant` and still get our value rather than a
seeded M3 tone.

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

`EventTokens` holds one `EventRole(fill, ink)` per event, because the contrast
is the point: the fill and the numeral ink travel together. These carry meaning
and nothing else:

| Role | Event | Fill | Ink |
|---|---|---|---|
| `eventWicket` | wickets, `W+n` run-out badges | `#DC143C` | white (5.0:1) |
| `eventSix` | a six | `#EC008C` | white (4.3:1) |
| `eventFour` | a four | `#15803D` | white (5.0:1) |
| `eventNoBall` | no-balls, `NB ARMED` | `#7B2CBF` | white (7.1:1) |
| `eventWide` | wides, armed wide key | `#FFBA08` | black (12.3:1) |
| `eventBye` | byes and leg-byes | `#00B4D8` | black (8.5:1) |
| `eventDot` | a dot ball | `#131316` | white |
| `eventRun1` / `eventRun2` / `eventRun3` | 1 / 2 / 3 runs, by cyan depth | light → deep cyan | black / black / white |
| `eventOther` | a badge with no event meaning | `#334155` | white |

**The Badge Contrast Rule.** A 12px w900 badge numeral needs **≥3:1** against
its fill (WCAG AA-large). Four of the six event fills sit between 4.3:1 and 5.0:1
with white ink — that passes, but it is *not* 7:1, and no amount of "harmonising"
will make crimson reach 7:1 while still reading as crimson. The one genuine trap
is bye cyan: `#00B4D8` is 2.46:1 against white, which is why `eventBye` carries
black ink. Never reassign an event ink without redoing that arithmetic.

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
**Body font:** the platform grotesque (Roboto on Android). Bundled with the
engine on Android; the Linux desktop preview resolves it through fontconfig, so
a preview-only face difference is expected and is not a bug.
**Micro-label font:** the same face at `w800–w900` with wide tracking.

Every bundled family is a **single file, single weight**, so anything above
`w700` is synthesised faux-bold. That is why the chrome does not use `w900`
everywhere: it reads blobby and it fights the numerals.

### Hierarchy

- **Display score** — `w900`, 68px, line-height 1.0, letter-spacing −1.5,
  tabular figures, the chosen face. Never below 52px, never wrapped, never
  animated in size.
- **Headline** — `w800`, 15–16px, +0.5 tracking, uppercase: sheet titles,
  empty-state headlines, screen titles.
- **Title** — `w700`, 15px, −0.2 tracking: a person's name in a row, a team
  name, a card title.
- **Body** — `w500`, 13.5–15px; row subtitles and reasons at 12px `w600` in
  `mutedInk`.
- **Micro-label** — `w800–w900`, 10–11px, +1.4 tracking, uppercase: stat
  captions, table column headers, `OV` / `CRR` / `ECON` / `MATCHES`, keypad
  subtitles.

### Named rules

**The One Numeral Rule.** `FontFeature.tabularFigures()` on every number that can
change while it is on screen, so a live score, over count or economy never
jitters.

**The Smaller-Than-Content Ban.** A section heading is never smaller or lighter
than the rows it introduces. Group labels are uppercase `w800` with tracking and
a 1.5px rule, or a filled colour band — never an 11px grey line above 14px bold
names.

**The Not-Everything-Is-Bold Rule.** `w900` belongs to score numerals and
micro-labels. Names are `w700`, body is `w500`, subtitles are `w600`. A screen
where every string is heavy has no hierarchy at all.

### Iconography

Uniform 2px-stroke outline glyphs (Material outlined set, already tree-shaken).
Never mix a filled decorative icon with a thin outline icon in one toolbar.

- `16dp` — inline status glyphs (lock on a locked row, check in a filled slot).
- `20dp` — button and row affordance icons.
- `22–24dp` — app bar actions, inside a 48dp target.
- An icon beside text is optically centred to cap height with a fixed 8dp gap.

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
- Cards stack with 10dp between them. Rows inside a card run edge to edge,
  separated by a 1px `borderRow`, with 14dp horizontal padding.
- The keypad is a fixed 3-column grid at 1.5 aspect ratio; keys are 72dp tall so
  a thumb can hit them without looking, at the bottom of the screen.
- The over strip is a fixed **246dp** window showing exactly six balls — never a
  half-peeking seventh — with the over summary scaling beside it.
- Long text never forces a layout change: names ellipsize first, figures use
  `FittedBox`.

## 5. Elevation and depth

Depth is **luminance-led and border-led**, never shadow-led. Soft shadows vanish
in direct sunlight and cost GPU overdraw for nothing.

- **`elevation: 0` everywhere**, including `cardTheme`, `AppBar`, dialogs, sheets
  and snackbars. Material's elevation 2 draws a shadow *and* a surface tint; it
  is not a semantic label, it is a visual effect, and this app does not ship it.
- Light mode separates by luminance: white `surface` on a `#F3F4F6` `scaffoldBg`.
- **Border hierarchy:** outer card / control frame `1.5px` `surfaceOutline` at
  100% opacity; internal row divider `1px` `borderRow` at 100% opacity; a hairline
  drawn *inside* a saturated fill follows that fill's ink, never `borderRow`.
- Sheets float by a 70%-black scrim and position, not by blur or translucency.
  There is no glassmorphism and no tonal ladder beyond scaffold → card →
  inverted card.

## 6. Shapes

Rectangular and decisive.

- **Controls, buttons, inputs, slots:** 8px (`radiusSm`).
- **Segmented innings switcher:** 12px (`radiusMd`).
- **Cards and sheet sections:** 16px (`radiusLg`).
- **Keypad:** the preset's own radius, 6–14px, so an arcade preset can read as
  CRT or cabinet hardware.
- **Full circles:** only 36dp ball badges, team dots and initials avatars.

Nothing else is a pill — not names, not tabs, not filters. A person is a row.

## 7. Components

### Buttons — `RectBtn`

- **Shape:** 8px rectangle, min 64×52, 12/16 padding, single-line label.
- **Primary:** `primaryFill` fill, `onPrimaryFill` w800 text.
- **Secondary:** `surface` fill with a **1.5px `surfaceOutline` border** and
  `onSurface` text — an outline, not a tint.
- **Danger:** `error` fill, `onPrimaryFill` text. Exactly one meaning: this
  destroys something.
- **Press:** feedback lands on pointer-down with an immediate solid state change
  plus `HapticFeedback.selectionClick()` — never a slow ripple that washes out
  in sun.
- **Disabled:** `lockedFill` fill, `lockedInk` text, and the reason in words in
  the label ("XI full (11)", "just bowled"). Never an opacity.

### Bento tiles and rule chips

- **Tile:** `surface` fill, 1.5px `surfaceOutline`, `radiusMd`, 12dp padding,
  10px `w800` tracked `mutedInk` label above the control. Two tiles may sit
  side by side.
- **Rule chip:** two-state, min height 44dp, 8px radius. **Active** = solid
  `primaryFill` with `onPrimaryFill`. **Inactive** = `surface` with a 1.5px
  `surfaceOutline` and `onSurface` ink. The chip always shows its state in words
  (`ON` / `OFF`, `+1` / `+0`, `ONE` / `NONE`), never by colour alone.

### Cards and containers

`surface` fill, 16px corner, 1.5px `surfaceOutline`, zero shadow, 12dp padding on
live screens and 16–20dp elsewhere. Inverted cards (`primaryFill` +
`onPrimaryFill`) are reserved for the live "act now" strip: innings-break
countdown, match-over countdown.

### Inputs and fields

`surface` fill, 8px radius, 1.5px `surfaceOutline`, 2px `primaryFill` when
focused. Every field carries a **persistent** `labelText` or a standalone heading
immediately above it — a placeholder is never the only label, because it vanishes
the moment the user types. Sheet fields add `viewInsets.bottom` padding so the
keyboard never covers the field or its confirm button.

### Name rows — `PlayerRow` / `DetailRow`

- `PlayerRow` 48dp min, `DetailRow` 54dp min: name left in w700, subtitle
  beneath in w600 `mutedInk`, the value or affordance right.
- **Selected** = solid `primaryFill` slab with `onPrimaryFill` text and a filled
  radio. Not a tint, not a checkmark alone.
- **Locked/disabled** = solid `lockedFill`, `lockedInk`, and a lock glyph (or the
  caller's `trailing`). The subtitle carries the reason.
- Divider: 1px solid `borderRow`, full opacity, bottom edge only.
- A person is always a row. Never a chip, never a pill.

### Navigation

AppBar: flat, `scaffoldBg` background, elevation 0, no surface tint, uppercase
`w800` 15px title, 22dp icon actions each in a 48dp target with a tooltip. Tabs
are underlined text (`UnderlineTabs`): the label reads as a heading, a 2.5px rule
marks the open one, and nothing moves when selection changes.

Page transitions are intentionally **instant** so route changes never animate
against a live scoreboard, celebration or strip glide. Sheets settle in 280ms
ease-out, collapsing to 120ms when reduced motion is requested.

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

36dp circles, solid fill from `context.events`, numeral in the role's own ink,
**no borders, no glow, no scale, no corner markers** — all six balls in an over
look structurally identical so the *colour* carries the meaning. Ordered by
impact: wicket crimson > six magenta > four green > no-ball purple > wide amber >
bye cyan > dot carbon > runs by cyan depth.

### Tables (scorecard, bowling figures, squad lists)

- **One header band per table**, `primaryFill` fill with `onPrimaryFill` w800
  11px uppercase labels. Batting and bowling tables in the same sheet use the
  same band, so the sheet reads as one grid.
- **Numeric columns are right-aligned, tabular, and the same width across
  tables** (batting `R | B | 4s | 6s`, bowling `O | M | R | W`). A figure that
  does not align with the figure above it is a bug.
- Unplayed squad members are listed after played ones, with `did not bat` /
  `did not bowl` in `mutedInk` — dimmed by *ink choice*, never by opacity on the
  whole row.
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
   `statGoodInk` check; an empty slot writes `TAP TO PICK` in `mutedInk`, so no
   state is colour-only. No cricket-event colour here — the bowler slot is
   structural, not a wicket.
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

Outdoor heat is a performance constraint: no `BackdropFilter`, no continuous
shadow animation, no infinite ticker. Compositor-only effects keep the phone from
throttling peak brightness.

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

- **Do** read every colour through `context.tokens` / `context.events` /
  `context.colors` and every gap through `context.spacing`.
- **Do** let the bright neutral scaffold and the white card do the separating in
  light mode, so borders stay crisp instead of carrying the whole hierarchy.
- **Do** reserve `w900` for score numerals and micro-labels, `w700` for titles
  and `w600` for subtitles.
- **Do** express selection as a solid fill with `onPrimaryFill` text at w700+.
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
- **Don't** ship `elevation: 2` "for semantics" — it draws a shadow and a tint.
- **Don't** make every string `w900` uppercase; that is not hierarchy.
- **Don't** add a page transition, hero animation or layout-size change to
  anything that moves on a live score.
- **Don't** hide a destructive action behind a collapsed trigger, or let a swipe
  dismiss a sheet with unsaved edits.
- **Don't** use a hint as a label, or hide the only explanation of a format in a
  placeholder that disappears while typing.
- **Don't** add a style preset, celebration or score font without wiring it into
  `StylePreset.presets` / `MatchStore.celebIds` / `ScoreFonts.ids` and the
  settings sheet in the same change.
- **Don't** read `StylePreset` outside `scoreboard.dart`, the keypad and the two
  style swatches (`StylePreset.ids` / `StylePreset.of`).
- **Don't** add a network call, a live-room viewer, a runtime font fetch or a CDN
  asset.

## 12. Enforcement

`tool/check-master.sh` (runs inside `tool/release.sh`) is the gate, not a
suggestion. It fails on:

- `APP.md` missing, over 1000 words, or its `Version:` disagreeing with
  `pubspec.yaml`;
- a role named in this document that is missing from `app_tokens.dart`;
- raw `Color(0x` in `lib/screens/home.dart` or `break_result.dart`;
- `lib/screens` raw-colour count above its baseline (10, currently 7);
- text dimming via `withValues(alpha: 0.4x)` / `0.45`;
- bare `#22C55E` / `#F59E0B` as a colour in `lib/screens`;
- stock Material chrome (`Card(`, `ListTile(`, `SwitchListTile(`, `ExpansionTile(`,
  `FilledButton(`, `ElevatedButton(`, `OutlinedButton(`, `TextButton(`) in the
  screen layer — `scoreboard.dart` and `scoring.dart` are allowlisted because the
  hero tile and the keypad are the arcade surface, and `widgets.dart` is the kit
  itself;
- `StylePreset` read anywhere but `scoreboard.dart`, the keypad, and the
  `StylePreset.of` / `StylePreset.ids` swatches in `home.dart` and `sheets.dart`;
- a `design-system/` directory reappearing.

`tool/check-ux.sh` enforces single-line labels (`overflow: ellipsis`) so no
button wraps. `tool/ui-inventory.sh` verifies that every `file:line` reference in
`docs/ui-inventory.html` still resolves; the inventory is the component ID index
(`sheet.settings`, `scoring.keypad.grid`, `widget.playerrow`) you paste back when
requesting a change.
