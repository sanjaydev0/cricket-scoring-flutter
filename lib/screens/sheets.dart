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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('✕'),
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
  showAppSheet(
    context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OVERS HISTORY // INNINGS $innIdx',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${inn.battingTeam}: ${inn.runs}/${inn.wickets} (${CricketMath.ballsToOvers(inn.legalDeliveries)} ov)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              RectBtn(
                onTap: () => Navigator.pop(context),
                child: const Text('✕ CLOSE'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RectBtn(
            primary: false,
            onTap: () {
              Navigator.pop(context);
              showScorecard(context, store, inningsNo: innIdx);
            },
            child: const Text('SCORECARD'),
          ),
          const SizedBox(height: 12),
          for (final o in inn.overs)
            if (o.balls.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OVER ${o.overNumber.toString().padLeft(2, '0')} // ${o.balls.fold<int>(0, (s, b) => s + b.totalRuns)} RUNS • ${o.balls.where((b) => b.isWicket).length} WKT',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final b in o.balls) BallBadge(b)],
                      ),
                    ],
                  ),
                ),
              ),
        ],
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
  // Per-team squad editor state (Setup-parity accordion).
  var openTeam = cfg.teamA;
  final searchCtrls = <String, TextEditingController>{
    cfg.teamA: TextEditingController(),
    cfg.teamB: TextEditingController(),
  };
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
  void confirmClose(BuildContext c, BuildContext sheetCtx) {
    if (!isDirty()) {
      Navigator.pop(sheetCtx);
      return;
    }
    showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('You changed overs or rules. Save before leaving?'),
        actions: [
          RectBtn(
            primary: false,
            onTap: () {
              Navigator.pop(c);
              Navigator.pop(sheetCtx);
            },
            child: const Text('DISCARD'),
          ),
          RectBtn(
            onTap: () {
              final err = savePending();
              if (err != null) {
                ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              Navigator.pop(c);
              Navigator.pop(sheetCtx);
              ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Saved')));
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
  showAppSheet(
    context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheet) =>
          PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              confirmClose(context, sheetCtx);
            },
            child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MID-MATCH CONFIG',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(height: 24),
              _flatRow(
                'MATCH OVERS',
                StepperRow(
                  label: '',
                  value: overs,
                  min: 1,
                  max: 50,
                  onChanged: (v) => setSheet(() => overs = v),
                ),
              ),
              _flatRow(
                'PLAYERS / SIDE',
                StepperRow(
                  label: '',
                  value: players,
                  min: 2,
                  max: 15,
                  onChanged: (v) => setSheet(() => players = v),
                ),
              ),
              _flatRow(
                'DOUBLE-SIDE',
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('None')),
                    ButtonSegment(value: 1, label: Text('One')),
                  ],
                  selected: {common},
                  onSelectionChanged: (s) {
                    final next = s.first;
                    if (next == common) return;
                    if (next == 1 && common == 0) {
                      if (players < 15) players += 1;
                      setSheet(() => common = 1);
                    } else if (next == 0 && common == 1) {
                      final commonIds = cfg.squadA
                          .where((id) => cfg.squadB.contains(id))
                          .toList();
                      for (final id in commonIds) {
                        final rerr = store.removeCommonPlayer(id);
                        if (rerr != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(rerr)));
                          setSheet(() => common = 1);
                          return;
                        }
                      }
                      if (players > 2) players -= 1;
                      setSheet(() => common = 0);
                    }
                  },
                ),
              ),
              if (store.tracking && common > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: _commonPlayerPicker(
                    context,
                    store,
                    setSheet,
                    players,
                    common,
                  ),
                ),
              _flatRow(
                'WIDE',
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('0')),
                    ButtonSegment(value: 1, label: Text('+1')),
                  ],
                  selected: {wide},
                  onSelectionChanged: (s) => setSheet(() => wide = s.first),
                ),
              ),
              _flatRow(
                'NO-BALL',
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('0')),
                    ButtonSegment(value: 1, label: Text('+1')),
                  ],
                  selected: {noball},
                  onSelectionChanged: (s) => setSheet(() => noball = s.first),
                ),
              ),
              _flatRow(
                'FREE HIT',
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('OFF')),
                    ButtonSegment(value: true, label: Text('ON')),
                  ],
                  selected: {freeHit},
                  onSelectionChanged: (s) => setSheet(() => freeHit = s.first),
                ),
              ),
              _flatRow(
                'LAST MAN',
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('OFF')),
                    ButtonSegment(value: true, label: Text('ON')),
                  ],
                  selected: {lms},
                  onSelectionChanged: (s) => setSheet(() => lms = s.first),
                ),
              ),
              const Divider(height: 24),
              if (store.tracking)
                _SquadAccordion(
                  store: store,
                  setSheet: setSheet,
                  openTeam: openTeam,
                  onOpenTeam: (t) => setSheet(() => openTeam = t),
                  searchCtrls: searchCtrls,
                  cap: players,
                  common: common,
                ),
              if (store.tracking) const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: RectBtn(
                      primary: false,
                      onTap: () => confirmClose(context, sheetCtx),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RectBtn(
                      onTap: () {
                        final err = savePending();
                        if (err != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(err)));
                          return;
                        }
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Saved')));
                      },
                      child: const Text('✓ SAVE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'MATCH ENDS',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RectBtn(
                      primary: false,
                      onTap: () => _declareWinner(context, store, cfg.teamA),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const TeamDot(MatchStore.teamAColor, size: 10),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              cfg.teamA,
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
                      onTap: () => _declareWinner(context, store, cfg.teamB),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const TeamDot(MatchStore.teamBColor, size: 10),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              cfg.teamB,
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
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmAbandon(context, store);
                },
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

