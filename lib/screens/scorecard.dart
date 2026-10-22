import 'package:flutter/material.dart';

import '../domain/players.dart';
import '../store.dart';
import 'summary.dart';
import 'widgets.dart';

/// The full innings scorecard, live.
///
/// Reachable from the overs history and from the players sheet. It answers the
/// three questions an umpire asks mid-match: who is at the crease, who has
/// batted, and what have the bowlers done.
///
/// The tables themselves are the shared [ScorecardView], so the live card and
/// the end-of-match card can never disagree about a figure.
class ScorecardScreen extends StatelessWidget {
  final MatchStore store;
  final int inningsNo;
  const ScorecardScreen(
      {required this.store, required this.inningsNo, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCORECARD')),
      body: ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final sheet = store.sheetFor(inningsNo);
          if (sheet == null) {
            return const Center(
                child: Text('No scorecard for this innings.',
                    style: TextStyle(fontSize: 13)));
          }
          return ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _nowCard(sheet),
                const SizedBox(height: 12),
                ScorecardView(store: store, inningsNo: inningsNo),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The "now" panel: the two batters at the crease and the bowler bowling.
Widget _nowCard(InningsSheet sheet) {
  final striker = sheet.striker;
  final nonStriker = sheet.nonStriker;
  final bowler = sheet.currentBowler;
  Widget batter(BattingCard? c, String where) {
    if (c == null) {
      return DetailRow(title: '—', subtitle: where);
    }
    return DetailRow(
      title: c.name,
      subtitle: where,
      valueLabel: 'RUNS (BALLS)',
      value: '${c.runs} (${c.balls})',
    );
  }

  return Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        batter(striker, 'On strike'),
        batter(nonStriker, 'At the other end'),
        if (bowler != null)
          DetailRow(
            title: bowler.name,
            subtitle: 'Bowling now • ${bowler.wickets} '
                '${bowler.wickets == 1 ? 'wicket' : 'wickets'} • '
                'economy ${fmt2(bowler.economy)}',
            valueLabel: 'OVERS',
            value: bowler.oversDisplay,
          ),
      ],
    ),
  );
}

/// Opens the live scorecard as its own screen.
void showScorecard(BuildContext context, MatchStore store, {int? inningsNo}) {
  final no = inningsNo ?? store.match?.currentInnings ?? 1;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ScorecardScreen(store: store, inningsNo: no),
  ));
}
