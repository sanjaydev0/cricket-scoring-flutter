import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/players.dart';
import '../models.dart';
import '../store.dart';
import 'widgets.dart';

/// Bowling figures in the newspaper scorecard convention: `O M R W` under a
/// labelled header row, with `WD NB` appended so the penalty breakdown stays
/// visible.
///
/// The header is what makes the single letters honest - `26-1-2-1` with no
/// legend is guesswork. Runs (`R`) already contain the wides and no-ball
/// penalties (Law 41.14), which is exactly why they sit in their own columns
/// rather than being added on: the total never moves.
///
/// Overs count legal balls only, so a bowler who sent six legal plus two
/// wides reads `6.0`, not `8.2`.
class BowlerRows extends StatelessWidget {
  final List<BowlingCard> bowlers;
  const BowlerRows(this.bowlers, {super.key});

  Widget _cell(
    String v, {
    Color? color,
    bool header = false,
    double width = 34,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        v,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: header
            ? const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              )
            : TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: color,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final faint = cs.onSurface.withValues(alpha: 0.6);
    final hasExtras = bowlers.any((c) => c.wides > 0 || c.noBalls > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: O M R W (+ WD NB) so the letters need no legend.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'BOWLING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: faint,
                  ),
                ),
              ),
              _cell('O', color: faint, header: true),
              _cell('M', color: faint, header: true),
              _cell('R', color: faint, header: true),
              _cell('W', color: faint, header: true),
              _cell('ECO', color: faint, header: true, width: 36),
              if (hasExtras) ...[
                _cell('WD', color: faint, header: true, width: 26),
                _cell('NB', color: faint, header: true, width: 26),
              ],
              const SizedBox(width: 2),
            ],
          ),
        ),
        for (final c in bowlers)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                _cell(c.oversDisplay),
                _cell('${c.maidens}'),
                _cell('${c.runsConceded}'),
                _cell(
                  '${c.wickets}',
                  color: c.wickets > 0 ? const Color(0xFF22C55E) : null,
                ),
                _cell(
                  c.economy == null ? '—' : c.economy!.toStringAsFixed(2),
                  color: const Color(0xFFF59E0B),
                  width: 36,
                ),
                if (hasExtras) ...[
                  _cell(
                    c.wides > 0 ? '${c.wides}' : '·',
                    color: faint,
                    width: 26,
                  ),
                  _cell(
                    c.noBalls > 0 ? '${c.noBalls}' : '·',
                    color: faint,
                    width: 26,
                  ),
                ],
                const SizedBox(width: 2),
              ],
            ),
          ),
        if (hasExtras)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'R (runs) already includes the wides and no-balls beside it.',
              style: TextStyle(fontSize: 10, color: faint),
            ),
          ),
      ],
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
            const Text(
              'MATCH AWARDS',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final a in awards)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        a.value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
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
    final current = m?.potmId != null
        ? store.playerName(m!.potmId!)
        : suggestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'PLAYER OF THE MATCH',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              current ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
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
                  selected:
                      m?.potmId == id ||
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
      final bb = destructive == null
          ? -1
          : destructive.fours + destructive.sixes;
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
    out.add(
      Award(
        'Best batter',
        '${bestBat.name} ${bestBat.runs} (${bestBat.balls})',
      ),
    );
  }
  if (bestBowl != null && bestBowl.wickets > 0) {
    out.add(
      Award(
        'Best bowler',
        '${bestBowl.name} ${bestBowl.wickets}/${bestBowl.runsConceded} (${bestBowl.oversDisplay} ov)',
      ),
    );
  }
  if (destructive != null && (destructive.fours + destructive.sixes) > 0) {
    out.add(
      Award(
        'Most destructive',
        '${destructive.name} ${destructive.fours + destructive.sixes} boundaries',
      ),
    );
  }
  if (tight != null) {
    out.add(
      Award(
        'Tightest bowler',
        '${tight.name} ${tight.economy!.toStringAsFixed(2)} econ',
      ),
    );
  }
  if (sr != null && sr != bestBat) {
    out.add(
      Award(
        'Highest SR (6+ balls)',
        '${sr.name} ${sr.strikeRate!.toStringAsFixed(1)}',
      ),
    );
  }
  if (bestPartRuns > 0) {
    out.add(
      Award('Biggest partnership', '$bestPartRuns ($bestPartBalls balls)'),
    );
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
      scores[c.playerId] =
          (scores[c.playerId] ?? 0) +
          c.wickets * 25 -
          c.runsConceded * 0.3 +
          c.maidens * 5;
    }
    for (final f in sheet.fielding.values) {
      scores[f.playerId] =
          (scores[f.playerId] ?? 0) +
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
      '${i2.battingTeam} ${i2.runs}/${i2.wickets}  → ${m.winner ?? ''} ${m.winMargin ?? ''}',
    );
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
      'Best bowler: ${bowl.name} ${bowl.wickets}/${bowl.runsConceded} (${bowl.oversDisplay} ov)',
    );
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
    const SnackBar(content: Text('Scorecard copied — paste into WhatsApp')),
  );
}

