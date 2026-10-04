import 'package:flutter/material.dart';

import '../math.dart';
import '../models.dart';
import '../store.dart' show MatchStore;
import '../theme.dart';
import 'widgets.dart';

/// The score display, extracted so the scorer and the live viewer render the
/// exact same thing.
///
/// This is deliberately one widget with a `live` flag rather than two screens:
/// a viewer that drew its own score tile would drift from the scorer's within a
/// release or two, and "the other phone shows something slightly different"
/// is precisely the bug that destroys trust in a shared score.
///
/// `live` viewers get no celebration and no keypad — a remote screen must not
/// flicker or invite input.
class Scoreboard extends StatelessWidget {
  final Match match;
  final Innings innings;
  final StylePreset preset;

  /// Score numeral font family. Null when the selected font has no bundled
  /// face, which is legal — Flutter then falls back to the default.
  final String? scoreFamily;

  /// Advances the hero numerals. Viewers pass the snapshot sequence, so a new
  /// remote ball animates exactly once.
  final int animationGen;

  /// Read-only mode: no celebrations, no input affordances.
  final bool live;

  /// Optional control shown at the end of the over strip. The scorer passes a
  /// button into the over-list sheet; a viewer passes null.
  final Widget? stripTrailing;

  /// Celebration id; ignored when [live].
  final String celebId;

