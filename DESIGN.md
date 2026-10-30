---
name: CricScore
description: Offline gully-cricket umpire scorer — glare-first arcade scoring for a phone held in one hand in the sun.
colors:
  umpire-blue: "#1D4ED8"
  carbon-ink: "#131316"
  carbon-deep: "#0A0A0A"
  paper: "#FAFAFA"
  night: "#0B0B0D"
  surface-night: "#131316"
  hairline: "#E2E2E2"
  hairline-dark: "#2E2E33"
  wicket-crimson: "#DC143C"
  danger-red: "#DC2626"
  six-magenta: "#EC008C"
  four-green: "#15803D"
  success-green: "#22C55E"
  live-green: "#16A34A"
  wide-amber: "#FFBA08"
  econ-amber: "#F59E0B"
  no-ball-purple: "#7B2CBF"
  bye-cyan: "#00B4D8"
  muted-slate: "#94A3B8"
  solar-cream: "#FFF3C4"
  gameboy-green: "#9BBC0F"
  gameboy-ink: "#0F380F"
typography:
  display-score:
    fontFamily: "ScoreFonts.family(id) — 10 bundled OFL faces, see Typography"
    fontSize: "68px"
    fontWeight: 900
    lineHeight: 1.05
    fontFeature: "tabular-figures"
  code-entry:
    fontSize: "28px"
    fontWeight: 900
    letterSpacing: "10px"
  headline:
    fontSize: "16px"
    fontWeight: 900
  title:
    fontSize: "15px"
    fontWeight: 800
  body:
    fontSize: "13px"
    fontWeight: 400
  caption:
    fontSize: "11px"
    fontWeight: 400
  label:
    fontSize: "10px"
    fontWeight: 900
    letterSpacing: "2px"
  value:
    fontSize: "18px"
    fontWeight: 900
    fontFeature: "tabular-figures"
rounded:
  sm: "6px"
  control: "8px"
  pill: "12px"
  button: "14px"
  card: "16px"
  round: "20px"
spacing:
  xxs: "4px"
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  xl: "16px"
  xxl: "20px"
  page: "24px"
components:
  button-primary:
    backgroundColor: "{colors.carbon-ink}"
    textColor: "#FFFFFF"
    rounded: "{rounded.control}"
    padding: "12px 16px"
    size: "min 64x52"
  button-secondary:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.carbon-deep}"
    rounded: "{rounded.control}"
    padding: "12px 16px"
  button-danger:
    backgroundColor: "{colors.danger-red}"
    textColor: "#FFFFFF"
    rounded: "{rounded.control}"
  keypad-key:
    backgroundColor: "#FFFFFF"
    textColor: "{colors.carbon-deep}"
    rounded: "{rounded.button}"
    size: "72px tall"
  card:
    backgroundColor: "#FFFFFF"
    textColor: "{colors.carbon-deep}"
    rounded: "{rounded.card}"
  name-row:
    backgroundColor: "transparent"
    textColor: "{colors.carbon-deep}"
    rounded: "0"
    height: "48px min"
  chip:
    backgroundColor: "#FFFFFF"
    textColor: "{colors.carbon-deep}"
    rounded: "{rounded.control}"
    padding: "10px 12px"
---

# Design System: CricScore

## Overview

**Creative North Star: "The Umpire's Scoreboard, In Sunlight"**

CricScore is an arcade scoreboard that happens to be a phone app. It is used outdoors,
standing, at arm's length, by one person who is simultaneously watching a ball and being
asked for the score. Every visual decision answers that scene: solid saturated fills
instead of tints, near-black or white text instead of greys, and numerals large enough to
read from a metre away. The interface is loud where the match is loud (boundaries, wickets,
the hero score) and deliberately silent everywhere else — settings, rosters and archives
are dense, plain, and free of ornament.

The register is **Operate**, not Persuade. There is no marketing surface, no onboarding
carousel, no imagery. Density is high and consistent: rows, not cards-within-cards; one
heading per group; hairline separators; no gradient, no glass, no blur. Personality comes
from the scoreboard itself — the hero tile, the coloured ball badges, the celebration
modes — never from chrome around it.

