import 'package:flutter/material.dart';
import '../store.dart';
import 'widgets.dart';

/// Scoring dialogs & sheets, kept out of the screen for readability.
void showWicketDialog(BuildContext context, MatchStore store) {
  const types = [
    'Bowled',
    'Caught',
    'LBW',
    'Stumped',
    'Hit Wicket',
    'Run Out'
  ];
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Wicket type'),
      content: const SizedBox(
        width: 320,
        child: Text('Free-hit protects all but Run Out.'),
      ),
      actions: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in types)
              FilterChip(
                label: Text(t),
                selected: false,
                onSelected: (_) {
                  Navigator.pop(context);
                  if (t == 'Run Out') {
                    showRunOutDialog(context, store);
                  } else {
                    store.score(action: 'WICKET', wicketType: t);
                  }
                },
              ),
          ],
        ),
      ],
    ),
  );
}

void showRunOutDialog(BuildContext context, MatchStore store) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Run-out + runs?'),
      content: const Text('Runs completed before the run-out.'),
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

void showOversSheet(BuildContext context, MatchStore store) {
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
            const Text('ADVANCED EXTRAS',
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
                FilledButton.tonal(
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
                FilledButton.tonal(
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
                FilledButton.tonal(
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
              StepperRow(
                  label: 'Players / side',
                  value: players,
                  min: 2,
                  max: 15,
                  onChanged: (v) =>
                      setSheet(() => players = v)),
              const SizedBox(height: 4),
              const Text('Common player',
                  style:
                      TextStyle(fontWeight: FontWeight.w700)),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('None')),
                  ButtonSegment(value: 1, label: Text('+1')),
                ],
                selected: {common},
                onSelectionChanged: (s) =>
                    setSheet(() => common = s.first),
              ),
              StepperRow(
                  label: 'Wide penalty',
                  value: wide,
                  min: 0,
                  max: 2,
                  onChanged: (v) =>
                      setSheet(() => wide = v)),
              StepperRow(
                  label: 'No-ball penalty',
                  value: noball,
                  min: 0,
                  max: 2,
                  onChanged: (v) =>
                      setSheet(() => noball = v)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Free hit'),
                value: freeHit,
                onChanged: (v) =>
                    setSheet(() => freeHit = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Last man standing'),
                value: lms,
                onChanged: (v) => setSheet(() => lms = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Advanced extras keys'),
                value: store.advancedExtras,
                onChanged: (v) => store.setAdvancedExtras(v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Arcade sounds'),
                value: store.soundOn,
                onChanged: (v) => store.setSound(v),
              ),
              const SizedBox(height: 8),
              FilledButton(
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
                    child: OutlinedButton(
                      onPressed: () =>
                          _declareWinner(context, store, cfg.teamA),
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
                    child: OutlinedButton(
                      onPressed: () =>
                          _declareWinner(context, store, cfg.teamB),
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
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.error),
                onPressed: () {
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

void _declareWinner(BuildContext context, MatchStore store, String team) {
  Navigator.pop(context);
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Declare $team winner?'),
      content:
          const Text('Ends the match now and archives it.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
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

void _confirmAbandon(BuildContext context, MatchStore store) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Abandon match?'),
      content:
          const Text('Live progress is discarded. Archives stay.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep scoring'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.error),
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