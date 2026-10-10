import 'package:flutter/material.dart';
import '../math.dart';
import '../theme.dart';
import '../store.dart';
import 'widgets.dart';
import 'summary.dart';

class BreakScreen extends StatelessWidget {
  final MatchStore store;
  const BreakScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final m = store.match!;
          // Undo-safety: state may no longer be an innings break.
          if (m.completed) {
            goOnce(context, '/result');
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (m.currentInnings != 1 || !m.innings1.completed) {
            goOnce(context, '/scoring');
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final inn1 = m.innings1;
          final preset = StylePreset.of(store.styleId);
          return Scaffold(
              appBar: AppBar(title: const Text('INNINGS BREAK')),
              body: SafeArea(
                  child: ResponsiveCenter(
                      child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          color: preset.heroBg,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TeamDot(inn1.battingTeam == m.config.teamA
                                        ? MatchStore.teamAColor
                                        : MatchStore.teamBColor),
                                    const SizedBox(width: 8),
                                    Text(
                                        '${inn1.battingTeam}: ${inn1.runs}/${inn1.wickets}',
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: preset.heroFg)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    'Overs ${CricketMath.ballsToOvers(inn1.legalDeliveries)}/${m.config.totalOvers} • CRR ${CricketMath.calcCRR(inn1.runs, inn1.legalDeliveries)}',
                                    style: TextStyle(
                                        color: preset.heroFg
                                            .withValues(alpha: 0.9))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 16),
                            child: Column(
                              children: [
                                Text('CHASE TARGET FOR ${inn1.bowlingTeam}',
                                    style: const TextStyle(
                                        letterSpacing: 1.2, fontSize: 11)),
                                Text('${m.target}',
                                    style: TextStyle(
                                        fontFamily:
                                            ScoreFonts.family(store.fontId),
                                        fontSize: 52,
                                        fontWeight: FontWeight.w900,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                                Text(
                                    'RRR ${CricketMath.calcRRR(m.target!, CricketMath.totalBalls(m.config.totalOvers))} RPO'),
                              ],
                            ),
                          ),
                        ),
                        if (store.tracking) ...[
                          const SizedBox(height: 12),
                          ScorecardView(store: store, inningsNo: 1),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: RectBtn(
                              onTap: () {
                                store.startSecondInnings();
                                Navigator.pushReplacementNamed(
                                    context, '/scoring');
                              },
                              child: const Text('COMMENCE 2ND INNINGS')),
                        ),
                        TextButton(
                          onPressed: () => store.undo(),
                          child: const Text('Undo'),
                        ),
                      ],
                    ),
                  ),
                ],
              ))));
        });
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
        // Undo-safety: a restored live match leaves this screen.
        if (!m.completed) {
          final dest = (m.currentInnings == 1 && m.innings1.completed)
              ? '/break'
              : '/scoring';
          goOnce(context, dest);
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final inn1 = m.innings1;
        final inn2 = m.innings2;
        return Scaffold(
          appBar: AppBar(title: const Text('MATCH FINISHED')),
          body: SafeArea(
              child: ResponsiveCenter(
                  child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(m.winner == 'TIE' ? 'MATCH TIED' : '${m.winner} WON',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      Text(m.winMargin ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _innCard(m, inn1.battingTeam, inn1.runs, inn1.wickets,
                          inn1.legalDeliveries),
                      if (inn2 != null)
                        _innCard(m, inn2.battingTeam, inn2.runs, inn2.wickets,
                            inn2.legalDeliveries),
                      if (store.tracking) ...[
                        const SizedBox(height: 12),
                        ResultScorecard(store: store),
                        const SizedBox(height: 12),
                        TopPerformersView(store: store),
                        const SizedBox(height: 12),
                        AwardsView(store: store),
                        const SizedBox(height: 12),
                        RectBtn(
                          primary: false,
                          onTap: () => shareScorecard(context, store),
                          child: const Text('COPY SCORECARD (WHATSAPP)'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: RectBtn(
                                  primary: false,
                                  onTap: () {
                                    store.newMatch();
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/', (r) => false);
                                  },
                                  child: const Text('HOME'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: RectBtn(
                                  onTap: () {
                                    store.newMatch();
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/setup', (r) => r.isFirst);
                                  },
                                  child: const Text('NEW MATCH'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ))),
        );
      },
    );
  }

  Widget _innCard(dynamic m, String team, int r, int w, int balls) {
    final dot =
        team == m.config.teamA ? MatchStore.teamAColor : MatchStore.teamBColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          TeamDot(dot),
          const SizedBox(width: 8),
          Expanded(
              child: Text(team,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('$r/$w (${CricketMath.ballsToOvers(balls)})',
              style: TextStyle(
                  fontFamily: ScoreFonts.family(store.fontId),
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
