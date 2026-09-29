import 'package:flutter/material.dart';
import '../math.dart';
import '../store.dart';
import 'widgets.dart';

class ScoringScreen extends StatelessWidget {
  final MatchStore store;
  const ScoringScreen(this.store, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final m = store.match;
        if (m == null) {
          return const Scaffold(
              body: Center(child: Text('No live match')));
        }
        // route guards
        if (m.completed) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pushReplacementNamed(context, '/result'));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (m.currentInnings == 1 && m.innings1.completed) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pushReplacementNamed(context, '/break'));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final inn = store.innings!;
        final totalOvers = m.config.totalOvers;
        final oversFmt = CricketMath.ballsToOvers(inn.legalDeliveries);
        final crr = CricketMath.calcCRR(inn.runs, inn.legalDeliveries);
        final cur = inn.currentOverBalls;
        final overRuns = cur.fold<int>(0, (s, b) => s + b.totalRuns);
        final overWkts = cur.where((b) => b.isWicket).length;
        final nb = store.nbArmed;
        final target = m.currentInnings == 2 ? m.target : null;
        String? targetLine;
        if (target != null) {
          final need = target - inn.runs;
          final ballsLeft =
              CricketMath.totalBalls(totalOvers) - inn.legalDeliveries;
          final rrr = CricketMath.calcRRR(need, ballsLeft);
          targetLine = need <= 0
              ? 'WON'
              : 'Need $need off $ballsLeft • RRR $rrr';
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
                'INN ${m.currentInnings} • ${inn.battingTeam}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'Overs',
                  onPressed: () => _oversSheet(context)),
              IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Extras / End',
                  onPressed: () => _moreSheet(context)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // HERO
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 18, horizontal: 16),
                  child: Column(
                    children: [
                      Text('BATTING: ${inn.battingTeam}',
                          style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${inn.runs}/${inn.wickets}',
                          style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              fontFeatures: [
                                FontFeature.tabularFigures()
                              ])),
                      if (inn.isFreeHitActive)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Chip(
                              label: Text('⚡ FREE HIT ACTIVE',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11)),
                              backgroundColor: Colors.red,
                              labelStyle:
                                  TextStyle(color: Colors.white)),
                        ),
                      if (targetLine != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.red.shade200)),
                            child: Text('🎯 $targetLine',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.red.shade800,
                                    fontSize: 12)),
                          ),
                        ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: totalOvers == 0
                              ? 0
                              : inn.legalDeliveries /
                                  (totalOvers * 6),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat('OVERS', '$oversFmt/$totalOvers'),
                          _stat('CRR', crr),
                          _stat('EXTRAS', '${inn.extrasTotal}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // OVER STRIP
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (int i = 0;
                                  i < cur.length;
                                  i++)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 6),
                                  child: BallBadge(cur[i],
                                      isLatest:
                                          i == cur.length - 1),
                                ),
                              if (cur.isEmpty)
                                const Text('Over 1 • tap to bowl',
                                    style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                          onPressed: () => _oversSheet(context),
                          child: Text(
                              '${overRuns}r • ${overWkts}w 📋 ›')),
                    ],
                  ),
                ),
              ),
              // KEYPAD
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          nb
                              ? '⚡ NO-BALL ARMED: CHOOSE RUNS'
                              : 'KEYPAD // 70PX KEYS',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: nb ? Colors.amber.shade800 : null)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.5,
                        children: [
                          KeyBtn(
                              label: '0',
                              sub: nb ? 'NB' : 'DOT',
                              armed: nb,
                              onTap: () =>
                                  _tap(context, 'DOT')),
                          KeyBtn(
                              label: '1',
                              sub: nb ? 'N1' : 'RUN',
                              armed: nb,
                              onTap: () =>
                                  _tap(context, 'RUNS', runs: 1)),
                          KeyBtn(
                              label: '2',
                              sub: nb ? 'N2' : 'RUNS',
                              armed: nb,
                              onTap: () =>
                                  _tap(context, 'RUNS', runs: 2)),
                          KeyBtn(
                              label: '3',
                              sub: nb ? 'N3' : 'RUNS',
                              armed: nb,
                              onTap: () =>
                                  _tap(context, 'RUNS', runs: 3)),
                          KeyBtn(
                              label: '4',
                              sub: nb ? 'N4' : 'FOUR',
                              color: const Color(0xFF059669),
                              fg: Colors.white,
                              armed: nb,
                              onTap: () => _tap(context, 'FOUR')),
                          KeyBtn(
                              label: '6',
                              sub: nb ? 'N6' : 'SIX',
                              color: const Color(0xFF4F46E5),
                              fg: Colors.white,
                              armed: nb,
                              onTap: () => _tap(context, 'SIX')),
                          KeyBtn(
                              label: 'WD',
                              sub:
                                  '+${m.config.rules.widePenalty} RUN',
                              color: const Color(0xFFF59E0B),
                              fg: Colors.black,
                              onTap: () =>
                                  _tap(context, 'WIDE')),
                          KeyBtn(
                              label: 'NB',
                              sub: nb ? 'ARMED' : '+${m.config.rules.noBallPenalty} RUN',
                              color: const Color(0xFFF59E0B),
                              fg: Colors.black,
                              armed: nb,
                              onTap: () =>
                                  store.toggleNb()),
                          KeyBtn(
                              label: 'W',
                              sub: 'WICKET',
                              color: const Color(0xFFE11D48),
                              fg: Colors.white,
                              onTap: () =>
                                  _wicketDialog(context)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: FilledButton(
                              onPressed: store.canUndo
                                  ? () => store.undo()
                                  : null,
                              style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              16)),
                                  padding: EdgeInsets.zero),
                              child: const Icon(
                                  Icons.undo, size: 24),
                            ),
                          ),
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

  Widget _stat(String k, String v) => Column(
        children: [
          Text(k,
              style:
                  const TextStyle(fontSize: 10, letterSpacing: 1.2)),
          Text(v,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      );

  void _tap(BuildContext ctx, String action, {int runs = 0}) {
    final err = store.score(action: action, runs: runs);
    if (err != null) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _wicketDialog(BuildContext context) {
    const types = [
      'Bowled',
      'Caught',
      'LBW',
      'Stumped',
      'Hit Wicket',
      'Run Out'
    ];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('WICKET TYPE',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in types)
                    ChoiceChip(
                      label: Text(t),
                      selected: false,
                      onSelected: (_) {
                        Navigator.pop(context);
                        if (t == 'Run Out') {
                          _runOutDialog(context);
                        } else {
                          _tap(context, 'WICKET',
                              runs: 0);
                          store.score(
                              action: 'WICKET',
                              wicketType: t);
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Run-out + runs?'),
        content: const Text('Runs completed before run-out (0-3)'),
        actions: [
          for (final r in [0, 1, 2, 3])
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  store.score(
                      action: 'WICKET',
                      runs: r,
                      wicketType: 'Run Out');
                },
                child: Text('+$r')),
        ],
      ),
    );
  }

  void _oversSheet(BuildContext context) {
    final inn = store.innings!;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('${inn.battingTeam} • ${inn.runs}/${inn.wickets}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final o in inn.overs)
              if (o.balls.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 36,
                          child: Text('O${o.overNumber}',
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w800))),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final b in o.balls)
                              BallBadge(b)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _moreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('EXTRAS / ACTIONS',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in [
                  ['B1', 'BYE', 1],
                  ['B2', 'BYE', 2],
                  ['B4', 'BYE', 4],
                  ['LB1', 'LEGBYE', 1],
                  ['LB2', 'LEGBYE', 2],
                  ['LB4', 'LEGBYE', 4],
                ])
                  ActionChip(
                      label: Text((e[0] as String)),
                      onPressed: () {
                        Navigator.pop(context);
                        store.score(
                            action: e[1] as String,
                            runs: e[2] as int);
                      }),
              ]),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    store.abandon();
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/', (r) => false);
                  },
                  child: const Text('Abandon match')),
            ],
          ),
        ),
      ),
    );
  }
}
