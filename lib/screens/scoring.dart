import 'package:flutter/material.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets.dart';
import 'scoreboard.dart';
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
                                                    BorderRadius.circular(20)),
                                          ),
                                          onPressed: store.canUndo
                                              ? () => store.undo()
                                              : null,
                                          child:
                                              const Icon(Icons.undo, size: 28),
                                        ),
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
    final err = store.score(action: action, runs: runs);
    if (err != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _wicketDialog(BuildContext context) => showWicketDialog(context, store);
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
