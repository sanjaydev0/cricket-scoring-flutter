import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/players.dart';
import '../models.dart';
import '../store.dart';
import 'widgets.dart';

/// Shared scorecard + awards, used by the break screen (first innings) and the
/// result screen (both innings). Rendered only when the match tracked players;
/// otherwise the existing totals UI stands alone.
/// Section band shared by break, result and scorecard: preset hero colors,
/// one style everywhere instead of four ad-hoc headers.
class SectionHeader extends StatelessWidget {
  final String label;
  const SectionHeader(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1)),
    );
  }
}

/// One bowler per two lines: figures large right, wides/no-balls + economy
/// small below. Roomier than the old 3-column table, same numbers.
class BowlerRows extends StatelessWidget {
  final List<BowlingCard> bowlers;
  const BowlerRows(this.bowlers, {super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in bowlers)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          'Wd ${c.wides} Nb ${c.noBalls} • Econ ${c.economy == null ? '—' : c.economy!.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                Text(
                    '${c.oversDisplay}-${c.maidens}-${c.runsConceded}-${c.wickets}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
      ],
    );
  }
}

class ScorecardView extends StatelessWidget {
  final MatchStore store;
  final int inningsNo;
  const ScorecardView(
      {required this.store, required this.inningsNo, super.key});

