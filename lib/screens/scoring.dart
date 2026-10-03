import 'package:flutter/material.dart';
import '../math.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets.dart';
import 'sheets.dart';

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
        final ballsLeft =
            CricketMath.totalBalls(totalOvers) - inn.legalDeliveries;
        final proj = inn.legalDeliveries == 0
            ? '—'
            : '${(inn.runs + (inn.runs / inn.legalDeliveries) * ballsLeft).round()}';
        final cur = inn.currentOverBalls;
        final overRuns = cur.fold<int>(0, (s, b) => s + b.totalRuns);
        final overWkts = cur.where((b) => b.isWicket).length;
        final nb = store.nbArmed;
        final target = m.currentInnings == 2 ? m.target : null;
        String? targetLine;
        if (target != null) {
          final need = target - inn.runs;
          final rrr = CricketMath.calcRRR(need, ballsLeft);
          targetLine =
              need <= 0 ? 'WON' : 'Need $need off $ballsLeft • RRR $rrr';
        }
        final isTeamA = inn.battingTeam == m.config.teamA;
        final preset = StylePreset.of(store.styleId);
        final scoreFamily = ScoreFonts.family(store.fontId);

        return Scaffold(
          appBar: AppBar(
            title: Text(
                'INN ${m.currentInnings} • ${inn.battingTeam}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  tooltip: store.soundOn ? 'Mute sounds' : 'Unmute',
                  onPressed: () =>
                      store.setSound(!store.soundOn)),
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
                Card(
                  color: preset.heroBg,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
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
                                style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: preset.heroFg)),
                          ],
                        ),
                        Builder(builder: (_) {
                          final lastBadge = cur.isNotEmpty
                              ? cur.last.badge
                              : '';
                          final isW =
                              lastBadge == 'W';
                          final isFour = lastBadge == '4' ||
                              lastBadge.startsWith('N4');
                          final isSix = lastBadge == '6' ||
                              lastBadge.startsWith('N6');
                          final fire =
                              isW || isFour || isSix;
                          final label = isW
                              ? 'W'
                              : (isFour ? '+4' : '+6');
                          final tint = isW
                              ? const Color(0xFFDC143C)
                              : (isFour
                                  ? const Color(0xFF2DC653)
                                  : const Color(0xFFEC008C));
                          return Celebrate(
                            mode: store.celebId,
                            valueKey:
                                '${inn.runs}/${inn.wickets}',
                            fire: fire,
                            label: label,
                            tint: tint,
                            text:
                                '${inn.runs}/${inn.wickets}',
                            style: TextStyle(
                                fontFamily: scoreFamily,
                                fontSize: 68,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                color: preset.heroFg,
                                fontFeatures: const [
                                  FontFeature
                                      .tabularFigures()
                                ]),
                          );
                        }),
                        if (inn.isFreeHitActive)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Badge(
                                label: Text('FREE HIT',
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.w900))),
                          ),
                        if (targetLine != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6),
                              decoration: BoxDecoration(
                                color: preset.heroFg.withValues(
                                    alpha: 0.18),
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: Border.all(
                                    color: preset.heroFg),
                              ),
                              child: Text(
                                  'TARGET $targetLine',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                      fontSize: 12,
                                      color: preset.heroFg)),
                            ),
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
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            _stat(context, 'OVERS',
                                '$oversFmt/$totalOvers', preset.heroFg),
                            _stat(context, 'CRR', crr, preset.heroFg),
                            _stat(context, 'PROJ', '~$proj',
                                preset.heroFg),
                            _stat(context, 'EXTRAS',
                                '${inn.extrasTotal}', preset.heroFg),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: preset.stripBg,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        // Fixed 6-ball window — never a half-peeking
                        // 7th ball; older balls scroll left.
                        SizedBox(
                            width: 246,
                            child: OverStrip(balls: cur)),
                        TextButton(
                            onPressed: () => _oversSheet(context),
                            child: Text(
                                '${overRuns}r • ${overWkts}w ›',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w800))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
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
                                    ? const Color(0xFF7B2CBF)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
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
                                radius: preset.keyRadius,
                                color: Colors.white,
                                fg: Colors.black,
                                onTap: () =>
                                    _tap(context, 'DOT')),
                            KeyBtn(
                                label: '1',
                                sub: nb ? 'N1' : 'RUN',
                                armed: nb,
                                radius: preset.keyRadius,
                                color: Colors.white,
                                fg: Colors.black,
                                onTap: () => _tap(context, 'RUNS',
                                    runs: 1)),
                            KeyBtn(
                                label: '2',
                                sub: nb ? 'N2' : 'RUNS',
                                armed: nb,
                                radius: preset.keyRadius,
                                color: Colors.white,
                                fg: Colors.black,
                                onTap: () => _tap(context, 'RUNS',
                                    runs: 2)),
                            KeyBtn(
                                label: '3',
                                sub: nb ? 'N3' : 'RUNS',
                                armed: nb,
                                radius: preset.keyRadius,
                                color: Colors.white,
                                fg: Colors.black,
                                onTap: () => _tap(context, 'RUNS',
                                    runs: 3)),
                            KeyBtn(
                                label: '4',
                                sub: nb ? 'N4' : 'FOUR',
                                color: const Color(0xFF2DC653),
                                fg: Colors.black,
                                armed: nb,
                                radius: preset.keyRadius,
                                onTap: () =>
                                    _tap(context, 'FOUR')),
                            KeyBtn(
                                label: '6',
                                sub: nb ? 'N6' : 'SIX',
                                color: const Color(0xFFEC008C),
                                fg: Colors.white,
                                armed: nb,
                                radius: preset.keyRadius,
                                onTap: () =>
                                    _tap(context, 'SIX')),
                            KeyBtn(
                                label: 'WD',
                                sub:
                                    '+${m.config.rules.widePenalty}',
                                color: const Color(0xFFFFBA08),
                                fg: Colors.black,
                                radius: preset.keyRadius,
                                onTap: () =>
                                    _tap(context, 'WIDE')),
                            KeyBtn(
                                label: 'NB',
                                sub: nb
                                    ? 'ARMED'
                                    : '+${m.config.rules.noBallPenalty}',
                                color: const Color(0xFF7B2CBF),
                                fg: Colors.white,
                                armed: nb,
                                radius: preset.keyRadius,
                                onTap: () =>
                                    store.toggleNb()),
                            KeyBtn(
                                label: 'W',
                                sub: 'WICKET',
                                color: const Color(0xFFDC143C),
                                fg: Colors.white,
                                radius: preset.keyRadius,
                                onTap: () =>
                                    _wicketDialog(context)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: store.canUndo
                                  ? () => store.undo()
                                  : null,
                              icon: const Icon(Icons.undo,
                                  size: 20),
                              label: const Text('UNDO'),
                            ),
                            if (store.advancedExtras) ...[
                              const SizedBox(width: 10),
                              FilledButton.tonal(
                                onPressed: () =>
                                    _moreSheet(context),
                                child: const Text('EXTRAS'),
                              ),
                            ],
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

  Widget _stat(BuildContext ctx, String k, String v, Color fg) {
    return Column(
      children: [
        Text(k,
            style: TextStyle(
                fontSize: 10, letterSpacing: 1.2, color: fg.withValues(alpha: 0.85))),
        Text(v,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: fg)),
      ],
    );
  }

  void _tap(BuildContext ctx, String action, {int runs = 0}) {
    final err = store.score(action: action, runs: runs);
    if (err != null) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _wicketDialog(BuildContext context) =>
      showWicketDialog(context, store);
  void _oversSheet(BuildContext context) =>
      showOversSheet(context, store);
  void _moreSheet(BuildContext context) =>
      showExtrasSheet(context, store);
  void _settingsSheet(BuildContext context) =>
      showSettingsSheet(context, store);
}

/// Over strip: smooth auto-scroll to the latest ball, scrollable history.
class OverStrip extends StatefulWidget {
  final List<Ball> balls;
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
        // Slow, smooth glide to the newest ball — never abrupt.
        _ctrl.animateTo(
          _ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
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
              child: i == balls.length - 1
                  ? _PopBadge(
                          key: ValueKey(
                              '${balls.length}-${balls[i].badge}'),
                          child: BallBadge(balls[i],
                              isLatest: true))
                  : BallBadge(balls[i]),
            ),
          if (balls.isEmpty)
            const Text('Over 1 • tap to bowl',
                style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Latest ball fades + scales in slowly instead of popping abruptly.
class _PopBadge extends StatelessWidget {
  final Widget child;
  const _PopBadge({required super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Transform.scale(
            scale: 0.5 + 0.5 * v, child: child),
      ),
    );
  }
}
