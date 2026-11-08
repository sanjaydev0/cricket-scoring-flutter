# Design Tokens + MCP + Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ThemeExtension tokens + Dart MCP + official skills with a softer, glare-first rule, migrating Home and Result first.

**Architecture:** Tokens in `lib/core/theme/app_tokens.dart` wired into both `UmpireTheme` builders; dev-loop MCP/skills in `opencode.jsonc`/`.agents/`; `check-master.sh` grep gate blocks new raw styling in screens. No app network code.

**Tech Stack:** Flutter 3.47.7, Dart 3.13.5, Material 3 `ThemeExtension`, Dart MCP (`dart mcp-server`), official Flutter/Dart agent skills.

**Spec:** Chat design approved 2026-11-08: Option B, softer rule, StylePreset stays as data, Home+Result migrate first, 2.27.0 stays.

## Global Constraints

- 100% offline app: MCP/skills are dev-only; APK has no network permission.
- Glare-first: saturated fills, near-black/white text; never flat subtle borders that wash out in sun.
- Animation primitives stay layout-frozen (`Transform`/`Opacity` only).
- `APP.md` < 1,000 words, version line matches `pubspec.yaml`.
- `flutter analyze --no-pub` clean; targeted tests per task; full suite final.

## Review Focus

- `ThemeExtension.lerp` must not return `this` (breaks tweens) — return `other` interpolation.
- Grep gate must not false-positive on `theme.dart`/`widgets.dart`/`app_tokens.dart` itself.
- MCP/skills install must not break `opencode.jsonc` parsing or add app dependencies.
- `RectBtn` token refactor must keep single-line clamp + 48dp target (a11y/layout tests).
- Result CTA after migration must still be primary REMATCH + 2 secondaries, single-line.

---

### Task 1: Design tokens core

**Files:**
- Create: `lib/core/theme/app_tokens.dart`
- Modify: `lib/theme.dart:236-340`
- Test: `test/design_test.dart` (append token assertions)

**Interfaces:**
- Consumes: `ThemeData.extensions`, `ColorScheme`, existing `StylePreset` values
- Produces: `AppSpacing extends ThemeExtension<AppSpacing>` (xs/sm/md/lg/xl/radiusSm/radiusMd/radiusLg), `DesignTokens` (hero/surface alias), `ThemeContextExtension` (`theme/colors/textStyles/spacing`)

- [ ] Write test asserting `Theme.of(widget).extension<AppSpacing>()` returns 4/8/16/24/32 and `lerp` interpolates.
- [ ] Run `flutter test --no-pub --reporter compact test/design_test.dart --plain-name "tokens"` → FAIL.
- [ ] Implement `AppSpacing` + extensions in `app_tokens.dart`; wire `extensions: const [AppSpacing()]`? Actually `ThemeData(extensions: [const AppSpacing()])`? Use `AppSpacing()` const instance in both light/dark; expose `context.spacing`.
- [ ] Run tests → PASS. Commit `feat: add AppSpacing ThemeExtension tokens`.

### Task 2: MCP + skills wiring

**Files:**
- Modify: `opencode.jsonc`
- Create: `.agents/skills/flutter-clean-ui/SKILL.md`
- Run: `npx skills add` for flutter + dart skills

**Interfaces:**
- Consumes: Task 1 tokens
- Produces: `opencode.jsonc` `mcpServers.dart` entry; `.agents/skills/` populated

- [ ] Add `mcpServers.dart {command: dart, args: [mcp-server]}` to `opencode.jsonc`.
- [ ] Run `npx skills add flutter/agent-plugins --skill '*' --agent universal --yes` and `npx skills add dart-lang/skills --skill '*' --agent universal --yes`.
- [ ] Write `SKILL.md` (softer rule, glare-first exception, atomic widgets, ellipsis rules).
- [ ] Verify `dart mcp-server --help` (or at least `dart --version`) resolves; note any login need. Commit `chore: wire Dart MCP + Flutter skills`.

### Task 3: AGENTS.md rule + grep gate

**Files:**
- Modify: `AGENTS.md` (clean-ui section), `tool/check-master.sh`
- Test: manual `bash tool/check-master.sh`

- [ ] Append clean-ui rule to `AGENTS.md` (softer rule wording).
- [ ] Extend `check-master.sh` to grep `Color(0x` / `EdgeInsets.all([0-9]` / `TextStyle(` in `lib/screens` excluding allowed files; fail with file:line.
- [ ] Run `bash tool/check-master.sh` → PASS on current tree (waive Home/Result pending migration via allowlist entry removed in Task 4) or explicitly scope gate to new-code check. Commit `chore: add clean-ui grep gate`.

### Task 4: Home + Result onto tokens

**Files:**
- Modify: `lib/screens/widgets.dart` (RectBtn), `lib/screens/home.dart`, `lib/screens/break_result.dart`
- Test: `test/screens_layout_test.dart` (single-line + primary assertions already cover; run)

- [ ] Refactor `RectBtn` padding/radius/text to `context.spacing`/`context.textStyles.labelLarge`; keep colors via `context.colors` + preset data.
- [ ] Migrate Home card padding + button gaps to `context.spacing`; Result CTA gaps likewise.
- [ ] Remove Home/Result from check-master allowlist; run `bash tool/check-master.sh` → PASS.
- [ ] Run `flutter test` layout suite → PASS. Commit `refactor: migrate Home+Result to tokens`.

### Task 5: Verify + push + install

- [ ] `flutter analyze --no-pub`, full `flutter test --no-pub`, `bash tool/check-master.sh`.
- [ ] `git push origin HEAD:main`, `./tool/fast-install.sh RZCRC04358J`, confirm `STORE:` boot line.