/// Top performers, newspaper style: the two best batters and the best bowler
/// of each innings, with the toss note.
///
/// The live card, the archives and the result page all show this, so the
/// "who did the damage" answer is the same everywhere. Rows are flat with
/// hairline separators — no card, no avatar photo (there are none), just the
/// initials in the team's colour.
class TopPerformersView extends StatelessWidget {
  final MatchStore store;

  /// Only this innings. Null shows every innings that was played.
  final int? inningsNo;

  const TopPerformersView({required this.store, this.inningsNo, super.key});

  @override
  Widget build(BuildContext context) {
    final m = store.match;
    if (m == null || !store.tracking) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    final squad = m.config.playersPerSide;
    final many = squad >= 8; // more players per side -> 3 batters, else 2
    final nBat = many ? 3 : 2;
    final nBowl = 2;
    for (var n = 1; n <= 2; n++) {
      if (inningsNo != null && n != inningsNo) continue;
      final sheet = store.sheetFor(n);
      if (sheet == null) continue;
      final bat = sheet.battingCards.where((c) => c.balls > 0).toList()
        ..sort((a, b) {
          final r = b.runs.compareTo(a.runs);
          return r != 0 ? r : (b.strikeRate ?? 0).compareTo(a.strikeRate ?? 0);
        });
      final bowl = sheet.bowlingCards.where((c) => c.legalBalls > 0).toList()
        ..sort((a, b) {
          final w = b.wickets.compareTo(a.wickets);
          return w != 0 ? w : a.runsConceded.compareTo(b.runsConceded);
        });
      if (bat.isEmpty && bowl.isEmpty) continue;
      final teamColor = sheet.battingTeam == m.config.teamA
          ? MatchStore.teamAColor
          : MatchStore.teamBColor;
      final bowlingFirst = m.config.battingFirst == 'A'
          ? m.config.teamB
          : m.config.teamA;
      rows.add(
        _inningsHeader(
          context,
          '${sheet.battingTeam} — ${n == 1 ? '1st' : '2nd'} Inns',
          n == 1 ? '$bowlingFirst opt to bowl' : null,
        ),
      );
      if (bat.isNotEmpty) {
        rows.add(_sectionLabel(context, 'BATTERS'));
        for (final c in bat.take(nBat)) {
          rows.add(
            _row(
              context,
              name: c.name,
              sub: c.strikeRate == null
                  ? 'SR —'
                  : 'SR: ${c.strikeRate!.toStringAsFixed(2)}',
              figure: '${c.runs} (${c.balls})${c.isNotOut ? '*' : ''}',
              color: teamColor,
            ),
          );
        }
      }
      if (bowl.isNotEmpty) {
        rows.add(_sectionLabel(context, 'BOWLERS'));
        for (final c in bowl.take(nBowl)) {
          rows.add(
            _row(
              context,
              name: c.name,
              sub: c.economy == null
                  ? 'ER —'
                  : 'ER: ${c.economy!.toStringAsFixed(2)}',
              figure: '${c.wickets}-${c.runsConceded} (${c.oversDisplay})',
              color: teamColor,
            ),
          );
        }
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'TOP PERFORMERS',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 4),
        ...rows,
        const SizedBox(height: 4),
        Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _inningsHeader(BuildContext context, String left, String? right) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (right != null)
            Text(
              right,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String name,
    required String sub,
    required String figure,
    required int color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          InitialsAvatar(name, colorValue: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            figure,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
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
  final squad = inn.battingTeam == m.config.teamA
      ? m.config.squadA
      : m.config.squadB;
  final batted = {for (final c in sheet.battingCards) c.playerId};
  return [
    for (final id in squad)
      if (!batted.contains(id)) id,
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
