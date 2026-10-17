import 'package:flutter/material.dart';
import '../domain/players.dart';
import '../math.dart';
import '../store.dart';
import '../theme.dart';
import 'player_sheets.dart';
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
          action: 'WICKET', wicketType: type.label, dismissal: type.name);
    },
    child: Text(
        type == DismissalType.runOut ? 'RUN OUT ›' : type.label.toUpperCase()),
  );
}

void showOversSheet(BuildContext context, MatchStore store) {
  final inn = store.innings!;
  final m = store.match!;
  final innIdx = m.currentInnings;
  showModalBottomSheet(
    context: context,
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
                    Text('OVERS HISTORY // INNINGS $innIdx',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text(
                        '${inn.battingTeam}: ${inn.runs}/${inn.wickets} (${CricketMath.ballsToOvers(inn.legalDeliveries)} ov)',
                        style: const TextStyle(fontSize: 12)),
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
                              fontWeight: FontWeight.w800, fontSize: 12)),
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
  showModalBottomSheet(
    context: context,
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
            _pillGroup('NO-BALL +', ['NB', 'NB+1', 'NB+2', 'NB+4', 'NB+6'],
                (label) {
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
    String title, List<String> opts, ValueChanged<String> onPick) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
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
  // Owned by the sheet so the mid-match "add a player" field survives
  // rebuilds and can be cleared after each add.
  final squadField = TextEditingController();
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
              Row(
                children: [
                  const Expanded(
                    child: Text('MID-MATCH CONFIG',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                    onChanged: (v) => setSheet(() => overs = v)),
              ),
              _flatRow(
                'PLAYERS / SIDE',
                StepperRow(
                    label: '',
                    value: players,
                    min: 2,
                    max: 15,
                    onChanged: (v) => setSheet(() => players = v)),
              ),
              _flatRow(
                'DOUBLE-SIDE',
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('None')),
                    ButtonSegment(value: 1, label: Text('One')),
                  ],
                  selected: {common},
                  onSelectionChanged: (s) => setSheet(() => common = s.first),
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
              if (store.tracking)
                _squadSection(context, store, setSheet, squadField),
              if (store.tracking) const Divider(height: 24),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: RectBtn(
                      primary: false,
                      onTap: () => Navigator.pop(sheetCtx),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RectBtn(
                      onTap: () {
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
                            SnackBar(content: Text(err ?? 'Saved')));
                      },
                      child: const Text('✓ SAVE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                              child: Text(cfg.teamA,
                                  overflow: TextOverflow.ellipsis)),
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
                              child: Text(cfg.teamB,
                                  overflow: TextOverflow.ellipsis)),
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
          child: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => ListenableBuilder(
      listenable: store,
      builder: (_, __) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STYLE',
                  style: TextStyle(fontWeight: FontWeight.w900)),
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
              const Text('SCORE FONT',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in ScoreFonts.ids)
                    ChoiceChip(
                      label: Text('142/7',
                          style: TextStyle(
                              fontFamily: ScoreFonts.family(id),
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      selected: store.fontId == id,
                      onSelected: (_) => store.setFont(id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('CELEBRATION',
                  style: TextStyle(fontWeight: FontWeight.w900)),
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

/// Mid-match XI management: rows per side, search-to-add from the roster,
/// type-a-name to create + add. Same cap and cross-exclusion as setup.
Widget _squadSection(BuildContext context, MatchStore store,
    StateSetter setSheet, TextEditingController squadField) {
  final m = store.match!;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('SQUADS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 8),
      for (final team in [m.config.teamA, m.config.teamB])
        _sideBlock(context, store, setSheet, team, squadField),
    ],
  );
}

Widget _sideBlock(BuildContext context, MatchStore store, StateSetter setSheet,
    String team, TextEditingController squadField) {
  final m = store.match!;
  final mine = team == m.config.teamA ? m.config.squadA : m.config.squadB;
  final other = team == m.config.teamA ? m.config.squadB : m.config.squadA;
  final cap = m.config.playersPerSide;
  // Quick adds: most frequent eligible first. Typed names go through the
  // field below (roster hit or created in-club, duplicates warned).
  final cands = store.clubRoster.where((p) {
    if (!p.active || mine.contains(p.id)) return false;
    if (other.contains(p.id) && m.config.commonPlayers == 0) return false;
    return true;
  }).toList()
    ..sort((a, b) => (store.playerAppearances[b.id] ?? 0)
        .compareTo(store.playerAppearances[a.id] ?? 0));
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$team (${mine.length}/$cap)',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      for (final id in mine.toList())
        Row(
          children: [
            Expanded(
              child: Text(store.playerName(id),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove (only if uncapped)',
              onPressed: () {
                final err = store.removeFromSquad(team, id);
                setSheet(() {});
                if (err != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(err)));
                }
              },
            ),
          ],
        ),
      const SizedBox(height: 4),
      // Explicit button, not just onSubmitted: typing a name and tapping away
      // used to do nothing at all, which read as "adding mid-match is broken".
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: squadField,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: mine.length >= cap
                    ? 'XI full ($cap)'
                    : 'Roster name, or type a new one',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              enabled: mine.length < cap,
              onSubmitted: (_) => _addByName(context, store, team, squadField),
            ),
          ),
          const SizedBox(width: 8),
          RectBtn(
            primary: false,
            onTap: mine.length >= cap
                ? null
                : () => _addByName(context, store, team, squadField),
            child: const Text('ADD'),
          ),
        ],
      ),
      const SizedBox(height: 4),
      for (final p in cands.take(4))
        PlayerRow(
          name: p.name,
          subtitle: '${store.playerAppearances[p.id] ?? 0} appearances',
          selected: false,
          enabled: mine.length < cap,
          blockedReason: mine.length >= cap ? 'XI full ($cap)' : null,
          onTap: () {
            final err = store.addToSquad(team, p.id);
            setSheet(() {});
            if (err != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(err)));
            }
          },
          trailing: const Icon(Icons.add_circle_outline, size: 20),
        ),
      const SizedBox(height: 10),
    ],
  );
}

/// Adds by typed name and clears the field either way, so the next player can
/// be typed straight away.
void _addByName(BuildContext context, MatchStore store, String team,
    TextEditingController squadField) {
  final err = store.addSquadByName(team, squadField.text);
  squadField.clear();
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }
}
