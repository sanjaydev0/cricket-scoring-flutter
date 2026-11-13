import 'package:flutter/material.dart';

import '../domain/players.dart';
import '../math.dart';
import '../store.dart';
import '../theme.dart';
import 'player_sheets.dart';
import 'scorecard.dart';
import 'widgets.dart';

/// Scoring dialogs & sheets in the reference layout:
/// pill headers, 2-col grids, segmented pills, dark SAVE/CLOSE.
/// Decorative text purged — titles, values and actions only.

void showWicketDialog(BuildContext context, MatchStore store) {
  // Armed no-ball or free hit: Laws allow only a run-out — skip the grid.
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
        // A dialog does not scroll its own content, so six wicket keys can run
        // past the bottom on a short screen.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Select wicket type'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: [
                  _wicketKey(context, store, DismissalType.bowled),
                  if (!simple) _wicketKey(context, store, DismissalType.caught),
                  _wicketKey(context, store, DismissalType.runOut),
                  if (!simple) ...[
                    _wicketKey(context, store, DismissalType.lbw),
                    _wicketKey(context, store, DismissalType.stumped),
                    _wicketKey(context, store, DismissalType.hitWicket),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        RectBtn(
          primary: false,
          onTap: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    ),
  );
}

Widget _wicketKey(BuildContext context, MatchStore store, DismissalType type) {
  return RectBtn(
    primary: false,
    onTap: () {
      Navigator.pop(context);
      if (type == DismissalType.runOut) {
        // Run-out asks three questions of its own, and it is the only
        // dismissal that does. The four-button grid that used to live here
        // never asked the end and always dismissed the striker, so the same
        // physical run-out scored differently from the tracked flow.
        showRunOutSheet(context, store);
        return;
      }
      // The enum travels with its label. A display string that did not match
      // the enum exactly (`'Hit Wicket'` versus `Hit wicket`) used to be
      // recorded as bowled.
      store.score(
        action: 'WICKET',
        wicketType: type.label,
        dismissal: type.name,
      );
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

void showOversSheet(BuildContext context, MatchStore store) {
  final inn = store.innings!;
  final m = store.match!;
  final innIdx = m.currentInnings;
  final overs = [
    for (final o in inn.overs)
      if (o.balls.isNotEmpty) o,
  ];
  showAppSheet(
    context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              title: 'Overs history',
              caption:
                  'Innings $innIdx · ${inn.battingTeam} ${inn.runs}/${inn.wickets} '
                  '(${CricketMath.ballsToOvers(inn.legalDeliveries)} ov)',
              onClose: () => Navigator.pop(ctx),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RectBtn(
                    primary: false,
                    onTap: () {
                      Navigator.pop(ctx);
                      showScorecard(context, store, inningsNo: innIdx);
                    },
                    child: const Text('SCORECARD'),
                  ),
                  const SizedBox(height: 12),
                  // Every over is a row of one table: number, runs, wickets,
                  // then the six badges. A card per over made six frames for
                  // six lines.
                  RectCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < overs.length; i++)
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              border: i == overs.length - 1
                                  ? null
                                  : Border(
                                      bottom: BorderSide(
                                        color: context.tokens.borderRow,
                                      ),
                                    ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'OVER ${overs[i].overNumber.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${overs[i].balls.fold<int>(0, (s, b) => s + b.totalRuns)} RUNS  ·  '
                                      '${overs[i].balls.where((b) => b.isWicket).length} WKT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: context.tokens.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final b in overs[i].balls)
                                      BallBadge(b),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showExtrasSheet(BuildContext context, MatchStore store) {
  showAppSheet(
    context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _pillGroup('BYES', ['B1', 'B2', 'B4'], (label) {
              final runs = int.parse(label.substring(1));
              Navigator.pop(context);
              store.score(action: 'BYE', runs: runs);
            }),
            _pillGroup('LEG-BYES', ['LB1', 'LB2', 'LB4'], (label) {
              final runs = int.parse(label.substring(2));
              Navigator.pop(context);
              store.score(action: 'LEGBYE', runs: runs);
            }),
            _pillGroup('WIDE +', ['WD', 'WD+1', 'WD+2', 'WD+4'], (label) {
              final runs = label == 'WD' ? 0 : int.parse(label.substring(3));
              Navigator.pop(context);
              store.score(action: 'WIDE', runs: runs);
            }),
            _pillGroup('NO-BALL +', ['NB', 'NB+1', 'NB+2', 'NB+4', 'NB+6'], (
              label,
            ) {
              final runs = label == 'NB' ? 0 : int.parse(label.substring(3));
              Navigator.pop(context);
              store.score(action: 'NB_DIRECT', runs: runs);
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}

Widget _pillGroup(
  String title,
  List<String> opts,
  ValueChanged<String> onPick,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final o in opts)
              RectBtn(primary: false, onTap: () => onPick(o), child: Text(o)),
          ],
        ),
      ],
    ),
  );
}

/// Mid-match config, bento layout: two stepper tiles, a rule chip strip,
/// two side-by-side XI columns and one shared bench pool. Rules stay pending
/// until SAVE; squad ticks land immediately (each is its own undo snapshot).
void showSettingsSheet(BuildContext context, MatchStore store) {
  final m = store.match!;
  final cfg = m.config;
  int overs = cfg.totalOvers;
  int players = cfg.playersPerSide;
  int common = cfg.commonPlayers;
  int wide = cfg.rules.widePenalty;
  int noball = cfg.rules.noBallPenalty;
  bool freeHit = cfg.rules.freeHit;
  bool lms = cfg.rules.lastManStanding;
  // Bench search + expand state belong to the sheet so they survive the
  // rebuild after every squad tick.
  final benchCtrl = TextEditingController();
  var benchAll = false;
  final tagA = _teamTag(cfg.teamA);
  final tagB = _teamTag(cfg.teamB);

  bool isDirty() =>
      overs != cfg.totalOvers ||
      players != cfg.playersPerSide ||
      common != cfg.commonPlayers ||
      wide != cfg.rules.widePenalty ||
      noball != cfg.rules.noBallPenalty ||
      freeHit != cfg.rules.freeHit ||
      lms != cfg.rules.lastManStanding;

  String? savePending() => store.applyMidMatch(
    totalOvers: overs,
    playersPerSide: players,
    commonPlayers: common,
    widePenalty: wide,
    noBallPenalty: noball,
    freeHit: freeHit,
    lastManStanding: lms,
  );

  void toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // Leaving with pending rule edits asks first. Squad ticks are already
  // committed, so only overs/rules/double-side can be "unsaved".
  void confirmClose(BuildContext sheetCtx) {
    if (!isDirty()) {
      Navigator.pop(sheetCtx);
      return;
    }
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('SAVE CHANGES?'),
        content: const Text(
          'Overs, rules or double-side were changed and are not saved yet.',
        ),
        actions: [
          RectBtn(
            primary: false,
            onTap: () {
              Navigator.pop(dCtx);
              Navigator.pop(sheetCtx);
            },
            child: const Text('NO, DISCARD'),
          ),
          RectBtn(
            onTap: () {
              final err = savePending();
              if (err != null) {
                Navigator.pop(dCtx);
                toast(err);
                return;
              }
              Navigator.pop(dCtx);
              Navigator.pop(sheetCtx);
              toast('Saved');
            },
            child: const Text('YES, SAVE'),
          ),
        ],
      ),
    );
  }

  // Double-side carries side effects: +1 player slot on, and every shared
  // pick is un-shared (and the slot returned) off.
  void setCommon(int next) {
    if (next == common) return;
    if (next > 0) {
      players = players < 15 ? players + 1 : players;
      common = 1;
      return;
    }
    for (final id in cfg.squadA.where(cfg.squadB.contains).toList()) {
      final err = store.removeCommonPlayer(id);
      if (err != null) {
        toast(err);
        return;
      }
    }
    players = players > 2 ? players - 1 : players;
    common = 0;
  }

  showAppSheet(
    context,
    // No drag-dismiss: a downward swipe pops the route directly and would
    // throw pending rule edits away without ever reaching confirmClose.
    showDragHandle: false,
    enableDrag: false,
    isDismissible: false,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheet) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          confirmClose(sheetCtx);
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'MID-MATCH CONFIG',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 13,
                            ),
                          ),
                          if (isDirty()) ...[
                            const SizedBox(width: 8),
                            const _UnsavedBadge(),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => confirmClose(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _bentoPair(
                  context,
                  a: _bentoTile(
                    context,
                    label: 'OVERS',
                    child: _bentoStepper(
                      context,
                      label: 'overs',
                      value: overs,
                      min: 1,
                      max: 50,
                      onChanged: (v) => setSheet(() => overs = v),
                    ),
                  ),
                  b: _bentoTile(
                    context,
                    label: 'PLAYERS / SIDE',
                    child: _bentoStepper(
                      context,
                      label: 'players per side',
                      value: players,
                      min: 2,
                      max: 15,
                      onChanged: (v) => setSheet(() => players = v),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RuleChip(
                      label: 'DOUBLE',
                      value: common > 0 ? 'ONE' : 'NONE',
                      active: common > 0,
                      onTap: () =>
                          setSheet(() => setCommon(common > 0 ? 0 : 1)),
                    ),
                    _RuleChip(
                      label: 'WIDE',
                      value: wide > 0 ? '+1' : '+0',
                      active: wide > 0,
                      onTap: () => setSheet(() => wide = wide > 0 ? 0 : 1),
                    ),
                    _RuleChip(
                      label: 'NO-BALL',
                      value: noball > 0 ? '+1' : '+0',
                      active: noball > 0,
                      onTap: () => setSheet(() => noball = noball > 0 ? 0 : 1),
                    ),
                    _RuleChip(
                      label: 'FREE HIT',
                      value: freeHit ? 'ON' : 'OFF',
                      active: freeHit,
                      onTap: () => setSheet(() => freeHit = !freeHit),
                    ),
                    _RuleChip(
                      label: 'LAST MAN',
                      value: lms ? 'ON' : 'OFF',
                      active: lms,
                      onTap: () => setSheet(() => lms = !lms),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (store.tracking) ...[
                  _squadHeader(context),
                  const SizedBox(height: 6),
                  _squadColumns(
                    context,
                    store: store,
                    setSheet: setSheet,
                    cap: players,
                  ),
                  const SizedBox(height: 8),
                  _BenchPool(
                    store: store,
                    setSheet: setSheet,
                    ctrl: benchCtrl,
                    cap: players,
                    common: common,
                    showAll: benchAll,
                    onToggleAll: () => setSheet(() => benchAll = !benchAll),
                    onCreate: () => _showCreatePlayer(context, store, setSheet),
                  ),
                ] else
                  Text(
                    'Player tracking is off — squads are fixed for this match.',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: RectBtn(
                        primary: false,
                        onTap: () => confirmClose(sheetCtx),
                        child: const Text('CANCEL'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RectBtn(
                        onTap: () {
                          final err = savePending();
                          if (err != null) {
                            toast(err);
                            return;
                          }
                          Navigator.pop(sheetCtx);
                          toast('Config saved');
                        },
                        child: const Text('✓ SAVE CONFIG'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'DECLARE WINNER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ends the match now and archives the result.',
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RectBtn(
                        primary: false,
                        onTap: () => _declareWinner(
                          context,
                          store,
                          cfg.teamA,
                          unsaved: isDirty(),
                          sheetCtx: sheetCtx,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const TeamDot(MatchStore.teamAColor, size: 10),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tagA,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RectBtn(
                        primary: false,
                        onTap: () => _declareWinner(
                          context,
                          store,
                          cfg.teamB,
                          unsaved: isDirty(),
                          sheetCtx: sheetCtx,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const TeamDot(MatchStore.teamBColor, size: 10),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tagB,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RectBtn(
                  danger: true,
                  onTap: () =>
                      _confirmAbandon(context, store, sheetCtx: sheetCtx),
                  child: const Text('ABANDON MATCH'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _declareWinner(
  BuildContext context,
  MatchStore store,
  String team, {
  required bool unsaved,
  required BuildContext sheetCtx,
}) {
  final tag = _teamTag(team);
  final colorValue = team == store.match?.config.teamA
      ? MatchStore.teamAColor
      : MatchStore.teamBColor;
  showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Text('DECLARE $tag WINNER?'),
      content: Text(
        'The match ends now and the result is archived.'
        '${unsaved ? '\n\nUnsaved overs or rule changes are discarded.' : ''}',
      ),
      actions: [
        RectBtn(
          primary: false,
          onTap: () => Navigator.pop(dCtx),
          child: const Text('NO'),
        ),
        RectBtn(
          onTap: () {
            store.declareWinner(team);
            Navigator.pop(dCtx);
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            Navigator.pushReplacementNamed(context, '/result');
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TeamDot(colorValue, size: 10),
              const SizedBox(width: 6),
              Flexible(
                child: Text('YES — $tag WINS', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _confirmAbandon(
  BuildContext context,
  MatchStore store, {
  required BuildContext sheetCtx,
}) {
  showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: const Text('ABANDON MATCH?'),
      content: const Text(
        'The live match is deleted. Nothing is archived, undo history is '
        'cleared, and this cannot be undone.',
      ),
      actions: [
        RectBtn(
          primary: false,
          onTap: () => Navigator.pop(dCtx),
          child: const Text('NO'),
        ),
        RectBtn(
          danger: true,
          onTap: () {
            store.abandon();
            Navigator.pop(dCtx);
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          },
          child: const Text('YES, ABANDON'),
        ),
      ],
    ),
  );
}

/// Compact style + font + celebration picker (palette icon in AppBar).
void showLookSheet(BuildContext context, MatchStore store) {
  showAppSheet(
    context,
    showDragHandle: true,
    builder: (_) => ListenableBuilder(
      listenable: store,
      builder: (_, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STYLE',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in StylePreset.ids)
                    ChoiceChip(
                      label: Text(StylePreset.of(id).name),
                      selected: store.styleId == id,
                      onSelected: (_) => store.setStyle(id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'SCORE FONT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in ScoreFonts.ids)
                    ChoiceChip(
                      label: Text(
                        '142/7',
                        style: TextStyle(
                          fontFamily: ScoreFonts.family(id),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      selected: store.fontId == id,
                      onSelected: (_) => store.setFont(id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'CELEBRATION',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in MatchStore.celebIds)
                    ChoiceChip(
                      label: Text(MatchStore.celebNames[id]!),
                      selected: store.celebId == id,
                      onSelected: (_) => store.setCeleb(id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Short, unambiguous tag for a team name — `BLUE XI` becomes `BLUE`, and a
/// two-word name keeps only its first word so it fits a 60dp assign button.
String _teamTag(String team) {
  final t = team.trim();
  if (t.isEmpty) return 'TEAM';
  final first = t.split(RegExp(r'\s+')).first.toUpperCase();
  return first.length <= 7 ? first : first.substring(0, 7);
}

/// Has this player batted or bowled in the live innings? Such a player can
/// never be benched: the figures already reference him.
bool _hasPlayed(MatchStore store, String id) {
  final sheet = store.currentSheet;
  final b = sheet?.batting[id];
  final w = sheet?.bowling[id];
  return (b != null && b.position > 0) ||
      (w != null && (w.balls > 0 || w.wickets > 0));
}

/// Two bento tiles side by side, stacking under 360dp so the steppers keep
/// their 44dp targets instead of being crushed.
Widget _bentoPair(
  BuildContext context, {
  required Widget a,
  required Widget b,
}) {
  final sp = context.spacing;
  return LayoutBuilder(
    builder: (c, cons) {
      if (cons.maxWidth < 360) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            a,
            SizedBox(height: sp.sm),
            b,
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            SizedBox(width: sp.sm),
            Expanded(child: b),
          ],
        ),
      );
    },
  );
}

Widget _bentoTile(
  BuildContext context, {
  required String label,
  required Widget child,
}) {
  final sp = context.spacing;
  final cs = context.colors;
  return Container(
    padding: EdgeInsets.all(sp.sm + sp.xs),
    decoration: BoxDecoration(
      color: cs.surface,
      border: Border.all(color: context.tokens.surfaceOutline, width: 1.5),
      borderRadius: BorderRadius.circular(sp.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: cs.onSurfaceVariant,
          ),
        ),
        SizedBox(height: sp.xs),
        child,
      ],
    ),
  );
}

Widget _bentoStepper(
  BuildContext context, {
  required String label,
  required int value,
  required int min,
  required int max,
  required ValueChanged<int> onChanged,
}) {
  final cs = context.colors;
  final sp = context.spacing;
  Widget key(IconData icon, bool on, int delta) => IconButton(
    onPressed: on ? () => onChanged(value + delta) : null,
    tooltip: delta < 0 ? 'Decrease $label' : 'Increase $label',
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      backgroundColor: cs.surfaceContainerHighest,
      foregroundColor: cs.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sp.radiusSm),
      ),
    ),
  );
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      key(Icons.remove, value > min, -1),
      Text(
        '$value',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          height: 1,
          color: cs.onSurface,
        ),
      ),
      key(Icons.add, value < max, 1),
    ],
  );
}

/// One rule as a two-state bento chip. Active is a saturated fill, never a
/// black slab: a strip of near-black chips was unreadable in sunlight.
class _RuleChip extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;
  const _RuleChip({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final sp = context.spacing;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(sp.radiusSm),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.symmetric(horizontal: sp.sm, vertical: sp.xs),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surface,
          border: Border.all(
            color: active ? cs.primary : context.tokens.surfaceOutline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(sp.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: active ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: active ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsavedBadge extends StatelessWidget {
  const _UnsavedBadge();

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'UNSAVED',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}

Widget _squadHeader(BuildContext context) {
  final cs = context.colors;
  final hint = TextStyle(fontSize: 10, color: cs.onSurfaceVariant);
  return Row(
    children: [
      const Text(
        'SQUADS',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          fontSize: 12,
        ),
      ),
      const Spacer(),
      Icon(Icons.close, size: 12, color: cs.onSurfaceVariant),
      const SizedBox(width: 2),
      Text('benches', style: hint),
      const SizedBox(width: 8),
      Icon(Icons.lock_outline, size: 12, color: cs.onSurfaceVariant),
      const SizedBox(width: 2),
      Text('played', style: hint),
    ],
  );
}

/// Both XIs as bento columns. Under 360dp they stack instead of squeezing two
/// 44dp targets and a name into 140dp.
Widget _squadColumns(
  BuildContext context, {
  required MatchStore store,
  required StateSetter setSheet,
  required int cap,
}) {
  final m = store.match!;
  final sp = context.spacing;
  final a = _TeamColumn(
    store: store,
    setSheet: setSheet,
    team: m.config.teamA,
    cap: cap,
  );
  final b = _TeamColumn(
    store: store,
    setSheet: setSheet,
    team: m.config.teamB,
    cap: cap,
  );
  return LayoutBuilder(
    builder: (c, cons) {
      if (cons.maxWidth < 360) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            a,
            SizedBox(height: sp.sm),
            b,
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            SizedBox(width: sp.sm),
            Expanded(child: b),
          ],
        ),
      );
    },
  );
}

class _TeamColumn extends StatelessWidget {
  final MatchStore store;
  final StateSetter setSheet;
  final String team;
  final int cap;
  const _TeamColumn({
    required this.store,
    required this.setSheet,
    required this.team,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    final m = store.match!;
    final cs = context.colors;
    final sp = context.spacing;
    final mine = team == m.config.teamA ? m.config.squadA : m.config.squadB;
    final other = team == m.config.teamA ? m.config.squadB : m.config.squadA;
    final colorValue = team == m.config.teamA
        ? MatchStore.teamAColor
        : MatchStore.teamBColor;
    final color = Color(colorValue);
    return Container(
      decoration: BoxDecoration(
        // No tint: the solid header band and the 1.5px team border already
        // carry the side. A 5% wash is exactly the pastel the Sunlight Rule
        // bans, and it muddies the rows inside.
        color: cs.surface,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(sp.radiusMd),
      ),
      // Clip so the solid header band keeps the card's rounded top corners.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    team,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${mine.length}/$cap',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (mine.isEmpty)
            Padding(
              padding: EdgeInsets.all(sp.sm),
              child: Text(
                'Empty — assign from the bench',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            )
          else
            for (final id in mine.toList())
              _SquadMemberRow(
                store: store,
                setSheet: setSheet,
                team: team,
                id: id,
                common: other.contains(id),
              ),
        ],
      ),
    );
  }
}

/// One XI member: name left, bench/lock right. A played player is *locked*, not
/// faded: solid [DesignTokens.lockedFill], full-contrast [DesignTokens.lockedInk],
/// a lock glyph and the reason in words — dimming the name is what made this
/// list unreadable in daylight.
class _SquadMemberRow extends StatelessWidget {
  final MatchStore store;
  final StateSetter setSheet;
  final String team;
  final String id;
  final bool common;
  const _SquadMemberRow({
    required this.store,
    required this.setSheet,
    required this.team,
    required this.id,
    required this.common,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final played = _hasPlayed(store, id);
    return PlayerRow(
      name: store.playerName(id),
      // A locked row always says why it will not respond.
      subtitle: played
          ? 'Already played — locked'
          : (common ? 'Both XIs' : null),
      enabled: !played,
      onTap: null,
      trailing: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 18,
          tooltip: played ? 'Already played — locked' : 'Bench from $team',
          icon: Icon(
            played ? Icons.lock_outline : Icons.close,
            color: played ? context.tokens.lockedInk : cs.onSurface,
          ),
          onPressed: played
              ? null
              : () {
                  final err = store.removeFromSquad(team, id);
                  setSheet(() {});
                  if (err != null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(err)));
                  }
                },
        ),
      ),
    );
  }
}

/// Everyone not in an XI, with one-tap assignment to either side. The shared
/// double-side pick appears once as BOTH and greys out once taken.
class _BenchPool extends StatelessWidget {
  final MatchStore store;
  final StateSetter setSheet;
  final TextEditingController ctrl;
  final int cap;
  final int common;
  final bool showAll;
  final VoidCallback onToggleAll;
  final VoidCallback onCreate;
  const _BenchPool({
    required this.store,
    required this.setSheet,
    required this.ctrl,
    required this.cap,
    required this.common,
    required this.showAll,
    required this.onToggleAll,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final m = store.match!;
    final cs = context.colors;
    final sp = context.spacing;
    final q = ctrl.text.trim();
    final shared = m.config.squadA.where(m.config.squadB.contains).toList();
    final pool =
        store.clubRoster.where((p) {
          if (!p.active) return false;
          if (m.config.squadA.contains(p.id)) return false;
          if (m.config.squadB.contains(p.id)) return false;
          if (q.isEmpty) return true;
          return p.name.toLowerCase().contains(q.toLowerCase());
        }).toList()..sort(
          (a, b) => (store.playerAppearances[b.id] ?? 0).compareTo(
            store.playerAppearances[a.id] ?? 0,
          ),
        );
    final visible = q.isEmpty && !showAll ? pool.take(6).toList() : pool;
    return Container(
      padding: EdgeInsets.all(sp.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: context.tokens.surfaceOutline, width: 1.5),
        borderRadius: BorderRadius.circular(sp.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'BENCH / ROSTER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${pool.length} free',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (shared.isNotEmpty) ...[
            SizedBox(height: sp.sm),
            Container(
              padding: EdgeInsets.only(left: sp.sm),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                border: Border.all(color: context.tokens.borderRow),
                borderRadius: BorderRadius.circular(sp.radiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'BOTH XIs · ${shared.map(store.playerName).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Un-share',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () {
                      for (final id in shared) {
                        final err = store.removeCommonPlayer(id);
                        if (err != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(err)));
                          return;
                        }
                      }
                      setSheet(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: sp.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search roster',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setSheet(() {}),
                ),
              ),
              SizedBox(width: sp.sm),
              RectBtn(
                primary: false,
                onTap: onCreate,
                child: const Text('＋ NEW'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (pool.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: sp.sm),
              child: Text(
                q.isEmpty
                    ? 'Everyone on the roster is already in an XI.'
                    : 'No roster player matches “$q”.',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            )
          else
            for (final p in visible)
              _BenchRow(
                store: store,
                setSheet: setSheet,
                player: p,
                cap: cap,
                common: common,
              ),
          if (q.isEmpty && pool.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RectBtn(
                primary: false,
                onTap: onToggleAll,
                child: Text(showAll ? 'SHOW FEWER' : 'SHOW ALL ${pool.length}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _BenchRow extends StatelessWidget {
  final MatchStore store;
  final StateSetter setSheet;
  final Player player;
  final int cap;
  final int common;
  const _BenchRow({
    required this.store,
    required this.setSheet,
    required this.player,
    required this.cap,
    required this.common,
  });

  @override
  Widget build(BuildContext context) {
    final m = store.match!;
    final aFull = m.config.squadA.length >= cap;
    final bFull = m.config.squadB.length >= cap;
    final shared = m.config.squadA.any(m.config.squadB.contains);
    void assign(String team) {
      final err = store.addToSquad(team, player.id, cap: cap);
      setSheet(() {});
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    }

    return PlayerRow(
      name: player.name,
      subtitle: '${store.playerAppearances[player.id] ?? 0} apps',
      onTap: null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AssignBtn(
            label: _teamTag(m.config.teamA),
            color: Color(MatchStore.teamAColor),
            enabled: !aFull,
            onTap: () => assign(m.config.teamA),
          ),
          const SizedBox(width: 4),
          _AssignBtn(
            label: _teamTag(m.config.teamB),
            color: Color(MatchStore.teamBColor),
            enabled: !bFull,
            onTap: () => assign(m.config.teamB),
          ),
          if (common > 0 && !shared) ...[
            const SizedBox(width: 4),
            _AssignBtn(
              label: 'BOTH',
              color: context.tokens.primaryFill,
              enabled: !aFull && !bFull,
              onTap: () {
                final err = store.addCommonPlayer(
                  player.id,
                  cap: cap,
                  commonPlayers: common,
                );
                setSheet(() {});
                if (err != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(err)));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Solid team-colour assign key. Disabled keeps the label readable instead of
/// fading into the card.
class _AssignBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _AssignBtn({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: enabled ? color : context.tokens.lockedFill,
          foregroundColor: enabled ? Colors.white : context.tokens.lockedInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.spacing.radiusSm),
          ),
        ),
        child: Text(
          '+$label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// Create a brand-new player mid-match. He is born on the club roster and
/// lands in the bench pool, then gets assigned with +TEAM (one commit each,
/// so undo still steps back a single change).
void _showCreatePlayer(
  BuildContext context,
  MatchStore store,
  StateSetter setSheet,
) {
  final nameCtrl = TextEditingController();
  var role = PlayerRole.allRounder;
  var bat = BattingStyle.rightHand;
  var bowl = BowlingStyle.none;
  const roleLabels = {
    PlayerRole.batter: 'BATTER',
    PlayerRole.bowler: 'BOWLER',
    PlayerRole.allRounder: 'ALL-ROUNDER',
    PlayerRole.keeper: 'KEEPER',
  };
  void toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  void commit(BuildContext dCtx) {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      toast('Type a name');
      return;
    }
    if (store.duplicateName(name)) {
      toast('$name is already on the roster');
      return;
    }
    final created = store.addPlayer(
      name: name,
      role: role,
      battingStyle: bat,
      bowlingStyle: bowl,
    );
    if (created == null) {
      toast('Could not add player');
      return;
    }
    Navigator.pop(dCtx);
    setSheet(() {});
    toast('$name added to the bench');
  }

  showDialog(
    context: context,
    builder: (dCtx) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        title: const Text('NEW PLAYER'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Joins the club roster and the bench. Assign him to an XI next.',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Player name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => commit(dCtx),
              ),
              const SizedBox(height: 12),
              const Text(
                'ROLE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in PlayerRole.values)
                    ChoiceChip(
                      label: Text(roleLabels[r]!),
                      selected: role == r,
                      onSelected: (_) => setD(() => role = r),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'BATTING',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in BattingStyle.values)
                    ChoiceChip(
                      label: Text(battingStyleLabel(s)),
                      selected: bat == s,
                      onSelected: (_) => setD(() => bat = s),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'BOWLING',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in BowlingStyle.values)
                    ChoiceChip(
                      label: Text(bowlingStyleLabel(s)),
                      selected: bowl == s,
                      onSelected: (_) => setD(() => bowl = s),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          RectBtn(
            primary: false,
            onTap: () => Navigator.pop(dCtx),
            child: const Text('CANCEL'),
          ),
          RectBtn(onTap: () => commit(dCtx), child: const Text('ADD TO BENCH')),
        ],
      ),
    ),
  );
}