  @override
  Widget build(BuildContext context) {
    final sheet = store.sheetFor(inningsNo);
    if (sheet == null) return const SizedBox.shrink();
    final bat = sheet.battingCards;
    final bowl = sheet.bowlingCards;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('INNINGS $inningsNo • ${sheet.battingTeam}'),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                const TableRow(
                  children: [
                    Text('BATTER',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11)),
                    Text('R(B)',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11),
                        textAlign: TextAlign.right),
                    Text('4s/6s',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11),
                        textAlign: TextAlign.right),
                    Text('SR',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11),
                        textAlign: TextAlign.right),
                  ],
                ),
                for (final c in bat)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(
                              c.position == 0
                                  ? ''
                                  : c.isNotOut
                                      ? 'not out'
                                      : (c.dismissal?.text(
                                              fielder: c.dismissedByName,
                                              bowler: c.bowlerName) ??
                                          'out'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('${c.runs} (${c.balls})',
                            textAlign: TextAlign.right,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('${c.fours}/${c.sixes}',
                            textAlign: TextAlign.right),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                            c.strikeRate == null
                                ? '—'
                                : c.strikeRate!.toStringAsFixed(1),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 20),
            const SectionHeader('BOWLING'),
            const SizedBox(height: 4),
            BowlerRows(bowl),
            Builder(builder: (_) {
              final m = store.match!;
              final inn = inningsNo == 1 ? m.innings1 : m.innings2!;
              final dnb = didNotBat(store, inningsNo);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 20),
                  Text(extrasLine(inn),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                  if (dnb.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('DID NOT BAT',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final id in dnb)
                          Text(store.playerName(id),
                              style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              );
            }),
            if (sheet.fallOfWickets.isNotEmpty) ...[
              const Divider(height: 20),
              const SectionHeader('FALL OF WICKETS'),
              const SizedBox(height: 4),
              Text(
                sheet.fallOfWickets
                    .map((c) => '${c.runs}/${c.wicketNumber} (${c.name})')
                    .join(' • '),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AwardsView extends StatelessWidget {
  final MatchStore store;

  /// Archives render read-only: tapping POTM must not write prefs through a
  /// throwaway store.
  final bool readOnly;
  const AwardsView({required this.store, this.readOnly = false, super.key});

  @override
  Widget build(BuildContext context) {
    final awards = computeAwards(store);
    if (awards.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MATCH AWARDS',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final a in awards)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(a.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    Flexible(
                      child: Text(a.value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _potm(context),
          ],
        ),
      ),
    );
  }

  Widget _potm(BuildContext context) {
    final m = store.match;
    final suggestion = suggestPotm(store);
    final current =
        m?.potmId != null ? store.playerName(m!.potmId!) : suggestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text('PLAYER OF THE MATCH',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            Text(current ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        if (!readOnly) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in _candidates())
                ChoiceChip(
                  label: Text(store.playerName(id)),
                  selected: m?.potmId == id ||
                      (m?.potmId == null && suggestion == store.playerName(id)),
                  onSelected: (_) {
                    if (store.match != null) {
                      store.match!.potmId = id;
                      store.persistOnly();
                    }
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<String> _candidates() {
    final ids = <String>{};
    for (final sheet in store.sheets.values) {
      for (final c in sheet.battingCards) {
        ids.add(c.playerId);
      }
      for (final c in sheet.bowlingCards) {
        ids.add(c.playerId);
      }
      if (ids.length >= 8) break;
    }
    // Keep the most involved first: batters by runs, then bowlers by wickets.
    final list = ids.toList();
    list.sort((a, b) {
      var ra = 0, rb = 0;
      for (final s in store.sheets.values) {
        ra += s.batting[a]?.runs ?? 0;
        rb += s.batting[b]?.runs ?? 0;
      }
      return rb.compareTo(ra);
    });
    return list.take(6).toList();
  }
}

class Award {
  final String label;
  final String value;
  const Award(this.label, this.value);
}

/// Derived awards with minimum-involvement guards, so a 3-ball cameo cannot
/// win "highest strike rate" and a 0.1-over spell cannot win "tightest".
List<Award> computeAwards(MatchStore store) {
  BattingCard? bestBat;
  BowlingCard? bestBowl;
  BattingCard? destructive;
  BowlingCard? tight;
  BattingCard? sr;
  var bestPartRuns = 0;
  var bestPartBalls = 0;
  for (final sheet in store.sheets.values) {
    for (final c in sheet.battingCards) {
      if (bestBat == null ||
          c.runs > bestBat.runs ||
          (c.runs == bestBat.runs &&
              (c.strikeRate ?? 0) > (bestBat.strikeRate ?? 0))) {
        bestBat = c;
      }
      final bnd = c.fours + c.sixes;
      final bb =
          destructive == null ? -1 : destructive.fours + destructive.sixes;
      if (bnd > bb) destructive = c;
      if (c.balls >= 6 &&
          (sr == null || (c.strikeRate ?? 0) > (sr.strikeRate ?? 0))) {
        sr = c;
      }
    }
    for (final c in sheet.bowlingCards) {
      if (bestBowl == null ||
          c.wickets > bestBowl.wickets ||
          (c.wickets == bestBowl.wickets &&
              c.runsConceded < bestBowl.runsConceded)) {
        bestBowl = c;
      }
      if (c.balls >= 12 &&
          (tight == null || (c.economy ?? 999) < (tight.economy ?? 999))) {
        tight = c;
      }
    }
    for (final p in sheet.partnerships) {
      if (p['runs']! > bestPartRuns) {
        bestPartRuns = p['runs']!;
        bestPartBalls = p['balls']!;
      }
    }
    if (sheet.partnershipRuns > bestPartRuns) {
      bestPartRuns = sheet.partnershipRuns;
      bestPartBalls = sheet.partnershipBalls;
    }
  }
  final out = <Award>[];
  if (bestBat != null && bestBat.runs > 0) {
    out.add(Award(
        'Best batter', '${bestBat.name} ${bestBat.runs} (${bestBat.balls})'));
  }
  if (bestBowl != null && bestBowl.wickets > 0) {
    out.add(Award('Best bowler',
        '${bestBowl.name} ${bestBowl.wickets}/${bestBowl.runsConceded} (${bestBowl.oversDisplay} ov)'));
  }
  if (destructive != null && (destructive.fours + destructive.sixes) > 0) {
    out.add(Award('Most destructive',
        '${destructive.name} ${destructive.fours + destructive.sixes} boundaries'));
  }
  if (tight != null) {
    out.add(Award('Tightest bowler',
        '${tight.name} ${tight.economy!.toStringAsFixed(2)} econ'));
  }
  if (sr != null && sr != bestBat) {
    out.add(Award('Highest SR (6+ balls)',
        '${sr.name} ${sr.strikeRate!.toStringAsFixed(1)}'));
  }
  if (bestPartRuns > 0) {
    out.add(
        Award('Biggest partnership', '$bestPartRuns ($bestPartBalls balls)'));
  }
  return out;
}

/// Suggested player of the match: runs + wickets weighted so an all-round
/// performance wins. The umpire can always override.
String? suggestPotm(MatchStore store) {
  String? best;
  var bestScore = double.negativeInfinity;
  final scores = <String, double>{};
  for (final sheet in store.sheets.values) {
    for (final c in sheet.battingCards) {
      scores[c.playerId] =
          (scores[c.playerId] ?? 0) + c.runs + c.fours * 1 + c.sixes * 2;
    }
    for (final c in sheet.bowlingCards) {
      scores[c.playerId] = (scores[c.playerId] ?? 0) +
          c.wickets * 25 -
          c.runsConceded * 0.3 +
          c.maidens * 5;
    }
    for (final f in sheet.fielding.values) {
      scores[f.playerId] = (scores[f.playerId] ?? 0) +
          f.catches * 10 +
          f.runOuts * 12 +
          f.stumpings * 12;
    }
  }
  scores.forEach((id, v) {
    if (v > bestScore) {
      bestScore = v;
      best = id;
    }
  });
  return best == null ? null : store.playerName(best!);
}

/// Copyable text summary for WhatsApp.
String buildShareText(MatchStore store) {
  final m = store.match!;
  final b = StringBuffer();
  final i1 = m.innings1;
  b.writeln('${i1.battingTeam} ${i1.runs}/${i1.wickets}');
  if (m.innings2 != null) {
    final i2 = m.innings2!;
    b.writeln(
        '${i2.battingTeam} ${i2.runs}/${i2.wickets}  → ${m.winner ?? ''} ${m.winMargin ?? ''}');
  } else {
    b.writeln('Target ${m.target ?? ''}');
  }
  b.writeln();
  BattingCard? top;
  BowlingCard? bowl;
  for (final sheet in store.sheets.values) {
    for (final c in sheet.battingCards) {
      if (top == null || c.runs > top.runs) top = c;
    }
    for (final c in sheet.bowlingCards) {
      if (bowl == null ||
          c.wickets > bowl.wickets ||
          (c.wickets == bowl.wickets && c.runsConceded < bowl.runsConceded)) {
        bowl = c;
      }
    }
  }
  if (top != null) {
    b.writeln('Top scorer: ${top.name} ${top.runs} (${top.balls})');
  }
  if (bowl != null) {
    b.writeln(
        'Best bowler: ${bowl.name} ${bowl.wickets}/${bowl.runsConceded} (${bowl.oversDisplay} ov)');
  }
  final potm = store.match!.potmId != null
      ? store.playerName(store.match!.potmId!)
      : suggestPotm(store);
  if (potm != null) b.writeln('Player of the match: $potm');
  return b.toString();
}

void shareScorecard(BuildContext context, MatchStore store) {
  final text = buildShareText(store);
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scorecard copied — paste into WhatsApp')));
}

/// Innings selector pills + the selected innings' full section.
///
/// Pills default to the chase innings when it exists, else innings 1. The
/// selection lives in this widget, not the store: it is view state, and the
/// store must not grow view state.
class ResultScorecard extends StatefulWidget {
  final MatchStore store;
  const ResultScorecard({required this.store, super.key});

  @override
  State<ResultScorecard> createState() => _ResultScorecardState();
}

class _ResultScorecardState extends State<ResultScorecard> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final m = widget.store.match!;
    final hasTwo = m.innings2 != null;
    final sel = _picked ?? (hasTwo ? 2 : 1);
    Innings innOf(int n) => n == 1 ? m.innings1 : m.innings2!;
    String labelOf(int n) {
      final inn = innOf(n);
      return '${inn.battingTeam} ${inn.runs}/${inn.wickets}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: _pill(context, labelOf(1), sel == 1,
                    () => setState(() => _picked = 1))),
            const SizedBox(width: 8),
            if (hasTwo)
              Expanded(
                  child: _pill(context, labelOf(2), sel == 2,
                      () => setState(() => _picked = 2))),
          ],
        ),
        const SizedBox(height: 12),
        ScorecardView(store: widget.store, inningsNo: sel),
        const SizedBox(height: 12),
        BallsView(store: widget.store, inningsNo: sel),
      ],
    );
  }

  Widget _pill(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return RectBtn(
      primary: selected,
      onTap: onTap,
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.white : cs.onSurface)),
    );
  }
}

