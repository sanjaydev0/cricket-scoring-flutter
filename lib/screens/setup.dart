import 'package:flutter/material.dart';
import '../store.dart';
import '../models.dart';
import 'widgets.dart';

class SetupScreen extends StatefulWidget {
  final MatchStore store;
  const SetupScreen(this.store, {super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late TextEditingController a, b;
  late MatchConfig cfg;
  @override
  void initState() {
    super.initState();
    final d = widget.store.draft;
    cfg = MatchConfig(
      teamA: d.teamA,
      teamB: d.teamB,
      totalOvers: d.totalOvers,
      playersPerSide: d.playersPerSide,
      commonPlayers: d.commonPlayers,
      rules: Rules(
        widePenalty: d.rules.widePenalty,
        noBallPenalty: d.rules.noBallPenalty,
        lastManStanding: d.rules.lastManStanding,
        freeHit: d.rules.freeHit,
      ),
    );
    a = TextEditingController(text: cfg.teamA);
    b = TextEditingController(text: cfg.teamB);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MATCH SETUP')),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TEAMS',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const TeamDot(MatchStore.teamAColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: a,
                            textCapitalization:
                                TextCapitalization.characters,
                            decoration: const InputDecoration(
                                labelText: 'Team A (bats first)',
                                border: OutlineInputBorder()),
                            onChanged: (v) =>
                                cfg.teamA = v.toUpperCase(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const TeamDot(MatchStore.teamBColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: b,
                            textCapitalization:
                                TextCapitalization.characters,
                            decoration: const InputDecoration(
                                labelText: 'Team B',
                                border: OutlineInputBorder()),
                            onChanged: (v) =>
                                cfg.teamB = v.toUpperCase(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FORMAT • ${cfg.sidesLabel}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    StepperRow(
                        label: 'Overs',
                        value: cfg.totalOvers,
                        min: 1,
                        max: 50,
                        onChanged: (v) =>
                            setState(() => cfg.totalOvers = v)),
                    StepperRow(
                        label: 'Players / side',
                        value: cfg.playersPerSide,
                        min: 2,
                        max: 15,
                        onChanged: (v) => setState(
                            () => cfg.playersPerSide = v)),
                    const SizedBox(height: 4),
                    const Text('Common player (odd-man)',
                        style: TextStyle(
                            fontWeight: FontWeight.w700)),
                    const Text('One player turns out for both sides',
                        style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 6),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                            value: 0, label: Text('None')),
                        ButtonSegment(
                            value: 1, label: Text('+1 common')),
                      ],
                      selected: {cfg.commonPlayers},
                      onSelectionChanged: (s) => setState(
                          () => cfg.commonPlayers = s.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RULES',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2)),
                    StepperRow(
                        label: 'Wide penalty',
                        hint: 'Default 1',
                        value: cfg.rules.widePenalty,
                        min: 0,
                        max: 2,
                        onChanged: (v) => setState(
                            () => cfg.rules.widePenalty = v)),
                    StepperRow(
                        label: 'No-ball penalty',
                        hint: 'Default 0',
                        value: cfg.rules.noBallPenalty,
                        min: 0,
                        max: 2,
                        onChanged: (v) => setState(
                            () => cfg.rules.noBallPenalty = v)),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Free hit on no-ball'),
                        value: cfg.rules.freeHit,
                        onChanged: (v) => setState(
                            () => cfg.rules.freeHit = v)),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            const Text('Last man standing'),
                        value: cfg.rules.lastManStanding,
                        onChanged: (v) => setState(() =>
                            cfg.rules.lastManStanding = v)),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title:
                            const Text('Advanced extras keys'),
                        subtitle: const Text(
                            'WD+overthrows, byes, NB+runs'),
                        value: widget.store.advancedExtras,
                        onChanged: (v) =>
                            widget.store.setAdvancedExtras(v)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: () {
                if (a.text.trim().isEmpty ||
                    b.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Enter both team names')));
                  return;
                }
                widget.store.draft = cfg;
                widget.store.startMatch(cfg);
                Navigator.pushReplacementNamed(context, '/scoring');
              },
              child: const Text('START SCORING'),
            ),
          ],
        ),
      ),
    );
  }
}
