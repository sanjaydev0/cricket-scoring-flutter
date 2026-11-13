import 'package:flutter/material.dart';

import '../math.dart';
import '../theme.dart';
import '../store.dart';
import 'widgets.dart';
import 'match_detail.dart';
import 'summary.dart';

class BreakScreen extends StatelessWidget {
  final MatchStore store;
  const BreakScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, _) {
        final m = store.match!;
        // Undo-safety: state may no longer be an innings break.
        if (m.completed) {
          goOnce(context, '/result');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (m.currentInnings != 1 || !m.innings1.completed) {
          goOnce(context, '/scoring');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final inn1 = m.innings1;
        final ink = context.tokens.onPrimaryFill;
        final sheet = store.sheetFor(1);
        return Scaffold(
          appBar: RectAppBar(title: 'Innings break'),
          body: SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(context.spacing.md),
                      children: [
                        // The innings that just closed. Inverted, like the live
                        // card on Home: the one plate that says "this is the
                        // state you are between".
                        RectCard(
                          inverted: true,
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 16,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TeamDot(
                                    inn1.battingTeam == m.config.teamA
                                        ? MatchStore.teamAColor
                                        : MatchStore.teamBColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      inn1.battingTeam,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${inn1.runs}/${inn1.wickets}',
                                style: TextStyle(
                                  fontSize: 48,
                                  height: 1.0,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'OVERS ${CricketMath.ballsToOvers(inn1.legalDeliveries)}/${m.config.totalOvers}  ·  CRR ${CricketMath.calcCRR(inn1.runs, inn1.legalDeliveries)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: context.spacing.sm + context.spacing.xs,
                        ),
                        if (store.tracking &&
                            sheet != null &&
                            sheet.bowlingCards.isNotEmpty) ...[
                          RectCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionBand(
                                  'Bowling',
                                  trailing: inn1.bowlingTeam,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: BowlerRows(sheet.bowlingCards),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: context.spacing.sm + context.spacing.xs,
                          ),
                        ],
                        RectCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 16,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'CHASE TARGET FOR ${inn1.bowlingTeam}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: context.tokens.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${m.target}',
                                style: TextStyle(
                                  fontFamily: ScoreFonts.family(store.fontId),
                                  fontSize: 52,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                  color: context.tokens.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'RRR ${CricketMath.calcRRR(m.target!, CricketMath.totalBalls(m.config.totalOvers))} RPO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.tokens.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (store.tracking) ...[
                          SizedBox(
                            height: context.spacing.sm + context.spacing.xs,
                          ),
                          RectCard(
                            padding: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: MatchDetail(
                                store: store,
                                initialInnings: 1,
                                showBallsLink: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.spacing.md,
                      4,
                      context.spacing.md,
                      context.spacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: RectBtn(
                              onTap: () {
                                store.startSecondInnings();
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/scoring',
                                );
                              },
                              child: const Text(
                                'COMMENCE 2ND INNINGS',
                                style: TextStyle(
                                  fontSize: 14,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: context.spacing.sm),
                        RectBtn(
                          primary: false,
                          onTap: () => store.undo(),
                          child: const Text('UNDO'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
      builder: (_, _) {
        final m = store.match;
        if (m == null) {
          return Scaffold(
            appBar: RectAppBar(title: 'Result'),
            body: Center(
              child: Text(
                'No match',
                style: TextStyle(color: context.tokens.mutedInk),
              ),
            ),
          );
        }
        // Undo-safety: a restored live match leaves this screen.
        if (!m.completed) {
          final dest = (m.currentInnings == 1 && m.innings1.completed)
              ? '/break'
              : '/scoring';
          goOnce(context, dest);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final inn2 = m.innings2;
        final ink = context.tokens.onPrimaryFill;
        return Scaffold(
          appBar: RectAppBar(title: 'Match finished'),
          body: SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: EdgeInsets.all(context.spacing.md),
                children: [
                  // The outcome is the one thing this screen exists to say, so
                  // it gets the inverted plate rather than a heading inside a
                  // card full of everything else.
                  RectCard(
                    inverted: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          m.winner == 'TIE' ? 'MATCH TIED' : '${m.winner} WON',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: ink,
                          ),
                        ),
                        if ((m.winMargin ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            m.winMargin!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (store.tracking) ...[
                    SizedBox(height: context.spacing.sm + context.spacing.xs),
                    RectCard(
                      padding: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: MatchDetail(
                          store: store,
                          initialInnings: inn2 == null ? 1 : 2,
                          showBallsLink: true,
                        ),
                      ),
                    ),
                    SizedBox(height: context.spacing.sm + context.spacing.xs),
                    AwardsView(store: store),
                    SizedBox(height: context.spacing.sm + context.spacing.xs),
                    RectBtn(
                      primary: false,
                      onTap: () => shareScorecard(context, store),
                      child: const Text('COPY SCORECARD (WHATSAPP)'),
                    ),
                  ],
                  SizedBox(height: context.spacing.md),
                  SizedBox(
                    height: 60,
                    child: RectBtn(
                      onTap: () => _rematch(context, store),
                      child: const Text(
                        'REMATCH',
                        style: TextStyle(fontSize: 15, letterSpacing: 0.8),
                      ),
                    ),
                  ),
                  SizedBox(height: context.spacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: RectBtn(
                          primary: false,
                          onTap: () {
                            store.newMatch();
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (r) => false,
                            );
                          },
                          child: const Text('HOME'),
                        ),
                      ),
                      SizedBox(width: context.spacing.sm),
                      Expanded(
                        child: RectBtn(
                          primary: false,
                          onTap: () {
                            store.newMatch();
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/setup',
                              (r) => r.isFirst,
                            );
                          },
                          child: const Text('NEW MATCH'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Starts the next match from the same teams, rules and squads.
///
/// It opens MATCH SETUP rather than firing straight into scoring: the umpire
/// gets the previous XI preselected but can still change overs, teams or
/// players first — a rematch is a normal new match with the form pre-filled.
void _rematch(BuildContext context, MatchStore store) {
  store.prepareRematch(store.match!.config);
  store.newMatch();
  Navigator.pushNamedAndRemoveUntil(context, '/setup', (r) => r.isFirst);
}
