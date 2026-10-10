import 'package:flutter/material.dart';

import '../domain/players.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets.dart';
import 'summary.dart';

String fmt1(double? v) => v == null ? '—' : v.toStringAsFixed(1);
String fmt2(double? v) => v == null ? '—' : v.toStringAsFixed(2);

/// Striker / non-striker / bowler at a glance. Read-only numbers; the only
/// mutating controls are the pickers.
void showPlayerStatsSheet(BuildContext context, MatchStore store) {
  final sheet = store.currentSheet;
  if (sheet == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player tracking is off for this match')));
    return;
  }
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final s = store.currentSheet;
        if (s == null) return const SizedBox.shrink();
        final preset = StylePreset.of(store.styleId);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rowsHeader(preset, 'Batter', const ['R', 'B', '4s', '6s']),
                if (s.striker != null)
                  _batterRow(context, store, s, s.striker!, isStriker: true),
                if (s.nonStriker != null)
                  _batterRow(context, store, s, s.nonStriker!,
                      isStriker: false),
                const SizedBox(height: 6),
                _partnershipRow(s),
                const SizedBox(height: 10),
                _rowsHeader(preset, 'Bowler', const ['W-R', 'Ov', 'Econ']),
                if (s.currentBowler != null) _bowlerRow(s.currentBowler!),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RectBtn(
                        primary: false,
                        onTap: () {
                          Navigator.pop(context);
                          showSwapSheet(context, store);
                        },
                        child: const Text('SWAP ENDS'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RectBtn(
                        primary: false,
                        onTap: () {
                          Navigator.pop(context);
                          showBowlerSheet(context, store);
                        },
                        child: const Text('CHANGE BOWLER'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Column header row in preset colors: label left, stat titles right.
Widget _rowsHeader(StylePreset preset, String label, List<String> cols) {
  return Container(
    color: preset.heroBg,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: preset.heroFg,
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ),
        for (final c in cols)
          SizedBox(
            width: 44,
            child: Text(c,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: preset.heroFg.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w800,
                    fontSize: 11)),
          ),
      ],
    ),
  );
}

Widget _batterRow(
    BuildContext context, MatchStore store, InningsSheet s, BattingCard c,
    {required bool isStriker}) {
  final p = _playerOf(store, c.playerId);
  return InkWell(
    onLongPress: () => _retireDialog(context, store, c),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.name}${isStriker ? ' *' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                    'SR ${fmt1(c.strikeRate)}${p == null ? '' : ' | ${battingStyleLabel(p.battingStyle)}'}',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          for (final v in [
            '${c.runs}',
            '${c.balls}',
            '${c.fours}',
            '${c.sixes}'
          ])
            SizedBox(
              width: 44,
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight:
                          v == '${c.runs}' ? FontWeight.w900 : FontWeight.w700,
                      fontSize: v == '${c.runs}' ? 16 : 13)),
            ),
        ],
      ),
    ),
  );
}

/// Single-bowler row in the stats sheet: same shared rows as the scorecard,
/// so the two can never disagree on layout.
Widget _bowlerRow(BowlingCard b) => BowlerRows([b]);

