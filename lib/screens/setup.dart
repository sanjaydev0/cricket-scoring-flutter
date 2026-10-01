import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
            ShadCard(
              title: const Text('Teams'),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const TeamDot(MatchStore.teamAColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ShadInput(
                            controller: a,
                            placeholder:
                                const Text('Team A (bats first)'),
                            textCapitalization:
                                TextCapitalization.characters,
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
                          child: ShadInput(
                            controller: b,
                            placeholder: const Text('Team B'),
                            textCapitalization:
                                TextCapitalization.characters,
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
            ShadCard(
              title: const Text('Format'),
              description:
                  Text('Sides: ${cfg.sidesLabel}'),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    StepperRow(
                        label: 'Overs',
                        value: cfg.totalOvers,
                        min: 1,
                        max: 50,
                        onChanged: (v) =>
                            setState(() => cfg.totalOvers = v)),
                    const SizedBox(height: 8),
                    StepperRow(
                        label: 'Players / side',
                        value: cfg.playersPerSide,
                        min: 2,
                        max: 15,
                        onChanged: (v) => setState(
                            () => cfg.playersPerSide = v)),
                    const SizedBox(height: 8),
                    StepperRow(
                        label: 'Common (both sides)',
                        hint: 'Odd-man: e.g. 13 players = 6 + 6 + 1',
                        value: cfg.commonPlayers,
                        min: 0,
                        max: 2,
                        onChanged: (v) => setState(
                            () => cfg.commonPlayers = v)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ShadCard(
              title: const Text('Rules'),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    StepperRow(
                        label: 'Wide penalty',
                        hint: 'Default 1',
                        value: cfg.rules.widePenalty,
                        min: 0,
                        max: 2,
                        onChanged: (v) => setState(
                            () => cfg.rules.widePenalty = v)),
                    const SizedBox(height: 8),
                    StepperRow(
                        label: 'No-ball penalty',
                        hint: 'Default 0',
                        value: cfg.rules.noBallPenalty,
                        min: 0,
                        max: 2,
                        onChanged: (v) => setState(
                            () => cfg.rules.noBallPenalty = v)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Free hit on no-ball'),
                        ShadSwitch(
                            value: cfg.rules.freeHit,
                            onChanged: (v) => setState(
                                () => cfg.rules.freeHit = v)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Last man standing'),
                        ShadSwitch(
                            value: cfg.rules.lastManStanding,
                            onChanged: (v) => setState(() =>
                                cfg.rules.lastManStanding = v)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ShadButton(
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
