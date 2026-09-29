import 'package:flutter/material.dart';
import '../store.dart';
import '../models.dart';

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
    cfg = MatchConfig(
        teamA: widget.store.draft.teamA,
        teamB: widget.store.draft.teamB,
        totalOvers: widget.store.draft.totalOvers,
        playersPerSide: widget.store.draft.playersPerSide,
        rules: Rules(
            widePenalty: widget.store.draft.rules.widePenalty,
            noBallPenalty: widget.store.draft.rules.noBallPenalty,
            lastManStanding: widget.store.draft.rules.lastManStanding,
            freeHit: widget.store.draft.rules.freeHit));
    a = TextEditingController(text: cfg.teamA);
    b = TextEditingController(text: cfg.teamB);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MATCH SETUP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: a,
              decoration: const InputDecoration(
                  labelText: 'Team A (bats first)', border: OutlineInputBorder()),
              onChanged: (v) => cfg.teamA = v.toUpperCase()),
          const SizedBox(height: 12),
          TextField(
              controller: b,
              decoration: const InputDecoration(
                  labelText: 'Team B', border: OutlineInputBorder()),
              onChanged: (v) => cfg.teamB = v.toUpperCase()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: cfg.totalOvers,
                  decoration: const InputDecoration(
                      labelText: 'Overs', border: OutlineInputBorder()),
                  items: [2, 3, 5, 6, 8, 10, 12, 15, 20]
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text('$e ov')))
                      .toList(),
                  onChanged: (v) => setState(() => cfg.totalOvers = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: cfg.playersPerSide,
                  decoration: const InputDecoration(
                      labelText: 'Players/side',
                      border: OutlineInputBorder()),
                  items: [5, 6, 7, 8, 9, 11]
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text('$e')))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => cfg.playersPerSide = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
              title: const Text('Free Hit on No-Ball'),
              value: cfg.rules.freeHit,
              onChanged: (v) =>
                  setState(() => cfg.rules.freeHit = v)),
          SwitchListTile(
              title: const Text('Last Man Standing (no all-out)'),
              value: cfg.rules.lastManStanding,
              onChanged: (v) =>
                  setState(() => cfg.rules.lastManStanding = v)),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: cfg.rules.widePenalty,
                  decoration: const InputDecoration(
                      labelText: 'Wide +', border: OutlineInputBorder()),
                  items: [0, 1, 2]
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text('+$e')))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => cfg.rules.widePenalty = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: cfg.rules.noBallPenalty,
                  decoration: const InputDecoration(
                      labelText: 'No-ball +',
                      border: OutlineInputBorder()),
                  items: [0, 1, 2]
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text('+$e')))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => cfg.rules.noBallPenalty = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: () {
                if (a.text.trim().isEmpty || b.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Enter both team names')));
                  return;
                }
                widget.store.draft = cfg;
                widget.store.startMatch(cfg);
                Navigator.pushReplacementNamed(context, '/scoring');
              },
              child: const Text('START SCORING ▶',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
