import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
          targetLine =
              need <= 0 ? 'WON' : 'Need $need off $ballsLeft • RRR $rrr';
        }
        final isTeamA = inn.battingTeam == m.config.teamA;

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
                  tooltip: 'Match settings',
                  onPressed: () => _settingsSheet(context)),
            ],
          ),
          body: ResponsiveCenter(
            maxWidth: 640,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ShadCard(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TeamDot(isTeamA
                                ? MatchStore.teamAColor
                                : MatchStore.teamBColor),
                            const SizedBox(width: 8),
                            Text('BATTING: ${inn.battingTeam}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        Text('${inn.runs}/${inn.wickets}',
                            style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ])),
                        if (inn.isFreeHitActive)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: ShadBadge(
                                child: Text('FREE HIT ACTIVE')),
                          ),
                        if (targetLine != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ShadBadge.secondary(
                                child: Text('TARGET $targetLine')),
                          ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: totalOvers == 0
                                  ? 0
                                  : inn.legalDeliveries /
                                      (totalOvers * 6),
                              minHeight: 6,
                            ),
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
                const SizedBox(height: 10),
                ShadCard(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(child: OverStrip(balls: cur)),
                        TextButton(
                            onPressed: () => _oversSheet(context),
                            child: Text(
                                '${overRuns}r • ${overWkts}w ›')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ShadCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            nb
                                ? 'NO-BALL ARMED — CHOOSE RUNS'
                                : 'KEYPAD',
                            style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                    color: nb
                                        ? const Color(0xFFEA580C)
                                        : null)),
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
                                onTap: () => _tap(context, 'RUNS',
                                    runs: 1)),
                            KeyBtn(
                                label: '2',
                                sub: nb ? 'N2' : 'RUNS',
                                armed: nb,
                                onTap: () => _tap(context, 'RUNS',
                                    runs: 2)),
                            KeyBtn(
                                label: '3',
                                sub: nb ? 'N3' : 'RUNS',
                                armed: nb,
                                onTap: () => _tap(context, 'RUNS',
                                    runs: 3)),
                            KeyBtn(
                                label: '4',
                                sub: nb ? 'N4' : 'FOUR',
                                color: const Color(0xFF059669),
                                fg: Colors.white,
                                armed: nb,
                                onTap: () =>
                                    _tap(context, 'FOUR')),
                            KeyBtn(
                                label: '6',
                                sub: nb ? 'N6' : 'SIX',
                                color: const Color(0xFFF59E0B),
                                fg: Colors.black,
                                armed: nb,
                                onTap: () =>
                                    _tap(context, 'SIX')),
                            KeyBtn(
                                label: 'WD',
                                sub:
                                    '+${m.config.rules.widePenalty}',
                                color: const Color(0xFFEAB308),
                                fg: Colors.black,
                                onTap: () =>
                                    _tap(context, 'WIDE')),
                            KeyBtn(
                                label: 'NB',
                                sub: nb
                                    ? 'ARMED'
                                    : '+${m.config.rules.noBallPenalty}',
                                color: const Color(0xFFEA580C),
                                fg: Colors.white,
                                armed: nb,
                                onTap: () =>
                                    store.toggleNb()),
                            KeyBtn(
                                label: 'W',
                                sub: 'WICKET',
                                color: const Color(0xFFDC2626),
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
                            ShadButton.outline(
                              onPressed: store.canUndo
                                  ? () => store.undo()
                                  : null,
                              child: const Row(
                                children: [
                                  Icon(Icons.undo, size: 18),
                                  SizedBox(width: 6),
                                  Text('UNDO'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ShadButton.outline(
                              onPressed: () =>
                                  _moreSheet(context),
                              child: const Text('EXTRAS'),
                            ),
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
    showShadDialog(
      context: context,
      builder: (_) => ShadDialog.alert(
        title: const Text('Wicket type'),
        description:
            const Text('Free-hit protects all but Run Out.'),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in types)
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    Navigator.pop(context);
                    if (t == 'Run Out') {
                      _runOutDialog(context);
                    } else {
                      store.score(action: 'WICKET', wicketType: t);
                    }
                  },
                  child: Text(t),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _runOutDialog(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (_) => ShadDialog.alert(
        title: const Text('Run-out + runs?'),
        description: const Text('Runs completed before the run-out.'),
        actions: [
          Wrap(
            spacing: 8,
            children: [
              for (final r in [0, 1, 2, 3])
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    Navigator.pop(context);
                    store.score(
                        action: 'WICKET',
                        runs: r,
                        wicketType: 'Run Out');
                  },
                  child: Text('+$r'),
                ),
            ],
          ),
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
              const Text('EXTRAS',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              const Text('Byes / leg-byes',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in [
                  ['B1', 'BYE', 1],
                  ['B2', 'BYE', 2],
                  ['B4', 'BYE', 4],
                  ['LB1', 'LEGBYE', 1],
                  ['LB2', 'LEGBYE', 2],
                  ['LB4', 'LEGBYE', 4],
                ])
                  ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () {
                        Navigator.pop(context);
                        store.score(
                            action: e[1] as String,
                            runs: e[2] as int);
                      },
                      child: Text(e[0] as String)),
              ]),
              const SizedBox(height: 12),
              const Text('Wide + overthrows',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in [0, 1, 2, 4])
                  ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () {
                        Navigator.pop(context);
                        store.score(
                            action: 'WIDE', runs: r);
                      },
                      child: Text(r == 0 ? 'WD' : 'WD+$r')),
              ]),
              const SizedBox(height: 12),
              const Text('No-ball + bat runs',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in [0, 1, 2, 4, 6])
                  ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () {
                        Navigator.pop(context);
                        store.score(
                            action: 'NB_DIRECT', runs: r);
                      },
                      child: Text(r == 0 ? 'NB' : 'NB+$r')),
              ]),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _settingsSheet(BuildContext context) {
    final m = store.match!;
    final cfg = m.config;
    int overs = cfg.totalOvers;
    int players = cfg.playersPerSide;
    int common = cfg.commonPlayers;
    int wide = cfg.rules.widePenalty;
    int noball = cfg.rules.noBallPenalty;
    bool freeHit = cfg.rules.freeHit;
    bool lms = cfg.rules.lastManStanding;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('MATCH SETTINGS',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                StepperRow(
                    label: 'Total overs',
                    value: overs,
                    min: 1,
                    max: 50,
                    onChanged: (v) =>
                        setSheet(() => overs = v)),
                const SizedBox(height: 8),
                StepperRow(
                    label: 'Players / side',
                    value: players,
                    min: 2,
                    max: 15,
                    onChanged: (v) =>
                        setSheet(() => players = v)),
                const SizedBox(height: 8),
                StepperRow(
                    label: 'Common (both sides)',
                    value: common,
                    min: 0,
                    max: 2,
                    onChanged: (v) =>
                        setSheet(() => common = v)),
                const SizedBox(height: 8),
                StepperRow(
                    label: 'Wide penalty',
                    value: wide,
                    min: 0,
                    max: 2,
                    onChanged: (v) =>
                        setSheet(() => wide = v)),
                const SizedBox(height: 8),
                StepperRow(
                    label: 'No-ball penalty',
                    value: noball,
                    min: 0,
                    max: 2,
                    onChanged: (v) =>
                        setSheet(() => noball = v)),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Free hit'),
                    ShadSwitch(
                        value: freeHit,
                        onChanged: (v) =>
                            setSheet(() => freeHit = v)),
                  ],
                ),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Last man standing'),
                    ShadSwitch(
                        value: lms,
                        onChanged: (v) =>
                            setSheet(() => lms = v)),
                  ],
                ),
                const SizedBox(height: 8),
                ShadButton(
                  onPressed: () {
                    final err = store.applyMidMatch(
                      totalOvers: overs,
                      playersPerSide: players,
                      commonPlayers: common,
                      widePenalty: wide,
                      noBallPenalty: noball,
                      freeHit: freeHit,
                      lastManStanding: lms,
                    );
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(err ??
                                'Match settings updated')));
                  },
                  child: const Text('APPLY'),
                ),
                const SizedBox(height: 16),
                const Text('DECLARE WINNER',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: () =>
                            _declare(context, cfg.teamA),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const TeamDot(
                                MatchStore.teamAColor,
                                size: 10),
                            const SizedBox(width: 6),
                            Flexible(
                                child: Text(cfg.teamA,
                                    overflow:
                                        TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: () =>
                            _declare(context, cfg.teamB),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const TeamDot(
                                MatchStore.teamBColor,
                                size: 10),
                            const SizedBox(width: 6),
                            Flexible(
                                child: Text(cfg.teamB,
                                    overflow:
                                        TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ShadButton.destructive(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _confirmAbandon(context);
                  },
                  child: const Text('ABANDON MATCH'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _declare(BuildContext context, String team) {
    Navigator.pop(context);
    showShadDialog(
      context: context,
      builder: (_) => ShadDialog.alert(
        title: Text('Declare $team winner?'),
        description:
            const Text('Ends the match now and archives it.'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () {
              store.declareWinner(team);
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/result');
            },
            child: const Text('Declare'),
          ),
        ],
      ),
    );
  }

  void _confirmAbandon(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (_) => ShadDialog.alert(
        title: const Text('Abandon match?'),
        description:
            const Text('Live progress is discarded. Archives stay.'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep scoring'),
          ),
          ShadButton.destructive(
            onPressed: () {
              store.abandon();
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (r) => false);
            },
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
  }
}

/// Over strip: auto-scrolls smoothly to the latest ball, shows the last
/// over window, scrollable back for history.
class OverStrip extends StatefulWidget {
  final List balls;
  const OverStrip({required this.balls, super.key});
  @override
  State<OverStrip> createState() => _OverStripState();
}

class _OverStripState extends State<OverStrip> {
  final ScrollController _ctrl = ScrollController();

  @override
  void didUpdateWidget(OverStrip old) {
    super.didUpdateWidget(old);
    if (widget.balls.length != old.balls.length && _ctrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_ctrl.hasClients) return;
        _ctrl.animateTo(
          _ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balls = widget.balls;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients &&
          _ctrl.position.pixels < _ctrl.position.maxScrollExtent) {
        _ctrl.jumpTo(_ctrl.position.maxScrollExtent);
      }
    });
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < balls.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child:
                  BallBadge(balls[i], isLatest: i == balls.length - 1),
            ),
          if (balls.isEmpty)
            const Text('Over 1 • tap to bowl',
                style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
