import 'package:flutter/material.dart';

import '../domain/players.dart';
import '../store.dart';
import 'widgets.dart';

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
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('PLAYERS',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _batterCard(context, store, s, s.striker, isStriker: true),
                const SizedBox(height: 8),
                _batterCard(context, store, s, s.nonStriker, isStriker: false),
                const SizedBox(height: 8),
                _bowlerCard(context, store, s),
                const SizedBox(height: 8),
                Text('Partnership ${s.partnershipRuns} (${s.partnershipBalls})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
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

Widget _batterCard(
    BuildContext context, MatchStore store, InningsSheet s, BattingCard? c,
    {required bool isStriker}) {
  if (c == null) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(isStriker ? 'No striker set' : 'No non-striker set'),
      ),
    );
  }
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    '${isStriker ? 'STRIKER ★ ' : ''}${c.name.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Text('${c.runs} (${c.balls})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              '4s ${c.fours} • 6s ${c.sixes} • Dots ${c.dots} • SR ${fmt1(c.strikeRate)}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

Widget _bowlerCard(BuildContext context, MatchStore store, InningsSheet s) {
  final b = s.currentBowler;
  if (b == null) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('No bowler set'),
            const SizedBox(height: 8),
            RectBtn(
              onTap: () {
                Navigator.pop(context);
                showBowlerSheet(context, store);
              },
              child: const Text('SET BOWLER'),
            ),
          ],
        ),
      ),
    );
  }
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('BOWLER ${b.name.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Text(
                  '${b.oversDisplay}-${b.maidens}-${b.runsConceded}-${b.wickets}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'Wd ${b.wides} • Nb ${b.noBalls} • Econ ${fmt2(b.economy)} • This over ${b.overBalls} balls',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
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
  final waiting = sheet.waitingBatters;
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
                Padding(
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
                    child: Text(sheet.nameOf(id)),
                  ),
                ),
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
  final candidates = sheet.bowling.keys.toList();
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
                            store.setBowler(id);
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
