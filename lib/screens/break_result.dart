import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../math.dart';
import '../store.dart';
import 'widgets.dart';

class BreakScreen extends StatelessWidget {
  final MatchStore store;
  const BreakScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final m = store.match!;
        final inn1 = m.innings1;
        return Scaffold(
          appBar: AppBar(title: const Text('INNINGS BREAK')),
          body: ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ShadCard(
                  title: const Text('1st innings summary'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            TeamDot(inn1.battingTeam ==
                                    m.config.teamA
                                ? MatchStore.teamAColor
                                : MatchStore.teamBColor),
                            const SizedBox(width: 8),
                            Text(
                                '${inn1.battingTeam}: ${inn1.runs}/${inn1.wickets}',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.w900)),
                          ],
                        ),
                        Text(
                            'Overs ${CricketMath.ballsToOvers(inn1.legalDeliveries)}/${m.config.totalOvers} • CRR ${CricketMath.calcCRR(inn1.runs, inn1.legalDeliveries)}'),
                        const SizedBox(height: 16),
                        Text(
                            'CHASE TARGET FOR ${inn1.bowlingTeam}',
                            style: const TextStyle(
                                letterSpacing: 1.2,
                                fontSize: 11)),
                        Text('${m.target}',
                            style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.shade700)),
                        Text(
                            'RRR ${CricketMath.calcRRR(m.target!, CricketMath.totalBalls(m.config.totalOvers))} RPO'),
                        const SizedBox(height: 16),
                        ShadButton(
                            onPressed: () {
                              store.startSecondInnings();
                              Navigator.pushReplacementNamed(
                                  context, '/scoring');
                            },
                            child: const Text(
                                'COMMENCE 2ND INNINGS')),
                        const SizedBox(height: 8),
                        ShadButton.outline(
                            onPressed: () => store.undo(),
                            child: const Text('UNDO')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ResultScreen extends StatelessWidget {
  final MatchStore store;
  const ResultScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final m = store.match;
        if (m == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('RESULT')),
              body: const Center(child: Text('No match')));
        }
        final inn1 = m.innings1;
        final inn2 = m.innings2;
        return Scaffold(
          appBar: AppBar(title: const Text('MATCH FINISHED')),
          body: ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ShadCard(
                  title: Text(
                      m.winner == 'TIE'
                          ? 'MATCH TIED'
                          : '${m.winner} WON',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  description: Text(m.winMargin ?? ''),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        _innCard(m, inn1.battingTeam,
                            inn1.runs, inn1.wickets,
                            inn1.legalDeliveries),
                        if (inn2 != null)
                          _innCard(
                              m,
                              inn2.battingTeam,
                              inn2.runs,
                              inn2.wickets,
                              inn2.legalDeliveries),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: ShadButton.outline(
                                    onPressed: () {
                                      store.newMatch();
                                      Navigator
                                          .pushNamedAndRemoveUntil(
                                              context,
                                              '/',
                                              (r) => false);
                                    },
                                    child:
                                        const Text('HOME'))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: ShadButton(
                                    onPressed: () {
                                      store.newMatch();
                                      Navigator
                                          .pushNamedAndRemoveUntil(
                                              context,
                                              '/setup',
                                              (r) => r.isFirst);
                                    },
                                    child: const Text(
                                        'NEW MATCH'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _innCard(dynamic m, String team, int r, int w, int balls) {
    final dot = team == m.config.teamA
        ? MatchStore.teamAColor
        : MatchStore.teamBColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          TeamDot(dot),
          const SizedBox(width: 8),
          Expanded(
              child: Text(team,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800))),
          Text('$r/$w (${CricketMath.ballsToOvers(balls)})',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