/// Every ball of an innings, over by over, read-only.
///
/// The umpire asked for "balls data" on the finished page: this is the
/// overs-history rendering inline for the selected innings, so both innings'
/// balls are one tap apart via the pills above.
class BallsView extends StatelessWidget {
  final MatchStore store;
  final int inningsNo;
  const BallsView({required this.store, required this.inningsNo, super.key});

  @override
  Widget build(BuildContext context) {
    final m = store.match!;
    final inn = inningsNo == 1 ? m.innings1 : m.innings2;
    if (inn == null) return const SizedBox.shrink();
    final overs = inn.overs.where((o) => o.balls.isNotEmpty).toList();
    if (overs.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BALLS • ${inn.battingTeam}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final o in overs) ...[
              Text(
                  'OVER ${o.overNumber.toString().padLeft(2, '0')} // ${o.balls.fold<int>(0, (s, b) => s + b.totalRuns)} RUNS • ${o.balls.where((b) => b.isWicket).length} WKT',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final b in o.balls) BallBadge(b)],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Top two batters + best bowler of each played innings, with the toss note.
///
/// This is the per-innings story: who made the runs, who took the wickets,
/// and who chose to chase.
class TopPerformersView extends StatelessWidget {
  final MatchStore store;
  const TopPerformersView({required this.store, super.key});

  @override
  Widget build(BuildContext context) {
    final m = store.match;
    if (m == null || !store.tracking) return const SizedBox.shrink();
    final parts = <Widget>[];
    for (var n = 1; n <= 2; n++) {
      final sheet = store.sheetFor(n);
      if (sheet == null) continue;
      if (sheet.battingCards.isEmpty && sheet.bowlingCards.isEmpty) continue;
      final bat = sheet.battingCards.toList()
        ..sort((a, b) {
          final r = b.runs.compareTo(a.runs);
          return r != 0 ? r : (b.strikeRate ?? 0).compareTo(a.strikeRate ?? 0);
        });
      final bowl = sheet.bowlingCards.toList()
        ..sort((a, b) {
          final w = b.wickets.compareTo(a.wickets);
          return w != 0 ? w : a.runsConceded.compareTo(b.runsConceded);
        });
      parts.add(Text('${sheet.battingTeam} • ${n == 1 ? '1st' : '2nd'} Inns',
          style: const TextStyle(fontWeight: FontWeight.w900)));
      if (n == 1) {
        final bowlingFirst =
            m.config.battingFirst == 'A' ? m.config.teamB : m.config.teamA;
        parts.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('$bowlingFirst opt to bowl',
              style: const TextStyle(fontSize: 12)),
        ));
      }
      for (final c in bat.take(2)) {
        parts.add(_row(
          name: c.name,
          sub: c.strikeRate == null
              ? 'SR —'
              : 'SR ${c.strikeRate!.toStringAsFixed(2)}',
          figure: '${c.runs} (${c.balls})${c.isNotOut ? '*' : ''}',
        ));
      }
      if (bowl.isNotEmpty && bowl.first.wickets > 0) {
        final c = bowl.first;
        parts.add(_row(
          name: c.name,
          sub: c.economy == null
              ? 'ER —'
              : 'ER ${c.economy!.toStringAsFixed(2)}',
          figure: '${c.wickets}-${c.runsConceded} (${c.oversDisplay})',
        ));
      }
      parts.add(const SizedBox(height: 8));
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TOP PERFORMERS',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...parts,
          ],
        ),
      ),
    );
  }

  Widget _row(
      {required String name, required String sub, required String figure}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(sub, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Text(figure,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

/// Squad members who never batted: ids on the side minus everyone with a
/// batting position. Retired-hurt counts as batted; that is the point of the
/// distinction.
List<String> didNotBat(MatchStore store, int inningsNo) {
  final m = store.match;
  final sheet = store.sheetFor(inningsNo);
  if (m == null || sheet == null) return const [];
  final inn = inningsNo == 1 ? m.innings1 : m.innings2;
  if (inn == null) return const [];
  final squad =
      inn.battingTeam == m.config.teamA ? m.config.squadA : m.config.squadB;
  final batted = {
    for (final c in sheet.battingCards) c.playerId,
  };
  return [
    for (final id in squad)
      if (!batted.contains(id)) id
  ];
}

/// One-line extras breakdown: `b 4, lb 2, w 11, nb 3 — total 20`.
String extrasLine(Innings inn) {
  final parts = <String>[];
  if (inn.byes > 0) parts.add('b ${inn.byes}');
  if (inn.legByes > 0) parts.add('lb ${inn.legByes}');
  if (inn.wides > 0) parts.add('w ${inn.wides}');
  if (inn.noBalls > 0) parts.add('nb ${inn.noBalls}');
  if (parts.isEmpty) return 'Extras 0';
  return 'Extras: ${parts.join(', ')} — total ${inn.extrasTotal}';
}
