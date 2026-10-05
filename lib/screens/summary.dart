import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/players.dart';
import '../store.dart';
import 'widgets.dart';

/// Shared scorecard + awards, used by the break screen (first innings) and the
/// result screen (both innings). Rendered only when the match tracked players;
/// otherwise the existing totals UI stands alone.
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
            Text('INNINGS $inningsNo • ${sheet.battingTeam}',
                style: const TextStyle(fontWeight: FontWeight.w900)),
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
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1),
              },
              children: [
                const TableRow(
                  children: [
                    Text('BOWLER',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11)),
                    Text('O-M-R-W',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11),
                        textAlign: TextAlign.right),
                    Text('ECON',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 11),
                        textAlign: TextAlign.right),
                  ],
                ),
                for (final c in bowl)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(c.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                            '${c.oversDisplay}-${c.maidens}-${c.runsConceded}-${c.wickets}',
                            textAlign: TextAlign.right),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                            c.economy == null
                                ? '—'
                                : c.economy!.toStringAsFixed(2),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
              ],
            ),
            if (sheet.fallOfWickets.isNotEmpty) ...[
              const Divider(height: 20),
              const Text('FALL OF WICKETS',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
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
  const AwardsView({required this.store, super.key});

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
  if (top != null)
    b.writeln('Top scorer: ${top.name} ${top.runs} (${top.balls})');
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
