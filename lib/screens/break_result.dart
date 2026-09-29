import 'package:flutter/material.dart';
import '../math.dart';
import '../store.dart';

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
          appBar: AppBar(title: const Text('( INNINGS BREAK )')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 40)),
                      Text('${inn1.battingTeam}: ${inn1.runs}/${inn1.wickets}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                      Text(
                          'Overs ${CricketMath.ballsToOvers(inn1.legalDeliveries)}/${m.config.totalOvers} • CRR ${CricketMath.calcCRR(inn1.runs, inn1.legalDeliveries)}'),
                      const SizedBox(height: 16),
                      Text('CHASE TARGET FOR ${inn1.bowlingTeam}',
                          style:
                              const TextStyle(letterSpacing: 1.2, fontSize: 11)),
                      Text('${m.target} RUNS',
                          style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.red.shade700)),
                      Text(
                          'RRR ${CricketMath.calcRRR(m.target!, CricketMath.totalBalls(m.config.totalOvers))} RPO'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                            onPressed: () {
                              store.startSecondInnings();
                              Navigator.pushReplacementNamed(
                                  context, '/scoring');
                            },
                            child: const Text('COMMENCE 2ND INNINGS ▶')),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                          onPressed: () => store.undo(),
                          child: const Text('⤺ UNDO (back to 1st inn)')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ResultScreen extends StatelessWidget {
  final MatchStore store;
  final bool fromHistory;
  const ResultScreen(this.store, {this.fromHistory = false, super.key});
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
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(m.winner == 'TIE' ? '⚖️' : '🏆',
                          style: const TextStyle(fontSize: 44)),
                      Text(
                          m.winner == 'TIE'
                              ? 'MATCH TIED'
                              : '${m.winner} WON',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                      Text(m.winMargin ?? '',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      _innCard(inn1.battingTeam, inn1.runs,
                          inn1.wickets, inn1.legalDeliveries),
                      if (inn2 != null)
                        _innCard(inn2.battingTeam, inn2.runs,
                            inn2.wickets, inn2.legalDeliveries),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: () {
                                    store.newMatch();
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/', (r) => false);
                                  },
                                  child: const Text('🏠 HOME'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: FilledButton(
                                  onPressed: () {
                                    store.newMatch();
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/setup', (r) => r.isFirst);
                                  },
                                  child:
                                      const Text('🏏 NEW MATCH'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _innCard(String team, int r, int w, int balls) => Card(
        color: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(team,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('$r/$w (${CricketMath.ballsToOvers(balls)} ov)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
        ),
      );
}