Widget _partnershipRow(InningsSheet s) {
  final last = s.fallOfWickets.isEmpty ? null : s.fallOfWickets.last;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text("P'ship: ${s.partnershipRuns} (${s.partnershipBalls})",
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        if (last != null)
          Expanded(
            child: Text('Last wkt: ${last.name} ${last.runs} (${last.balls})',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

Player? _playerOf(MatchStore store, String id) {
  for (final p in store.roster) {
    if (p.id == id) return p;
  }
  return null;
}

/// Long-press a batter row to retire them. Hurt may return via the next-batter
/// picker; out never does.
void _retireDialog(BuildContext context, MatchStore store, BattingCard c) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('RETIRE ${c.name}?'),
      content: const Text(
          'Hurt can return later through the next-batter list. Out cannot.'),
      actions: [
        RectBtn(
          primary: false,
          onTap: () => Navigator.pop(context),
          child: const Text('Keep'),
        ),
        RectBtn(
          onTap: () {
            store.retireStriker(DismissalType.retiredHurt);
            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('Hurt'),
        ),
        RectBtn(
          danger: true,
          onTap: () {
            store.retireStriker(DismissalType.retiredOut);
            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('Out'),
        ),
      ],
    ),
  );
}

/// One-tap dismissal: type chips on top, next batter below. Tapping a name
/// commits the wicket AND the incoming batter in the same store call.
void showDismissalSheet(
    BuildContext context, MatchStore store, String wicketType) {
  final sheet = store.currentSheet;
  // Untracked matches keep the old instant behaviour.
  if (sheet == null) {
    store.score(action: 'WICKET', wicketType: wicketType);
    return;
  }
  var type = DismissalType.fromId(wicketType);
  String? fielder;
  String? newId;
  var crossed = false;
  var runOutRuns = 0;
  // Explicit exclusion: the out batter, the non-striker, the dismissed and
  // the retired-out never appear. Retired-hurt returnees do.
  final outId = sheet.strikerId ?? '';
  final waiting = sheet.nextBatterOptions(outId);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('OUT • ${sheet.nameOf(sheet.strikerId ?? '')}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in DismissalType.values)
                    if (d != DismissalType.retiredHurt &&
                        d != DismissalType.retiredOut)
                      ChoiceChip(
                        label: Text(d.label),
                        selected: type == d,
                        onSelected: (_) => setSheet(() {
                          type = d;
                          fielder = null;
                        }),
                      ),
                ],
              ),
              if (store.askFielder && type.hasFielder) ...[
                const SizedBox(height: 12),
                const Text('WHO TOOK IT? (optional)',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in sheet.bowling.keys)
                      if (id != sheet.strikerId)
                        ChoiceChip(
                          label: Text(sheet.nameOf(id)),
                          selected: fielder == sheet.nameOf(id),
                          onSelected: (_) => setSheet(() {
                            fielder = fielder == sheet.nameOf(id)
                                ? null
                                : sheet.nameOf(id);
                          }),
                        ),
                  ],
                ),
              ],
              if (type == DismissalType.runOut) ...[
                const SizedBox(height: 8),
                const Text('RUNS COMPLETED',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i <= 3; i++)
                      ChoiceChip(
                        label: Text('$i'),
                        selected: runOutRuns == i,
                        onSelected: (_) => setSheet(() => runOutRuns = i),
                      ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(
                        child: Text('Batters crossed?',
                            style: TextStyle(fontSize: 12))),
                    Switch(
                        value: crossed,
                        onChanged: (v) => setSheet(() => crossed = v)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Text('NEXT BATTER',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              if (waiting.isEmpty)
                const Text('No batters left.', style: TextStyle(fontSize: 12)),
              for (final id in waiting)
                Builder(builder: (_) {
                  final returning = (sheet.batting[id]?.position ?? 0) > 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RectBtn(
                      primary: newId == id,
                      onTap: () {
                        final runs =
                            type == DismissalType.runOut ? runOutRuns : 0;
                        Navigator.pop(sheetCtx);
                        final label = _wicketLabel(type);
                        final err = store.score(
                          action: 'WICKET',
                          runs: runs,
                          wicketType: label,
                          dismissal: type.name,
                          fielderName: fielder,
                          newBatterId: id,
                          crossed: crossed,
                        );
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                      child: Text(returning
                          ? '${sheet.nameOf(id)} (returning)'
                          : sheet.nameOf(id)),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    ),
  );
}

String _wicketLabel(DismissalType t) => switch (t) {
      DismissalType.bowled => 'Bowled',
      DismissalType.caught => 'Caught',
      DismissalType.lbw => 'LBW',
      DismissalType.stumped => 'Stumped',
      DismissalType.hitWicket => 'Hit Wicket',
      DismissalType.runOut => 'Run Out',
      DismissalType.obstructing => 'Obstructing the field',
      DismissalType.retiredHurt => 'Retired Hurt',
      DismissalType.retiredOut => 'Retired Out',
    };

/// Bowler picker with live figures. The just-bowled bowler is excluded by law.
void showBowlerSheet(BuildContext context, MatchStore store,
    {bool auto = false}) {
  final sheet = store.currentSheet;
  if (sheet == null) return;
  // Candidates are the BOWLING side's squad in XI order — never the batters.
  // (The bowling map holds every registered player, so reading its keys
  // showed batting names as bowlers.)
  final m = store.match!;
  final squadIds =
      sheet.bowlingTeam == m.config.teamA ? m.config.squadA : m.config.squadB;
  final inXi = squadIds.isEmpty
      ? sheet.bowling.keys.toList()
      : [
          for (final id in squadIds)
            if (sheet.bowling.containsKey(id)) id
        ];
  // Anyone who already bowled but is not in the XI (mid-match squad edits)
  // stays visible rather than vanishing.
  final candidates = [
    ...inXi,
    for (final id in sheet.bowling.keys)
      if (!inXi.contains(id) &&
          (sheet.bowling[id]!.balls > 0 || sheet.bowling[id]!.wickets > 0))
        id,
  ];
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(auto ? 'OVER DONE — NEXT BOWLER' : 'CHANGE BOWLER',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Tap a name; they bowl the whole over.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            for (final id in candidates)
              Builder(builder: (_) {
                final c = sheet.bowling[id]!;
                final allowed = sheet.canBowl(id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RectBtn(
                    primary: false,
                    onTap: allowed
                        ? () {
                            final err = store.setBowler(id);
                            if (err != null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(err)));
                              return;
                            }
                            Navigator.pop(context);
                          }
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(
                                '${c.name}${allowed ? "" : " (just bowled)"}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        Text(
                            '${c.oversDisplay}-${c.maidens}-${c.runsConceded}-${c.wickets}  Econ ${fmt2(c.economy)}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    ),
  );
}

/// Openers + first bowler, picked once per innings when tracking is on.
void showInningsStartSheet(BuildContext context, MatchStore store) {
  final sheet = store.currentSheet;
  if (sheet == null) return;
  final batting = [for (final p in store.squadForTeam(sheet.battingTeam)) p];
  final bowling = [for (final p in store.squadForTeam(sheet.bowlingTeam)) p];
  String? a;
  String? b;
  String? bowl;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('START INNINGS • ${sheet.battingTeam}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('STRIKER',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in batting)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: a == p.id,
                      onSelected: (_) => setSheet(() => a = p.id),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('NON-STRIKER',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in batting)
                    if (p.id != a)
                      ChoiceChip(
                        label: Text(p.name),
                        selected: b == p.id,
                        onSelected: (_) => setSheet(() => b = p.id),
                      ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('OPENING BOWLER',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in bowling)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: bowl == p.id,
                      onSelected: (_) => setSheet(() => bowl = p.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              RectBtn(
                onTap: (a != null && b != null && bowl != null)
                    ? () {
                        store.setOpeners(a!, b!);
                        store.setBowler(bowl!);
                        Navigator.pop(sheetCtx);
                      }
                    : null,
                child: const Text('START'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void showSwapSheet(BuildContext context, MatchStore store) {
  final sheet = store.currentSheet;
  if (sheet == null) return;
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('SWAP ENDS?'),
      content: Text(
          '${sheet.nameOf(sheet.strikerId ?? '')} ★ ⇄ ${sheet.nameOf(sheet.nonStrikerId ?? '')}'),
      actions: [
        RectBtn(
          primary: false,
          onTap: () => Navigator.pop(context),
          child: const Text('Keep'),
        ),
        RectBtn(
          onTap: () {
            store.swapStrike();
            Navigator.pop(context);
          },
          child: const Text('Swap'),
        ),
      ],
    ),
  );
}