/// Flat label-left / control-right row for the compact settings sheet.
Widget _flatRow(String title, Widget control) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
        Expanded(child: control),
      ],
    ),
  );
}

void _declareWinner(BuildContext context, MatchStore store, String team) {
  Navigator.pop(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Declare $team winner?'),
      actions: [
        RectBtn(
          primary: false,
          onTap: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        RectBtn(
          onTap: () {
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

void _confirmAbandon(BuildContext context, MatchStore store) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Abandon match?'),
      actions: [
        RectBtn(
          primary: false,
          onTap: () => Navigator.pop(context),
          child: const Text('Keep scoring'),
        ),
        RectBtn(
          danger: true,
          onTap: () {
            store.abandon();
            Navigator.pop(context);
            Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          },
          child: const Text('Abandon'),
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

Widget _commonPlayerPicker(
  BuildContext context,
  MatchStore store,
  StateSetter setSheet,
  int cap,
  int common,
) {
  final m = store.match!;
  final squadA = m.config.squadA;
  final squadB = m.config.squadB;
  final commonIds = squadA.where((id) => squadB.contains(id)).toList();
  final eligible = store.clubRoster
      .where(
        (p) => p.active && !squadA.contains(p.id) && !squadB.contains(p.id),
      )
      .toList();
  final full = squadA.length >= cap || squadB.length >= cap;
  if (commonIds.isNotEmpty) {
    return Row(
      children: [
        const Text(
          'DOUBLE-SIDE:',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            commonIds.map(store.playerName).join(', '),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Remove common player',
          padding: EdgeInsets.zero,
          // A 16px glyph with zero constraints was a ~20dp target; 48dp is the
          // floor for anything that deletes a squad entry.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () {
            for (final id in commonIds) {
              final err = store.removeCommonPlayer(id);
              if (err != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            }
            setSheet(() {});
          },
        ),
      ],
    );
  }
  if (full) {
    return const Text(
      'DOUBLE-SIDE: XI full — raise players per side first.',
      style: TextStyle(fontSize: 11),
    );
  }
  if (eligible.isEmpty) {
    return const Text(
      'DOUBLE-SIDE: no eligible players — add to a squad first.',
      style: TextStyle(fontSize: 11),
    );
  }
  return Row(
    children: [
      const Text(
        'DOUBLE-SIDE:',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: DropdownButton<String>(
          hint: const Text(
            'Pick common player',
            style: TextStyle(fontSize: 12),
          ),
          isDense: true,
          isExpanded: true,
          items: eligible
              .map(
                (p) => DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final err = store.addCommonPlayer(
              id,
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
      ),
    ],
  );
}

/// Mid-match XI editor: Setup-parity accordion, one team open at a time.
/// Search + tap-to-add/remove, played rows grey, ADD NEW PLAYER creates
/// in-club + lands in the XI in one commit. Same cap/cross rules as setup.
class _SquadAccordion extends StatelessWidget {
  final MatchStore store;
  final StateSetter setSheet;
  final String openTeam;
  final ValueChanged<String> onOpenTeam;
  final Map<String, TextEditingController> searchCtrls;
  final int cap;
  final int common;
  const _SquadAccordion({
    required this.store,
    required this.setSheet,
    required this.openTeam,
    required this.onOpenTeam,
    required this.searchCtrls,
    required this.cap,
    required this.common,
  });

  @override
  Widget build(BuildContext context) {
    final m = store.match!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'SQUADS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        for (final team in [m.config.teamA, m.config.teamB])
          _TeamPanel(
            store: store,
            setSheet: setSheet,
            team: team,
            open: openTeam == team,
            onTapHeader: () => onOpenTeam(team),
            ctrl: searchCtrls[team]!,
            cap: cap,
          ),
      ],
    );
  }
}

class _TeamPanel extends StatelessWidget {
  final MatchStore store;
  final StateSetter setSheet;
  final String team;
  final bool open;
  final VoidCallback onTapHeader;
  final TextEditingController ctrl;
  final int cap;
  const _TeamPanel({
    required this.store,
    required this.setSheet,
    required this.team,
    required this.open,
    required this.onTapHeader,
    required this.ctrl,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    final m = store.match!;
    final mine = team == m.config.teamA ? m.config.squadA : m.config.squadB;
    final other = team == m.config.teamA ? m.config.squadB : m.config.squadA;
    final colorValue = team == m.config.teamA
        ? MatchStore.teamAColor
        : MatchStore.teamBColor;
    final query = ctrl.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTapHeader,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: open
                  ? Color(colorValue).withValues(alpha: 0.10)
                  : Colors.transparent,
              border: Border.all(color: Color(colorValue), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                TeamDot(colorValue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    team,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${mine.length}/$cap',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Search roster',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setSheet(() {}),
          ),
          const SizedBox(height: 6),
          for (final id in mine.toList())
            _PlayedAwareRow(
              store: store,
              setSheet: setSheet,
              team: team,
              id: id,
              common: other.contains(id),
            ),
          // Eligible roster (not in either XI), filtered by search.
          for (final p in store.clubRoster.where((p) {
            if (!p.active && !mine.contains(p.id)) return false;
            if (mine.contains(p.id) || other.contains(p.id)) return false;
            if (query.isEmpty) return true;
            return p.name.toLowerCase().contains(query);
          }).toList())
            PlayerRow(
              name: p.name,
              subtitle: '${store.playerAppearances[p.id] ?? 0} appearances',
              selected: false,
              enabled: mine.length < cap,
              blockedReason: mine.length >= cap ? 'XI full ($cap)' : null,
              onTap: () {
                final err = store.addToSquad(team, p.id, cap: cap);
                setSheet(() {});
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                }
              },
              trailing: const Icon(Icons.add_circle_outline, size: 20),
            ),
          const SizedBox(height: 6),
          RectBtn(
            primary: false,
            onTap: mine.length >= cap
                ? null
                : () => _showCreatePlayer(context, store, setSheet, team, cap),
            child: const Text('＋ ADD NEW PLAYER'),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PlayedAwareRow extends StatelessWidget {
  final MatchStore store;
  final StateSetter setSheet;
  final String team;
  final String id;
  final bool common;
  const _PlayedAwareRow({
    required this.store,
    required this.setSheet,
    required this.team,
    required this.id,
    required this.common,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = store.currentSheet;
    final b = sheet?.batting[id];
    final w = sheet?.bowling[id];
    final played = (b != null && b.position > 0) ||
        (w != null && (w.balls > 0 || w.wickets > 0));
    return PlayerRow(
      name: store.playerName(id) + (common ? ' • COMMON' : ''),
      subtitle: played ? 'Already played' : 'In XI — tap to remove',
      selected: true,
      enabled: !played,
      blockedReason: played ? 'Played — locked' : null,
      onTap: () {
        final err = store.removeFromSquad(team, id);
        setSheet(() {});
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
      },
      trailing: played ? null : const Icon(Icons.check_circle, size: 20),
    );
  }
}

void _showCreatePlayer(
  BuildContext context,
  MatchStore store,
  StateSetter setSheet,
  String team,
  int cap,
) {
  final nameCtrl = TextEditingController();
  var role = PlayerRole.allRounder;
  var bat = BattingStyle.rightHand;
  var bowl = BowlingStyle.none;
  void commit() {
    final err = store.createAndAddToSquad(
      team,
      name: nameCtrl.text.trim(),
      role: role,
      battingStyle: bat,
      bowlingStyle: bowl,
      cap: cap,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(context);
    setSheet(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${nameCtrl.text.trim()} added to $team')),
    );
  }

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        title: Text('NEW PLAYER — $team'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Player name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => commit(),
              ),
              const SizedBox(height: 10),
              const Text('ROLE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Wrap(spacing: 8, children: [
                for (final r in PlayerRole.values)
                  ChoiceChip(
                    label: Text(r.name),
                    selected: role == r,
                    onSelected: (_) => setD(() => role = r),
                  ),
              ]),
              const SizedBox(height: 8),
              const Text('BATTING', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Wrap(spacing: 8, children: [
                for (final s in BattingStyle.values)
                  ChoiceChip(
                    label: Text(s == BattingStyle.rightHand ? 'RHB' : 'LHB'),
                    selected: bat == s,
                    onSelected: (_) => setD(() => bat = s),
                  ),
              ]),
              const SizedBox(height: 8),
              const Text('BOWLING', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Wrap(spacing: 8, children: [
                for (final s in BowlingStyle.values)
                  ChoiceChip(
                    label: Text(bowlingStyleLabel(s)),
                    selected: bowl == s,
                    onSelected: (_) => setD(() => bowl = s),
                  ),
              ]),
            ],
          ),
        ),
        actions: [
          RectBtn(
            primary: false,
            onTap: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          RectBtn(onTap: commit, child: const Text('Add + pick')),
        ],
      ),
    ),
  );
}