The system is offline-first and glare-first by rule: all fonts and sounds are bundled,
nothing is fetched at runtime, and no screen may rely on contrast that a phone screen loses
in direct sun.

**Key Characteristics:**
- Solid saturated fills, near-black/white text, no pastels, no low-contrast grey body copy.
- Names are rows, never pills; controls are 8px rectangles, never pills; only badges and
  avatars are circles.
- One deliberate exception to the rectangle rule: the innings switcher pill is a 12px slab.
- Motion is layout-frozen: numerals animate with Transform/Opacity/ShaderMask only.
- Every interactive target is at least 48dp; every icon-only control has a tooltip.
- One coherent screen-reader sentence per scoreboard, not a pile of bare numerals.

## Colors

A saturated arcade palette on a near-white/near-black neutral base: the colour is spent on
match events, and the surface stays out of the way.

### Primary

- **Umpire Blue** (#1D4ED8): the default hero tile and the colour of every "you must do
  something" card (set batters, select new bowler, restored-from-backup). It is the app's
  one loud informational colour.
- **Carbon Ink** (#131316): the primary action fill, the selected chip fill, the selected
  name-row fill, and the dot-ball badge. It is the "chosen / go" colour in a control and
  the "nothing happened" colour on the field.

### Secondary

- **Wicket Crimson** (#DC143C): wickets and `W+n` run-out badges, and nothing else.
- **Six Magenta** (#EC008C): a six. **Four Green** (#15803D): a four. These two never appear
  outside a boundary badge or its celebration tint.
- **Wide Amber** (#FFBA08): wides, and the armed no-ball keypad state. **No-Ball Purple**
  (#7B2CBF): no-balls and the "NB ARMED" caption.
- **Bye Cyan** (#00B4D8): byes and leg-byes.

### Tertiary

- **Success Green** (#22C55E): a positive derived figure — wickets in a bowling row, the
  selected radio in a name picker.
- **Economy Amber** (#F59E0B): the economy readout on bowling figures. Small, specific,
  and the only place amber is used as a value colour.
- **Muted Slate** (#94A3B8): placeholder glyphs inside an empty code field only.

### Neutral

- **Paper** (#FAFAFA): light scaffold. **Card White** (#FFFFFF): light card fill.
- **Night** (#0B0B0D): dark scaffold. **Surface Night** (#131316): dark card fill.
- **Carbon Deep** (#0A0A0A): light-mode onSurface. **White**: dark-mode onSurface.
- **Hairline** (#E2E2E2) / **Hairline Dark** (#2E2E33): the 1px card border and row
  separators. Separators sit at 50% alpha so dense tables never look ruled.

### Named Rules

**The Sunlight Rule.** Every fill is a solid saturated colour carrying white or near-black
text. No pastels, no 20%-alpha tint as the only signal, no grey-on-grey. If a state can only
be read by a subtle shade change, it is wrong.

**The Event Colour Rule.** Crimson, magenta, green, amber, purple and cyan mean a cricket
event. They are never used for decoration, headings, or generic emphasis.

## Typography

**Display Font:** the user's chosen score face — ten bundled OFL families exposed through
`ScoreFonts` (Stadium Sans, Condensed Punch, Block Heavy, Mono Ledger, Tech Board, Tall
Ticket, Ultra Slab, Wide Circuit, Broadcast, Narrow Board).
**Body Font:** platform default (Roboto on Android), bundled and offline.
**Label Font:** the same default, forced to w900 with wide tracking.

**Character:** a heavy grotesque for structure and an outsized, tabular, switchable numeral
face for the score. The UI never competes with the numerals: labels are small, tracked and
uppercase; the score is the largest thing on any screen.

### Hierarchy

- **Display Score** (w900, 68px, line-height 1.05, tabular figures): the runs/wickets pair on
  the hero tile, scored in the user's chosen face. Never smaller than 52px; never wrapped.
- **Code Entry** (w900, 28px, 10px tracking): the five-character room code field, sized for
  one-handed typing while somebody reads the code aloud.
- **Headline** (w900, 16px): sheet titles and empty-state headlines, uppercase.
- **Title** (w800, 15px): a person's name in a list row, a team name on a pill.
- **Body** (w400–w700, 13px): supporting copy, card text, list subtitles at 12px.
- **Label** (w900, 9–11px, 1.2–2px tracking, uppercase): stat captions, section bands,
  `OV`/`ECON`/`MATCHES`-style micro-labels, and keypad key subtitles at 9px.

### Named Rules

**The One Numeral Rule.** Tabular figures on every number that can change while it is on
screen (`FontFeature.tabularFigures()`), so a live score, overs count or economy never
jitters as digits change.

**The Smaller-Than-Content Ban.** A section heading is never smaller or lighter than the
rows it introduces. Group labels are uppercase w900 with tracking, or a filled colour band
— never a 11px grey line above 14px bold names.

## Layout

Portrait only, one-handed, single column. Content is centred in a `ResponsiveCenter` capped
at **560dp** (640dp on the scoring and scorecard screens) so a tablet or the Linux desktop
preview shows the same phone-shaped column rather than a stretched grid.

- Page padding: 12dp on dense live screens, 16dp on home/history, 20dp inside sheets.
- Vertical rhythm is an 8dp base with 4/6 for in-row gaps: 4, 6, 8, 10, 12, 16, 20, 24.
- Cards stack with 10dp between them; rows inside a card use hairline separators and no
  outer margin.
- The keypad is a fixed 3-column grid at 1.5 aspect ratio; keys are 72dp tall so a thumb
  can hit them without looking. It sits at the bottom, in reach.
- The over strip is a fixed **246dp** window showing exactly six balls — never a
  half-peeking seventh — with the over summary scaling down beside it rather than pushing
  the row past the card.
- Long text never forces a layout change: names ellipsize first, figures use `FittedBox`.

## Elevation & Depth

Depth is hairline-led, not shadow-led. Every card carries Material elevation **2** with a
1px border (`#E2E2E2` light, `#2E2E33` dark) and no visible drop shadow. The border does the
work the shadow would do, because a soft shadow disappears in sunlight while a hairline
still reads. Sheets are the only surfaces that float, and they float by scrim and position,
not by blur or translucency. There is no glassmorphism, no gradient, and no tonal ladder
beyond scaffold → card → inverted card.

### Named Rules

**The Border-Not-Shadow Rule.** A new surface gets a 1px border before it gets a shadow.
Nothing in this app is distinguished by blur.

## Shapes

Rectangular and decisive. Controls are **8px** rectangles; primary buttons are **14px**;
cards are **16px**; the style preset carries its own keypad radius (6–14px) so the arcade
presets can read as CRT or cabinet hardware. Full-round shapes are reserved for two things:
**36dp circle ball badges** and **circular initials avatars / team dots**. Nothing else is a
pill — not names, not tabs, not filters. The one sanctioned slab is the innings switcher
(12px) because it is a segmented control, not a chip.

## Components

### Buttons

- **Shape:** 8px rectangle (`RectBtn`), 14px for preset-driven keypad keys.
- **Primary:** Carbon Ink fill, white w800 text, min 64×52, 12/16 padding.
- **Secondary:** card fill with a 1.5px **black** border and dark text — an outline, not a
  tint.
- **Danger:** `danger-red` fill, white text.
- **Press:** feedback lands on **pointer-down** with an immediate 75–80% black overlay, not a
  ripple. A ripple is invisible in direct sun.
- **Disabled:** 45% opacity via the row/pill wrapper; the reason is always written in the
  subtitle ("XI full (11)", "just bowled").

### Chips

- **Style:** 8px rectangle, 12/10 padding for a 44dp+ target, outline border, w800 label.
- **Selected:** Carbon Ink fill with white text. Selection is a fill, never a tint.
- Chips are for **non-name toggles only** — dismissals, styles, celebration modes. A person
  is never a chip.

### Cards / Containers

- **Corner:** 16px. **Border:** 1px hairline. **Elevation:** 2, no visible shadow.
- **Padding:** 12dp on live screens, 16–20dp elsewhere.
- **Inverted cards** (Carbon Ink fill, white text) are reserved for the live "act now" strip:
  innings break countdown, match over countdown.

### Inputs / Fields

- Outline border, 8px radius, dense where it sits in a row.
- Every field carries a **persistent** `labelText` (or a standalone heading immediately
  above it) — a placeholder is never the only label, because it vanishes the moment the user
  types.
- Multi-line and sheet fields add `viewInsets.bottom` padding so the keyboard never covers
  the field or its confirm button.

### Name rows

- **`PlayerRow`** (48dp min) and **`DetailRow`** (54dp min): name left in w800, quiet
  subtitle beneath, the value or affordance right.
- Selected = a solid Carbon Ink slab with white text (not a tint, not a checkmark alone).
- Disabled rows are dimmed **and** explain themselves in the subtitle.

### Navigation

- AppBar: uppercase w900 15px title, icon actions only, each with a tooltip.
- Tabs are underlined text (`UnderlineTabs`): the label reads as a heading, a 2.5px rule
  marks the open one, and nothing moves when the selection changes.
- Page transitions are intentionally **instant** (no slide/fade) so route changes never
  animate against a live scoreboard, celebration or strip glide. Sheets use a 280ms
  ease-out settle, collapsing to 120ms when reduced motion is requested.

### Scoreboard (signature)

The hero tile is the product. Solid preset fill, four hairline registration crosses in the
corners, team dot + uppercase team name in a 20px chip, then the 68px runs/wickets pair,
then a hairline, then a three-up stat row (OVERS / CRR / EXTRAS). Tapping it swaps the stat
row for the chase line (TARGET / NEED n OFF n · RRR) for four seconds, in place, with no
layout shift outside the card. For assistive technology the whole tile is **one** semantic
node announcing team, score, overs, run rate, free-hit state and chase requirement, with a
hint telling the user the tile can be double-tapped.

### Ball badges (signature)

36dp circles, solid fill, white or black numeral, **no borders, no glow, no scale, no
corner markers** — all six balls in an over look structurally identical so the *colour*
carries the meaning. Ordered by impact: wicket crimson > six magenta > four green >
no-ball purple > wide amber > bye cyan > dot carbon > runs by cyan depth.

## Do's and Don'ts

### Do:

- **Do** give every icon-only control a `tooltip` (it is also its screen-reader label) and a
  48dp minimum target.
- **Do** express selection as a solid fill with white text, at w800 or heavier.
- **Do** keep names as rows and controls as 8px rectangles; use circles only for badges,
  dots and avatars.
- **Do** add `FittedBox(fit: BoxFit.scaleDown)` around any fixed-height/fixed-width text
  block (keypad keys, hero numerals, pill figures) so a 2× system text size shrinks instead
  of overflowing.
- **Do** wrap a multi-number readout in a single `Semantics(excludeSemantics: true, label:)`
  with a sentence a person would say out loud.
- **Do** confirm every destructive action in the archives, and name what is *not* deleted.
- **Do** keep celebrations inside Transform, Opacity, ShaderMask, text colour/shadow and
  Positioned overlays; honour `MediaQuery.disableAnimationsOf`.

### Don't:

- **Don't** introduce a pastel, a 20%-tint state, or grey-on-grey body text; that is the
  Sunlight Rule failing.
- **Don't** use crimson, magenta, green, amber, purple or cyan for anything that is not a
  cricket event.
- **Don't** add a page transition, hero animation or layout-size change to anything that
  moves on a live score.
- **Don't** put a stub where a bar is: no `resume()` after `stop()`, no placeholder assets,
  no runtime font or CDN fetch.
- **Don't** use a hint as a label, and don't hide the only explanation of a format inside a
  placeholder that disappears when typing.
- **Don't** add a new style preset, celebration or score font without wiring it into
  `StylePreset.presets` / `MatchStore.celebIds` / `ScoreFonts.ids` and the settings sheet in
  the same change.
