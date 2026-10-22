import 'package:flutter/material.dart';

import '../store.dart';
import 'match_detail.dart';
import 'widgets.dart';

/// The live innings scorecard.
///
/// Reachable from the players sheet and the overs history. It shows ONE
/// innings at a time — the team pills at the top switch between them — plus a
/// SUMMARY tab with the top performers of the match.
class ScorecardScreen extends StatelessWidget {
  final MatchStore store;
  final int inningsNo;
  const ScorecardScreen({
    required this.store,
    required this.inningsNo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCORECARD')),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: MatchDetail(
              store: store,
              initialInnings: inningsNo,
              showBallsLink: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the live scorecard as its own screen.
void showScorecard(BuildContext context, MatchStore store, {int? inningsNo}) {
  final no = inningsNo ?? store.match?.currentInnings ?? 1;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ScorecardScreen(store: store, inningsNo: no),
    ),
  );
}
