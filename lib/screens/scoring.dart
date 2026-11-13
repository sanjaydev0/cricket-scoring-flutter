import 'package:flutter/material.dart';

import '../domain/players.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets.dart';
import 'scoreboard.dart';
import 'sheets.dart';
import 'player_sheets.dart';

class ScoringScreen extends StatefulWidget {
  final MatchStore store;
  const ScoringScreen(this.store, {super.key});

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  MatchStore get store => widget.store;

  /// Which innings the picker has already been offered for.
  ///
  /// The picker opens ITSELF when the openers are missing: after START
  /// SCORING the umpire should not have to hunt for a "SET" button, and the
  /// same is true at the start of the second innings. Once offered, it is not
  /// offered again in that innings — the blue SET card stays as the fallback.
  int? _offeredInnings;

  void _offerInningsStart() {
    final store = widget.store;
    final m = store.match;
    if (m == null || !m.config.trackPlayers) return;
    final sheet = store.currentSheet;
    if (sheet == null) return;
    // Nothing to ask: both batters are in and the bowler is picked.
    if (sheet.strikerId != null && sheet.bowlerId != null) return;
    if (_offeredInnings == m.currentInnings) return;
    _offeredInnings = m.currentInnings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showInningsStartSheet(context, store);
    });
  }

  @override
  Widget build(BuildContext context) {
    _offerInningsStart();
    return ListenableBuilder(
      listenable: widget.store,
      builder: (_, _) {
        final store = widget.store;
        final m = store.match;
        if (m == null) {
          return const Scaffold(body: Center(child: Text('No live match')));
        }
        if (m.completed && store.breakDest == null) {
          goOnce(context, '/result');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (m.currentInnings == 1 &&
            m.innings1.completed &&
            store.breakDest == null) {
          goOnce(context, '/break');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final inn = store.innings!;
        // Team identity travels as a solid band, never a tint. It comes from
        // the match, not from a literal, so both sides get their own colour.
        final teamColor = Color(
          inn.battingTeam == m.config.teamA
              ? MatchStore.teamAColor
              : MatchStore.teamBColor,
        );
        final nb = store.nbArmed;
        final preset = StylePreset.of(store.styleId);
        final scoreFamily = ScoreFonts.family(store.fontId);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'INN ${m.currentInnings} • ${inn.battingTeam}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            actions: [
              IconButton(
                icon: Icon(store.soundOn ? Icons.volume_up : Icons.volume_off),
                tooltip: store.soundOn ? 'Mute sounds' : 'Unmute',
                onPressed: () => store.setSound(!store.soundOn),
              ),
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'Overs',
                onPressed: () => _oversSheet(context),
              ),
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                tooltip: 'Style & font',
                onPressed: () => showLookSheet(context, store),
              ),
            ],
          ),
          body: SafeArea(
            child: ResponsiveCenter(
              maxWidth: 640,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Scoreboard(
                    match: m,
                    innings: inn,
                    preset: preset,
                    scoreFamily: scoreFamily,
                    animationGen: store.ballGen,
                    celebId: store.isBatterySaverOn ? 'off' : store.celebId,
                    // A compact tap-through, not a TextButton: the button's
                    // own padding pushed the strip row past the card edge
                    // on a 360dp phone.
                    stripTrailing: _stripTrailing(context, store, inn),
                  ),
                  if (store.breakDest != null) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: context.tokens.primaryFill,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                store.breakDest == '/break'
                                    ? 'INNINGS COMPLETE — BREAK IN ${store.breakWait}s'
                                    : 'MATCH OVER — RESULT IN ${store.breakWait}s',
                                style: TextStyle(
                                  color: context.tokens.onPrimaryFill,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            RectBtn(
                              onTap: () => store.skipBreakWait(),
                              child: const Text('NEXT →'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (store.tracking &&
                      store.currentSheet?.needsNewBowler == true) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: teamColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'SELECT THE NEW BOWLER TO CONTINUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            RectBtn(
                              primary: false,
                              onTap: () =>
                                  showBowlerSheet(context, store, auto: true),
                              child: const Text('SET'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (store.tracking &&
                      (store.currentSheet?.strikerId == null ||
                          store.currentSheet?.bowlerId == null)) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: teamColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'SET BATTERS + BOWLER TO START',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            RectBtn(
                              primary: false,
                              onTap: () =>
                                  showInningsStartSheet(context, store),
                              child: const Text('SET'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  RepaintBoundary(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (nb)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Center(
                                  child: Text(
                                    'NB ARMED',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: context.events.eventNoBall.fill,
                                    ),
                                  ),
                                ),
                              ),
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                                  onTap: () => _tap(context, 'DOT'),
                                ),
                                KeyBtn(
                                  label: '1',
                                  sub: nb ? 'N1' : 'RUN',
                                  armed: nb,
                                  radius: preset.keyRadius,
                                  color: Colors.white,
                                  fg: Colors.black,
                                  onTap: () => _tap(context, 'RUNS', runs: 1),
                                ),
                                KeyBtn(
                                  label: '2',
                                  sub: nb ? 'N2' : 'RUNS',
                                  armed: nb,
                                  radius: preset.keyRadius,
                                  color: Colors.white,
                                  fg: Colors.black,
                                  onTap: () => _tap(context, 'RUNS', runs: 2),
                                ),
                                KeyBtn(
                                  label: '3',
                                  sub: nb ? 'N3' : 'RUNS',
                                  armed: nb,
                                  radius: preset.keyRadius,
                                  color: Colors.white,
                                  fg: Colors.black,
                                  onTap: () => _tap(context, 'RUNS', runs: 3),
                                ),
                                KeyBtn(
                                  label: '4',
                                  sub: nb ? 'N4' : 'FOUR',
                                  color: context.events.eventFour.fill,
                                  fg: context.events.eventFour.ink,
                                  armed: nb,
                                  radius: preset.keyRadius,
                                  onTap: () => _tap(context, 'FOUR'),
                                ),
                                KeyBtn(
                                  label: '6',
                                  sub: nb ? 'N6' : 'SIX',
                                  color: context.events.eventSix.fill,
                                  fg: context.events.eventSix.ink,
                                  armed: nb,
                                  radius: preset.keyRadius,
                                  onTap: () => _tap(context, 'SIX'),
                                ),
                                KeyBtn(
                                  label: 'WD',
                                  sub: '+${m.config.rules.widePenalty}',
                                  color: context.events.eventWide.fill,
                                  fg: context.events.eventWide.ink,
                                  radius: preset.keyRadius,
                                  onTap: () => _tap(context, 'WIDE'),
                                ),
                                KeyBtn(
                                  label: 'NB',
                                  sub: nb
                                      ? 'ARMED'
                                      : '+${m.config.rules.noBallPenalty}',
                                  color: context.events.eventNoBall.fill,
                                  fg: context.events.eventNoBall.ink,
                                  armed: nb,
                                  radius: preset.keyRadius,
                                  onTap: () => store.toggleNb(),
                                ),
                                KeyBtn(
                                  label: 'W',
                                  sub: 'WICKET',
                                  color: context.events.eventWicket.fill,
                                  fg: context.events.eventWicket.ink,
                                  radius: preset.keyRadius,
                                  onTap: () => _wicketDialog(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (store.tracking) ...[
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 72,
                                            height: 72,
                                            child: FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF1D4ED8,
                                                ),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  showPlayerStatsSheet(
                                                    context,
                                                    store,
                                                  ),
                                              child: const Icon(
                                                Icons.groups_outlined,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'PLAYERS',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF0A0A0A,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            onPressed: store.canUndo
                                                ? () => store.undo()
                                                : null,
                                            child: const Icon(
                                              Icons.undo,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'UNDO',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (store.advancedExtras) ...[
                                      const SizedBox(width: 10),
                                      FilledButton.tonal(
                                        onPressed: () => _moreSheet(context),
                                        child: const Text('EXTRAS'),
                                      ),
                                    ],
                                  ],
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _settingsSheet(context),
                                      child: const Icon(
                                        Icons.settings_outlined,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  void _tap(BuildContext ctx, String action, {int runs = 0}) {
    final err = store.score(action: action, runs: runs);
    if (err != null) {
      // Gated states reopen their picker instead of only snacking: the umpire
      // is one tap from unblocked, with no hunting for the right sheet.
      if (err == MatchStore.needBowlerMsg) {
        showBowlerSheet(ctx, store, auto: true);
        return;
      }
      if (err == MatchStore.needSetupMsg) {
        showInningsStartSheet(ctx, store);
        return;
      }
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // The store arms ONE latch when the sixth legal ball completes an over.
    // Ask here — right after that ball — and nowhere else. The previous code
    // also derived "the over ended" from the strip's over number, which
    // re-fired on the first ball of the new over and asked a second time for
    // an over the umpire had already answered.
    if (store.tracking && store.currentSheet?.needsNewBowler == true) {
      showBowlerSheet(ctx, store, auto: true);
    }
  }

  void _wicketDialog(BuildContext context) {
    if (!store.tracking) {
      showWicketDialog(context, store);
      return;
    }
    if (store.nbArmed || (store.innings?.isFreeHitActive ?? false)) {
      showRunOutSheet(context, store);
      return;
    }
    final simple = !store.complexWickets;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('RECORD DISMISSAL'),
        content: SizedBox(
          width: 340,
          // A dialog does not scroll its own content, so six wicket keys can
          // run past the bottom on a short screen. The scroll view is cheap.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECT WICKET TYPE',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: [
                    _tWicketKey(context, DismissalType.bowled),
                    if (!simple) _tWicketKey(context, DismissalType.caught),
                    _tWicketKey(context, DismissalType.runOut),
                    if (!simple) ...[
                      _tWicketKey(context, DismissalType.lbw),
                      _tWicketKey(context, DismissalType.stumped),
                      _tWicketKey(context, DismissalType.hitWicket),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('✕'),
          ),
        ],
      ),
    );
  }

  Widget _tWicketKey(BuildContext context, DismissalType type) {
    return RectBtn(
      primary: false,
      onTap: () {
        Navigator.pop(context);
        if (type == DismissalType.runOut) {
          // Run-out has its own sheet: runs completed, who was out, which
          // end. No other dismissal asks those, so no wicket-type pills.
          showRunOutSheet(context, store);
          return;
        }
        // A plain dismissal asks one question: who comes next. Going through
        // the full sheet for it cost taps and showed options that do not apply.
        if (type == DismissalType.bowled && store.tracking) {
          showNextBatterSheet(context, store, type: type);
          return;
        }
        showDismissalSheet(context, store, type);
      },
      child: Text(
        type == DismissalType.runOut
            ? 'RUN OUT ›'
            : type == DismissalType.bowled
            ? 'WICKET'
            : type.label.toUpperCase(),
      ),
    );
  }

  void _oversSheet(BuildContext context) => showOversSheet(context, store);

  /// The over strip's tail.
  ///
  /// Before the first ball of an innings the `0r • 0w ›` tail has nothing to
  /// say, so it becomes the one place to change the openers or the bowler —
  /// and only once all three are already set, so it never competes with the
  /// blue `SET BATTERS + BOWLER TO START` card. After the first ball the tail
  /// is the overs tap-through again; mid-innings changes live in PLAYERS.
  Widget _stripTrailing(BuildContext context, MatchStore store, Innings inn) {
    final sheet = store.currentSheet;
    final editable =
        store.tracking &&
        inn.legalDeliveries == 0 &&
        sheet != null &&
        sheet.strikerId != null &&
        sheet.nonStrikerId != null &&
        sheet.bowlerId != null;
    final cur = inn.currentOverBalls;
    if (!editable) {
      return InkWell(
        onTap: () => _oversSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${cur.fold<int>(0, (s, b) => s + b.totalRuns)}r • ${cur.where((b) => b.isWicket).length}w',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16),
            ],
          ),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Change openers or bowler',
      child: InkWell(
        onTap: () => showInningsStartSheet(context, store),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: context.tokens.surfaceOutline,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 14, color: cs.onSurface),
              const SizedBox(width: 4),
              Text(
                'EDIT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moreSheet(BuildContext context) => showExtrasSheet(context, store);
  void _settingsSheet(BuildContext context) =>
      showSettingsSheet(context, store);
}