  const Scoreboard({
    required this.match,
    required this.innings,
    required this.preset,
    required this.scoreFamily,
    this.animationGen = 0,
    this.live = false,
    this.stripTrailing,
    this.celebId = 'pop',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final inn = innings;
    final totalOvers = match.config.totalOvers;
    final oversFmt = CricketMath.ballsToOvers(inn.legalDeliveries);
    final crr = CricketMath.calcCRR(inn.runs, inn.legalDeliveries);
    final cur = inn.currentOverBalls;
    final overRuns = cur.fold<int>(0, (s, b) => s + b.totalRuns);
    final overWkts = cur.where((b) => b.isWicket).length;
    final isTeamA = inn.battingTeam == match.config.teamA;
    final target = match.currentInnings == 2 ? match.target : null;
    String? targetLine;
    if (target != null) {
      final need = target - inn.runs;
      final ballsLeft =
          CricketMath.totalBalls(totalOvers) - inn.legalDeliveries;
      final rrr = CricketMath.calcRRR(need, ballsLeft);
      targetLine = need <= 0 ? 'WON' : 'Need $need off $ballsLeft • RRR $rrr';
    }

    return Column(
      children: [
        RepaintBoundary(
            child: Card(
          color: preset.heroBg,
          child: Stack(
            children: [
              Positioned(top: 8, left: 12, child: _CornerMark(preset.heroFg)),
              Positioned(top: 8, right: 12, child: _CornerMark(preset.heroFg)),
              Positioned(
                  bottom: 8, left: 12, child: _CornerMark(preset.heroFg)),
              Positioned(
                  bottom: 8, right: 12, child: _CornerMark(preset.heroFg)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: preset.heroFg.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TeamDot(isTeamA
                              ? MatchStore.teamAColor
                              : MatchStore.teamBColor),
                          const SizedBox(width: 8),
                          Text(inn.battingTeam,
                              style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w800,
                                  color: preset.heroFg)),
                        ],
                      ),
                    ),
                    _numerals(cur, inn),
                    if (inn.isFreeHitActive)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Badge(
                            label: Text('FREE HIT',
                                style: TextStyle(fontWeight: FontWeight.w900))),
                      ),
                    if (targetLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: preset.heroFg.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: preset.heroFg),
                          ),
                          child: Text('TARGET $targetLine',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: preset.heroFg)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: totalOvers == 0
                            ? 0
                            : inn.legalDeliveries / (totalOvers * 6),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                        height: 1,
                        color: preset.heroFg.withValues(alpha: 0.25)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('OVERS', '$oversFmt/$totalOvers'),
                        _stat('CRR', crr),
                        _stat('EXTRAS', '${inn.extrasTotal}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 10),
        RepaintBoundary(
            child: Card(
          color: preset.stripBg,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Fixed 6-ball window — never a half-peeking 7th ball.
                SizedBox(
                    width: 246,
                    child: OverStrip(
                        balls: cur,
                        overNumber: inn.currentOverNumber,
                        gen: animationGen,
                        // A remote innings is never mid-animation on this phone.
                        frozen: live)),
                // The scorer offers a tap-through to the full over list; a
                // viewer has nothing to tap, so it passes null.
                if (stripTrailing != null)
                  stripTrailing!
                else
                  Text('${overRuns}r • ${overWkts}w',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _numerals(List<Ball> cur, Innings inn) {
    final lastBadge = cur.isNotEmpty ? cur.last.badge : '';
    final isW = lastBadge == 'W' || lastBadge.startsWith('W+');
    final isFour = lastBadge == '4' || lastBadge.startsWith('N4');
    final isSix = lastBadge == '6' || lastBadge.startsWith('N6');
    final numStyle = TextStyle(
        fontFamily: scoreFamily,
        fontSize: 68,
        fontWeight: FontWeight.w900,
        height: 1.05,
        color: preset.heroFg,
        fontFeatures: const [FontFeature.tabularFigures()]);
    // Runs and wickets celebrate independently — a boundary never shakes the
    // wicket digit. Finished innings stay calm. A live viewer never celebrates:
    // the scorer already did, on their phone.
    final calm = live || inn.completed || match.completed;
    return Row(
      key: const ValueKey('hero-numerals'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Celebrate(
          key: const ValueKey('hero-runs'),
          mode: live ? 'off' : celebId,
          valueKey: '${inn.runs}',
          fire: (isFour || isSix) && !calm,
          tint: isFour ? const Color(0xFF2DC653) : const Color(0xFFEC008C),
          text: '${inn.runs}',
          style: numStyle,
        ),
        Text('/',
            style: numStyle.copyWith(
                color: preset.heroFg.withValues(alpha: 0.55))),
        Celebrate(
          key: const ValueKey('hero-wickets'),
          mode: live ? 'off' : celebId,
          valueKey: '${inn.wickets}',
          fire: isW && !calm,
          tint: const Color(0xFFDC143C),
          text: '${inn.wickets}',
          style: numStyle,
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: preset.heroFg.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: preset.heroFg)),
        ],
      );
}

/// Tiny corner registration mark, like the reference scoreboard tile.
class _CornerMark extends StatelessWidget {
  final Color c;
  const _CornerMark(this.c);
  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, color: c);
}

class OverStrip extends StatefulWidget {
  final List<Ball> balls;
  final int overNumber;
  final int gen; // advances on score() only — undo never animates
  final bool frozen; // completed innings: zero motion
  const OverStrip(
      {required this.balls,
      required this.overNumber,
      required this.gen,
      this.frozen = false,
      super.key});
  @override
  State<OverStrip> createState() => _OverStripState();
}

class _OverStripState extends State<OverStrip> {
  final ScrollController _ctrl = ScrollController();
  int _swapGen = 0; // bumped on new-over rollover for a soft fade

  @override
  void didUpdateWidget(OverStrip old) {
    super.didUpdateWidget(old);
    if (!_ctrl.hasClients) return;
    // Frozen (completed innings) or undo (same generation): sync silently.
    if (widget.frozen || widget.gen == old.gen) {
      if (_ctrl.position.pixels > _ctrl.position.maxScrollExtent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_ctrl.hasClients) return;
          _ctrl.jumpTo(_ctrl.position.maxScrollExtent);
        });
      }
      return;
    }
    // Fade ONLY on forward rollover into a new over — never on undo.
    if (widget.overNumber > old.overNumber) {
      setState(() => _swapGen++);
      return;
    }
    final shift = (widget.balls.length - old.balls.length).abs();
    if (shift > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_ctrl.hasClients) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _ctrl.jumpTo(_ctrl.position.maxScrollExtent);
          return;
        }
        // Distance-based glide to the latest balls — never abrupt.
        _ctrl.animateTo(
          _ctrl.position.maxScrollExtent,
          duration: Motion.glide(shift),
          curve: Motion.curve,
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
    if (_ctrl.hasClients &&
        _ctrl.position.pixels > _ctrl.position.maxScrollExtent) {
      // Clamp only — no visible snap (position already beyond content).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_ctrl.hasClients) return;
        _ctrl.jumpTo(_ctrl.position.maxScrollExtent);
      });
    }
    final row = SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Gaps between badges only — exactly 6 full balls per window.
          for (int i = 0; i < balls.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == balls.length - 1 ? 0 : 6),
              child: BallBadge(balls[i]),
            ),
          if (balls.isEmpty)
            const Text('Over 1 • tap to bowl', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
    if (_swapGen == 0) return row;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_swapGen),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (_, v, __) => Opacity(opacity: v, child: row),
    );
  }
}
