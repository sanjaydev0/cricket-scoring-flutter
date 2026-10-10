import 'package:flutter/material.dart';
import '../store.dart';
import '../domain/players.dart';
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
  bool _triedSubmit = false;
  bool _track = false;
  final Set<String> _squadA = {};
  final Set<String> _squadB = {};
  String _qa = '';
  String _qb = '';
  final Set<String> _expanded = {};
  final Map<String, TextEditingController> _searchCtrls = {};
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
      body: SafeArea(
          child: ResponsiveCenter(
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
                          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const TeamDot(MatchStore.teamAColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: a,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                              labelText: 'Team A',
                              errorText: _triedSubmit && a.text.trim().isEmpty
                                  ? 'Required'
                                  : null,
                              border: const OutlineInputBorder()),
                          onChanged: (v) =>
                              setState(() => cfg.teamA = v.toUpperCase()),
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
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                              labelText: 'Team B',
                              errorText: _triedSubmit && b.text.trim().isEmpty
                                  ? 'Required'
                                  : null,
                              border: const OutlineInputBorder()),
                          onChanged: (v) =>
                              setState(() => cfg.teamB = v.toUpperCase()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('BATTING FIRST',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'A',
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const TeamDot(MatchStore.teamAColor, size: 10),
                              const SizedBox(width: 6),
                              Text(cfg.teamA.isEmpty ? 'TEAM A' : cfg.teamA),
                            ],
                          )),
                      ButtonSegment(
                          value: 'B',
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const TeamDot(MatchStore.teamBColor, size: 10),
                              const SizedBox(width: 6),
                              Text(cfg.teamB.isEmpty ? 'TEAM B' : cfg.teamB),
                            ],
                          )),
                    ],
                    selected: {cfg.battingFirst},
                    onSelectionChanged: (s) =>
                        setState(() => cfg.battingFirst = s.first),
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
                          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  StepperRow(
                      label: 'Overs',
                      value: cfg.totalOvers,
                      min: 1,
                      max: 50,
                      onChanged: (v) => setState(() => cfg.totalOvers = v)),
                  StepperRow(
                      label: 'Players / side',
                      value: cfg.playersPerSide,
                      min: 2,
                      max: 15,
                      onChanged: (v) => setState(() => cfg.playersPerSide = v)),
                  const SizedBox(height: 4),
                  const Text('Double-side player',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('None')),
                      ButtonSegment(value: 1, label: Text('+1 common')),
                    ],
                    selected: {cfg.commonPlayers},
                    onSelectionChanged: (s) =>
                        setState(() => cfg.commonPlayers = s.first),
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
                          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  StepperRow(
                      label: 'Wide penalty',
                      hint: 'Default 1',
                      value: cfg.rules.widePenalty,
                      min: 0,
                      max: 2,
                      onChanged: (v) =>
                          setState(() => cfg.rules.widePenalty = v)),
                  StepperRow(
                      label: 'No-ball penalty',
                      hint: 'Default 0',
                      value: cfg.rules.noBallPenalty,
                      min: 0,
                      max: 2,
                      onChanged: (v) =>
                          setState(() => cfg.rules.noBallPenalty = v)),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Free hit on no-ball'),
                      value: cfg.rules.freeHit,
                      onChanged: (v) => setState(() => cfg.rules.freeHit = v)),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Last man standing'),
                      value: cfg.rules.lastManStanding,
                      onChanged: (v) =>
                          setState(() => cfg.rules.lastManStanding = v)),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Advanced extras keys'),
                      subtitle: const Text('WD+overthrows, byes, NB+runs'),
                      value: widget.store.advancedExtras,
                      onChanged: (v) => widget.store.setAdvancedExtras(v)),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Track players + stats'),
                    subtitle: const Text('Squads + scorecard. Off = fast.'),
                    value: _track,
                    onChanged: (v) => setState(() => _track = v),
                  ),
                  if (_track) ...[
                    const SizedBox(height: 4),
                    Text(
                        'Squads come from CLUB roster (${widget.store.clubRoster.length} players).',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    _squadPicker('TEAM A', cfg.teamA, _squadA, _squadB, _qa,
                        (v) => setState(() => _qa = v)),
                    const SizedBox(height: 8),
                    _squadPicker('TEAM B', cfg.teamB, _squadB, _squadA, _qb,
                        (v) => setState(() => _qb = v)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          RectBtn(
            onTap: () {
              setState(() => _triedSubmit = true);
              if (a.text.trim().isEmpty || b.text.trim().isEmpty) {
                return;
              }
              if (_track && (_squadA.length < 2 || _squadB.length < 2)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Pick at least 2 players per side (or turn tracking off).')));
                return;
              }
              cfg.trackPlayers = _track;
              cfg.squadA = _squadA.toList();
              cfg.squadB = _squadB.toList();
              widget.store.draft = cfg;
              widget.store.startMatch(cfg);
              Navigator.pushReplacementNamed(context, '/scoring');
            },
            child: const Text('START SCORING'),
          ),
        ],
      ))),
    );
  }

  Widget _squadPicker(String side, String team, Set<String> sel,
      Set<String> otherSel, String query, ValueChanged<String> onQuery) {
    final store = widget.store;
    final q = query.toLowerCase().trim();
    // Cross-exclusion: a player picked for one side never appears on the
    // other — unless the match allows a common player, in which case the
    // shared pick stays visible on both.
    final sharedOk = cfg.commonPlayers > 0;
    final pool = store.clubRoster.where((p) {
      if (!p.active) return false;
      // Cross-exclusion: picked for the other side stays visible only when a
      // common player is allowed; otherwise it is hidden, not disabled, so a
      // shared pick can never be made by accident.
      if (otherSel.contains(p.id) && !sharedOk) return false;
      return q.isEmpty || p.searchKey.contains(q);
    }).toList();
    // Most frequent first; the picked stay pinned on top so a tap never makes
    // a name vanish from under the finger.
    int freq(String id) => store.playerAppearances[id] ?? 0;
    pool.sort((a, b) {
      final sa = sel.contains(a.id) ? 1 : 0;
      final sb = sel.contains(b.id) ? 1 : 0;
      if (sa != sb) return sb.compareTo(sa);
      return freq(b.id).compareTo(freq(a.id));
    });
    final expanded = _expanded.contains(side);
    // Collapsed until tapped: only picked players show, so a long roster does
    // not bury the form. Tapping search reveals frequent-first + More.
    final showPool = expanded || q.isNotEmpty;
    final listed =
        showPool ? pool : pool.where((p) => sel.contains(p.id)).toList();
    final visible =
        expanded ? listed.take(12).toList() : listed.take(8).toList();
    final hidden = listed.length - visible.length;
    // The XI can never exceed players-per-side: selected stay tappable so a
    // pick can always be undone, unselected lock with the reason visible.
    final cap = cfg.playersPerSide;
    final full = sel.length >= cap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$side • $team (${sel.length}/$cap picked)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller:
              _searchCtrls.putIfAbsent(side, () => TextEditingController()),
          decoration: InputDecoration(
              labelText: 'Select players',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchCtrls[side]?.clear();
                        onQuery('');
                      },
                    ),
              border: const OutlineInputBorder()),
          onChanged: onQuery,
          onTap: () => setState(() => _expanded.add(side)),
        ),
        const SizedBox(height: 4),
        if (pool.isEmpty)
          const Text('No players — add them in CLUB first.',
              style: TextStyle(fontSize: 12)),
        if (!showPool && pool.isNotEmpty)
          Text('Tap Select players to choose (${pool.length} in club)',
              style: const TextStyle(fontSize: 12)),
        for (final p in visible)
          Opacity(
            opacity: (full && !sel.contains(p.id)) ? 0.45 : 1.0,
            child: InkWell(
              onTap: (full && !sel.contains(p.id))
                  ? null
                  : () => setState(() {
                        if (sel.contains(p.id)) {
                          sel.remove(p.id);
                        } else {
                          sel.add(p.id);
                        }
                      }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                              '${_roleName(p.role)} | ${battingStyleLabel(p.battingStyle)} ${bowlingStyleLabel(p.bowlingStyle)}${freq(p.id) > 0 ? ' | ${freq(p.id)} played' : ''}',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    Icon(
                      sel.contains(p.id)
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: sel.contains(p.id) ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (hidden > 0)
          TextButton(
            onPressed: () => setState(() => _expanded.add(side)),
            child: Text(expanded ? 'Show less' : 'More ($hidden)'),
          ),
      ],
    );
  }

  String _roleName(PlayerRole r) => switch (r) {
        PlayerRole.batter => 'Batter',
        PlayerRole.bowler => 'Bowler',
        PlayerRole.allRounder => 'All-rounder',
        PlayerRole.keeper => 'Keeper',
      };
}
