import 'package:flutter/material.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets.dart';
import 'scoreboard.dart';
import 'sheets.dart';
import 'player_sheets.dart';

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
          return const Scaffold(body: Center(child: Text('No live match')));
        }
        if (m.completed && store.breakDest == null) {
          goOnce(context, '/result');
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (m.currentInnings == 1 &&
            m.innings1.completed &&
            store.breakDest == null) {
          goOnce(context, '/break');
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final inn = store.innings!;
        final cur = inn.currentOverBalls;
        final nb = store.nbArmed;
        final preset = StylePreset.of(store.styleId);
        final scoreFamily = ScoreFonts.family(store.fontId);

        return Scaffold(
          appBar: AppBar(
            title: Text('INN ${m.currentInnings} • ${inn.battingTeam}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            actions: [
              if (store.roomCode != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  child: Text(store.roomCode!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.white)),
                ),
                IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: 'Stop sharing',
                    onPressed: () => store.stopSharing()),
              ] else
                IconButton(
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Share live score',
                    onPressed: () => _shareSheet(context)),
              IconButton(
                  icon:
                      Icon(store.soundOn ? Icons.volume_up : Icons.volume_off),
                  tooltip: store.soundOn ? 'Mute sounds' : 'Unmute',
                  onPressed: () => store.setSound(!store.soundOn)),
              IconButton(
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'Overs',
                  onPressed: () => _oversSheet(context)),
              IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: 'Style & font',
                  onPressed: () => showLookSheet(context, store)),
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
                        celebId: store.celebId,
                        stripTrailing: TextButton(
                          onPressed: () => _oversSheet(context),
                          child: Text(
                              '${cur.fold<int>(0, (s, b) => s + b.totalRuns)}r • ${cur.where((b) => b.isWicket).length}w ›',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      if (store.breakDest != null) ...[
                        const SizedBox(height: 10),
                        Card(
                          color: const Color(0xFF131316),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    store.breakDest == '/break'
                                        ? 'INNINGS COMPLETE — BREAK IN ${store.breakWait}s'
                                        : 'MATCH OVER — RESULT IN ${store.breakWait}s',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1),
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
                          color: const Color(0xFF1D4ED8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'SELECT THE NEW BOWLER TO CONTINUE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1),
                                  ),
                                ),
                                RectBtn(
                                  primary: false,
                                  onTap: () => showBowlerSheet(context, store,
                                      auto: true),
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
                          color: const Color(0xFF1D4ED8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'SET BATTERS + BOWLER TO START',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1),
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
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Center(
                                    child: Text('NB ARMED',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                            color: Color(0xFF7B2CBF))),
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
                                      onTap: () => _tap(context, 'DOT')),
                                  KeyBtn(
                                      label: '1',
                                      sub: nb ? 'N1' : 'RUN',
                                      armed: nb,
                                      radius: preset.keyRadius,
                                      color: Colors.white,
                                      fg: Colors.black,
                                      onTap: () =>
                                          _tap(context, 'RUNS', runs: 1)),
                                  KeyBtn(
                                      label: '2',
                                      sub: nb ? 'N2' : 'RUNS',
                                      armed: nb,
                                      radius: preset.keyRadius,
                                      color: Colors.white,
                                      fg: Colors.black,
                                      onTap: () =>
                                          _tap(context, 'RUNS', runs: 2)),
                                  KeyBtn(
                                      label: '3',
                                      sub: nb ? 'N3' : 'RUNS',
                                      armed: nb,
                                      radius: preset.keyRadius,
                                      color: Colors.white,
                                      fg: Colors.black,
                                      onTap: () =>
                                          _tap(context, 'RUNS', runs: 3)),
                                  KeyBtn(
                                      label: '4',
                                      sub: nb ? 'N4' : 'FOUR',
                                      color: const Color(0xFF15803D),
                                      fg: Colors.white,
                                      armed: nb,
                                      radius: preset.keyRadius,
                                      onTap: () => _tap(context, 'FOUR')),
                                  KeyBtn(
                                      label: '6',
                                      sub: nb ? 'N6' : 'SIX',
                                      color: const Color(0xFFEC008C),
                                      fg: Colors.white,
                                      armed: nb,
                                      radius: preset.keyRadius,
                                      onTap: () => _tap(context, 'SIX')),
                                  KeyBtn(
                                      label: 'WD',
                                      sub: '+${m.config.rules.widePenalty}',
                                      color: const Color(0xFFFFBA08),
                                      fg: Colors.black,
                                      radius: preset.keyRadius,
                                      onTap: () => _tap(context, 'WIDE')),
                                  KeyBtn(
                                      label: 'NB',
                                      sub: nb
                                          ? 'ARMED'
                                          : '+${m.config.rules.noBallPenalty}',
                                      color: const Color(0xFF7B2CBF),
                                      fg: Colors.white,
                                      armed: nb,
                                      radius: preset.keyRadius,
                                      onTap: () => store.toggleNb()),
                                  KeyBtn(
                                      label: 'W',
                                      sub: 'WICKET',
                                      color: const Color(0xFFDC143C),
                                      fg: Colors.white,
                                      radius: preset.keyRadius,
                                      onTap: () => _wicketDialog(context)),
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
                                                  backgroundColor:
                                                      const Color(0xFF1D4ED8),
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.zero,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20)),
                                                ),
                                                onPressed: () =>
                                                    showPlayerStatsSheet(
                                                        context, store),
                                                child: const Icon(
                                                    Icons.groups_outlined,
                                                    size: 28),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text('PLAYERS',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w800)),
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
                                                backgroundColor:
                                                    const Color(0xFF0A0A0A),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20)),
                                              ),
                                              onPressed: store.canUndo
                                                  ? () => store.undo()
                                                  : null,
                                              child: const Icon(Icons.undo,
                                                  size: 28),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text('UNDO',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800)),
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
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                        ),
                                        onPressed: () =>
                                            _settingsSheet(context),
                                        child: const Icon(
                                            Icons.settings_outlined,
                                            size: 22),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ))),
        );
      },
    );
  }

  void _tap(BuildContext ctx, String action, {int runs = 0}) {
    return _tapInner(ctx, action, runs: runs);
  }

  void _tapInner(BuildContext ctx, String action, {int runs = 0}) {
    final beforeOver = store.innings?.currentOverNumber ?? 1;
    final beforeLegal = store.innings?.legalDeliveries ?? 0;
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
    // The over just finished: prompt the next bowler immediately, while the
    // captain is deciding. Never on innings end, and never twice for the same
    // over: deferred rollover starts the new over on the NEXT delivery, which
    // re-fires the overNumber branch after a pick. The latch below is what
    // stops that — same over + bowler already changed means handled.
    final inn = store.innings;
    final sheet = store.currentSheet;
    final completedCount = inn == null ? 0 : inn.legalDeliveries ~/ 6;
    final overDone = store.tracking &&
        inn != null &&
        !inn.completed &&
        (inn.currentOverNumber != beforeOver ||
            (inn.legalDeliveries - beforeLegal > 0 &&
                inn.legalDeliveries % 6 == 0));
    if (overDone && sheet != null) {
      final handled = sheet.promptedOver == completedCount &&
          sheet.bowlerId != sheet.promptedBowler;
      if (!handled) {
        sheet.promptedOver = completedCount;
        sheet.promptedBowler = sheet.bowlerId;
        store.persistOnly();
        showBowlerSheet(ctx, store, auto: true);
      }
    }
  }

  void _wicketDialog(BuildContext context) {
    if (!store.tracking) {
      showWicketDialog(context, store);
      return;
    }
    if (store.nbArmed || (store.innings?.isFreeHitActive ?? false)) {
      showDismissalSheet(context, store, 'Run Out');
      return;
    }
    final simple = !store.complexWickets;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('RECORD DISMISSAL'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SELECT WICKET TYPE',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: [
                  _tWicketKey(context, 'BOWLED', 'Bowled'),
                  if (!simple) _tWicketKey(context, 'CAUGHT', 'Caught'),
                  _tWicketKey(context, 'RUN OUT ›', 'Run Out'),
                  if (!simple) ...[
                    _tWicketKey(context, 'LBW', 'LBW'),
                    _tWicketKey(context, 'STUMPED', 'Stumped'),
                    _tWicketKey(context, 'HIT WICKET', 'Hit Wicket'),
                  ],
                ],
              ),
            ],
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

  Widget _tWicketKey(BuildContext context, String label, String type) {
    return RectBtn(
      primary: false,
      onTap: () {
        Navigator.pop(context);
        showDismissalSheet(context, store, type);
      },
      child: Text(label),
    );
  }

  void _oversSheet(BuildContext context) => showOversSheet(context, store);
  void _moreSheet(BuildContext context) => showExtrasSheet(context, store);
  void _settingsSheet(BuildContext context) =>
      showSettingsSheet(context, store);

  /// Opens a live room. Sharing is strictly additive: if no backend is
  /// configured, or the sign-in failed, this says so plainly instead of
  /// pretending, and the match is untouched either way.
  Future<void> _shareSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await store.startSharing();
    if (!context.mounted) return;
    // Names the actual cause. The first version reported every failure as
    // "no backend configured in this build", which sent the diagnosis after
    // the build flags instead of the real error.
    messenger.showSnackBar(SnackBar(
      content:
          Text(result.ok ? '${result.message} (read-only)' : result.message),
      duration: const Duration(seconds: 6),
    ));
  }
}
