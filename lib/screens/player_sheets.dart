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
  // Run-out can dismiss either end. Choosing the end is what decides whether
  // the batters crossed, so there is no separate toggle to mistap.
  var outAtNonStrikerEnd = false;
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
                Builder(builder: (_) {
                  // Fielders come from the FIELDING (bowling) side's squad in
                  // XI order — the bowling map holds every registered player,
                  // so its keys showed batters as fielders.
                  final m = store.match!;
                  final squadIds = sheet.bowlingTeam == m.config.teamA
                      ? m.config.squadA
                      : m.config.squadB;
                  final ids = squadIds.isEmpty
                      ? sheet.bowling.keys
                          .where((id) => id != sheet.strikerId)
                          .toList()
                      : squadIds.where((id) => id != sheet.strikerId).toList();
                  return Column(
                    children: [
                      for (final id in ids)
                        InkWell(
                          onTap: () => setSheet(() {
                            fielder = fielder == sheet.nameOf(id)
                                ? null
                                : sheet.nameOf(id);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(sheet.nameOf(id),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                Icon(
                                  fielder == sheet.nameOf(id)
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: fielder == sheet.nameOf(id)
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }),
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
                const RowSectionLabel('WHICH BATTER IS OUT?',
                    color: Color(0xFFDC143C)),
                PlayerRow(
                  name: sheet.nameOf(sheet.strikerId ?? ''),
                  subtitle: "Facing, at the striker's end",
                  selected: !outAtNonStrikerEnd,
                  onTap: () => setSheet(() => outAtNonStrikerEnd = false),
                ),
                PlayerRow(
                  name: sheet.nameOf(sheet.nonStrikerId ?? ''),
                  subtitle: "At the non-striker's end",
                  selected: outAtNonStrikerEnd,
                  onTap: () => setSheet(() => outAtNonStrikerEnd = true),
                ),
                const SizedBox(height: 6),
                Text(
                  outAtNonStrikerEnd
                      ? "Non-striker out — the batters crossed, so the new batter takes the striker's end."
                      : 'Striker out. Ends change only if an odd number of runs was completed.',
                  style: const TextStyle(fontSize: 11),
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
                      primary: false,
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
                          outAtNonStrikerEnd: outAtNonStrikerEnd,
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
            if (sheet.lastBowlerId != null) ...[
              const SizedBox(height: 4),
              Text(
                  'Prev: ${sheet.nameOf(sheet.lastBowlerId!)} (${_oversBowled(sheet, sheet.lastBowlerId!)} overs)',
                  style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 4),
            const Text('Tap a name; they bowl the whole over.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            for (final id in candidates)
              Builder(builder: (_) {
                final c = sheet.bowling[id]!;
                final allowed = sheet.canBowl(id);
                return PlayerRow(
                  name: c.name,
                  selected: false,
                  enabled: allowed,
                  blockedReason: allowed
                      ? null
                      : sheet.bowlBlockReason(id) ?? 'unavailable',
                  subtitle: bowlerFigureLine(c),
                  trailing: BowlerFigureBlock(c),
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
                );
              }),
          ],
        ),
      ),
    ),
  );
}

/// Who comes next — the only question a plain dismissal leaves open.
///
/// Bowled needs no runs count and no end choice, so the full dismissal sheet
/// was pure friction: seven wicket-type pills to answer a single question.
void showNextBatterSheet(BuildContext context, MatchStore store,
    {required String wicketType}) {
  final sheet = store.currentSheet;
  if (sheet == null) {
    store.score(action: 'WICKET', wicketType: wicketType);
    return;
  }
  final type = DismissalType.fromId(wicketType);
  final outId = sheet.strikerId ?? '';
  final waiting = sheet.nextBatterOptions(outId);
  final outName = sheet.nameOf(outId);
  String? fielder;

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
              Text('$outName — ${type.label.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const RowSectionLabel('NEXT BATTER', color: Color(0xFF1D4ED8)),
              if (waiting.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child:
                      Text('No batters left.', style: TextStyle(fontSize: 12)),
                )
              else
                for (final id in waiting)
                  Builder(builder: (_) {
                    final returning = (sheet.batting[id]?.position ?? 0) > 0;
                    return PlayerRow(
                      name: sheet.nameOf(id),
                      subtitle: returning
                          ? 'Retired hurt — coming back in'
                          : 'Yet to bat • ${sheet.battingTeam}',
                      selected: false,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        final err = store.score(
                          action: 'WICKET',
                          wicketType: wicketType,
                          dismissal: type.name,
                          fielderName:
                              fielder == null ? null : sheet.nameOf(fielder!),
                          newBatterId: id,
                        );
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(err)));
                        }
                      },
                    );
                  }),
              if (store.askFielder && type.hasFielder) ...[
                const RowSectionLabel('WHO TOOK IT? (optional)',
                    color: Color(0xFFDC143C)),
                for (final id in _fieldingIds(store, sheet))
                  PlayerRow(
                    name: sheet.nameOf(id),
                    subtitle: sheet.bowlingTeam,
                    selected: fielder == id,
                    onTap: () =>
                        setSheet(() => fielder = fielder == id ? null : id),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Run-out: exactly two questions, no dismissal-type grid.
///
/// Opening the full dismissal sheet for a run-out buried both questions under
/// seven wicket-type pills. This sheet answers only what a run-out actually
/// needs: how many runs were completed, and which batter was out.
void showRunOutSheet(BuildContext context, MatchStore store) {
  final sheet = store.currentSheet;
  if (sheet == null) return;
  var runs = 0;
  var nonStrikerOut = false;
  // Stated separately from WHO is out. The two are independent: a non-striker
  // is often out at the striker's end, and a striker can be out at the
  // bowler's end. Asking both keeps the scorecard faithful to what happened
  // instead of inferring one from the other.
  var outAtStrikerEnd = true;
  String? fielder;

  final strikerName = sheet.nameOf(sheet.strikerId ?? '');
  final nonStrikerName = sheet.nameOf(sheet.nonStrikerId ?? '');
  final battingSide = sheet.battingTeam;
  final bowlingSide = sheet.bowlingTeam;

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
              const RowSectionLabel('RUN OUT', color: Color(0xFFDC143C)),
              const SizedBox(height: 6),

              const RowSectionLabel('1. RUNS COMPLETED'),
              for (final n in [0, 1, 2, 3])
                PlayerRow(
                  name: n == 0
                      ? 'No runs — out at his own end'
                      : '$n run${n == 1 ? '' : 's'} completed',
                  subtitle:
                      n == 0 ? 'Wicket only' : 'W$n — Wicket, $n runs added',
                  selected: runs == n,
                  onTap: () => setSheet(() => runs = n),
                ),

              const RowSectionLabel('2. WHO WAS DISMISSED?',
                  color: Color(0xFFDC143C)),
              PlayerRow(
                name: strikerName,
                subtitle: '$battingSide • facing the bowler',
                selected: !nonStrikerOut,
                onTap: () => setSheet(() => nonStrikerOut = false),
              ),
              PlayerRow(
                name: nonStrikerName,
                subtitle: '$battingSide • at the other end',
                selected: nonStrikerOut,
                onTap: () => setSheet(() => nonStrikerOut = true),
              ),

              const RowSectionLabel('3. WHICH END WAS HE OUT AT?',
                  color: Color(0xFFDC143C)),
              PlayerRow(
                name: 'Striker\'s end',
                subtitle: 'Where he was facing',
                selected: outAtStrikerEnd,
                onTap: () => setSheet(() => outAtStrikerEnd = true),
              ),
              PlayerRow(
                name: "Bowler's end",
                subtitle: 'Where his partner was',
                selected: !outAtStrikerEnd,
                onTap: () => setSheet(() => outAtStrikerEnd = false),
              ),
              const SizedBox(height: 6),
              // State the consequence so the choice is never a guess.
              Text(
                outAtStrikerEnd
                    ? "Out at the striker's end — the new batter takes that end and faces next."
                    : "Out at the bowler's end — the new batter fills that gap and ${nonStrikerOut ? nonStrikerName : strikerName} keeps his end and stays on strike.",
                style: const TextStyle(fontSize: 11),
              ),

              if (store.askFielder) ...[
                const RowSectionLabel('WHO TOOK IT? (optional)',
                    color: Color(0xFFDC143C)),
                for (final id in _fieldingIds(store, sheet))
                  PlayerRow(
                    name: sheet.nameOf(id),
                    subtitle: bowlingSide,
                    selected: fielder == id,
                    onTap: () =>
                        setSheet(() => fielder = fielder == id ? null : id),
                  ),
              ],

              const SizedBox(height: 14),
              RectBtn(
                onTap: () {
                  Navigator.pop(sheetCtx);
                  final err = store.score(
                    action: 'WICKET',
                    runs: runs,
                    wicketType: 'Run Out',
                    dismissal: DismissalType.runOut.name,
                    fielderName:
                        fielder == null ? null : sheet.nameOf(fielder!),
                    outAtNonStrikerEnd: nonStrikerOut,
                    outAtStrikerEnd: outAtStrikerEnd,
                  );
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                child:
                    Text('${nonStrikerOut ? nonStrikerName : strikerName} OUT'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Fielding side's XI, for the optional fielder credit.
List<String> _fieldingIds(MatchStore store, InningsSheet sheet) {
  final m = store.match!;
  final ids =
      sheet.bowlingTeam == m.config.teamA ? m.config.squadA : m.config.squadB;
  return [
    for (final id in ids)
      if (id != sheet.strikerId && id != sheet.nonStrikerId) id
  ];
}

/// Openers + first bowler, picked once per innings when tracking is on.
String _oversBowled(InningsSheet sheet, String id) {
  final c = sheet.bowling[id];
  if (c == null) return '0';
  return '${c.balls ~/ 6}.${c.balls % 6}';
}

void showInningsStartSheet(BuildContext context, MatchStore store) {
  final sheet = store.currentSheet;
  if (sheet == null) return;
  final batting = [for (final p in store.squadForTeam(sheet.battingTeam)) p];
  final bowling = [for (final p in store.squadForTeam(sheet.bowlingTeam)) p];
  String? a;
  String? b;
  String? bowl;
  // The first two who have not batted are the sensible defaults, but nothing
  // is pre-committed: a wrong auto-picked striker silently corrupts figures,
  // so START stays disabled until all three are chosen on purpose.
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('START INNINGS • ${sheet.battingTeam}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                const Text('Pick the two batters and the opening bowler.',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                _pickGroup(
                  label: 'STRIKER — FACING',
                  accent: const Color(0xFF1D4ED8),
                  people: batting,
                  selected: a,
                  enabledFor: (p) => true,
                  emptyNote:
                      'No squad for ${sheet.battingTeam} — add players mid-match.',
                  onPick: (p) => setSheet(() {
                    a = p.id;
                    if (b == p.id) b = null; // never both ends the same batter
                  }),
                ),
                _pickGroup(
                  label: 'NON-STRIKER',
                  accent: const Color(0xFF0F766E),
                  people: batting,
                  selected: b,
                  enabledFor: (p) => p.id != a,
                  emptyNote: null,
                  onPick: (p) => setSheet(() => b = p.id),
                ),
                _pickGroup(
                  label: 'OPENING BOWLER',
                  accent: const Color(0xFFDC143C),
                  people: bowling,
                  selected: bowl,
                  enabledFor: (p) => true,
                  emptyNote:
                      'No squad for ${sheet.bowlingTeam} — add players mid-match.',
                  onPick: (p) => setSheet(() => bowl = p.id),
                ),
                const SizedBox(height: 14),
                RectBtn(
                  onTap: (a != null && b != null && bowl != null)
                      ? () {
                          store.setOpeners(a!, b!);
                          store.setBowler(bowl!);
                          Navigator.pop(sheetCtx);
                        }
                      : null,
                  child: Text(a == null || b == null || bowl == null
                      ? 'PICK ALL THREE'
                      : 'START INNINGS'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// One labelled group of name rows. Names are rows, never pills — a wrapped
/// row of chips on a phone hides whole squads behind a scroll.
Widget _pickGroup({
  required String label,
  required Color accent,
  required List<Player> people,
  required String? selected,
  required bool Function(Player) enabledFor,
  required void Function(Player) onPick,
  String? emptyNote,
  void Function()? onReopen,
}) {
  // Once a pick is made, show only that pick: this sheet is three choices, so
  // a full roster of names that cannot be selected is just noise. Tapping the
  // chosen row reopens the list to change it.
  final chosen = selected == null
      ? null
      : [
          for (final p in people)
            if (p.id == selected) p
        ];
  final shown = chosen ?? people;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RowSectionLabel(label, color: accent, filled: true),
      if (people.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(emptyNote ?? 'No players.',
              style: const TextStyle(fontSize: 12)),
        )
      else
        for (final p in shown)
          PlayerRow(
            name: p.name,
            subtitle: chosen != null
                ? 'Tap to change'
                : '${battingStyleLabel(p.battingStyle)} • ${bowlingStyleLabel(p.bowlingStyle)}',
            selected: selected == p.id,
            enabled: enabledFor(p),
            blockedReason: enabledFor(p) ? null : 'already the striker',
            onTap: chosen != null
                ? () {
                    onReopen?.call();
                    onPick(p);
                  }
                : () => onPick(p),
          ),
    ],
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
