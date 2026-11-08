---
name: flutter-clean-ui
description: Use whenever creating, modifying, or redesigning Flutter UI screens, widgets, buttons, or lists in CricScore.
---

# CricScore Clutter-Free UI Rules (softer rule, glare-first kept)

## 1. Tokens first
- New UI reads `context.spacing` (4/8/16/24/32 grid), `context.colors`
  (Material 3 `ColorScheme`), and `context.textStyles` — never a fresh raw
  `Color(0xFF…)` or `EdgeInsets.all(<raw>)` in a screen file.
- Saturated glare-proof fills live in `StylePreset` + `DesignTokens`
  (`theme.dart` / `app_tokens.dart`). Screens reference them as data;
  they never invent a new hex value inline.
- `theme.dart` and `app_tokens.dart` are the only files that may hold
  raw `Color(` literals.

## 2. Clutter-free, sunlight-first
- Prefer flat surfaces with a 1px border (`outlineVariant` at 0.5 alpha)
  over heavy shadows (`elevation: 0`) — **except** where glare-first wins:
  scoreboard hero, keypad primaries, and result primary stay solid black/
  saturated so they read in direct sun.
- Max 3 data points per tile/card. One innings at a time on the scorecard.
- Animations stay layout-frozen: `Transform`/`Opacity`/`ShaderMask` only.

## 3. Atomic extraction
- No `build()` over ~60 lines without a private widget extract
  (`StatelessWidget` with `const` ctor, same file or `widgets.dart`).
- Never `Widget _buildX()` helpers; use widget classes for diffing.
- `RectBtn` is the reference button (FilledButton, `radiusMd`, `labelLarge`
  600, single-line clamp, 48dp target).

## 4. Responsiveness
- `MediaQuery.sizeOf(context)` over `MediaQuery.of(context).size`.
- Dynamic text in a `Row` gets `Expanded`/`Flexible` with
  `maxLines: 1, overflow: TextOverflow.ellipsis` (already the `RectBtn` clamp).
- Buttons never wrap mid-word: clamp, don't stack.

## 5. MCP + skills
- Dart MCP (`dart mcp-server` in `opencode.jsonc`) is dev-only; the APK
  stays 100% offline with no network permission.
- Prefer official flutter-*/dart-* skills for responsive layout,
  widget previews, and static analysis over hand-rolled patterns.
