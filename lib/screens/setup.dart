import 'package:flutter/material.dart';

import '../store.dart';
import '../domain/players.dart';
import '../models.dart';
import '../theme.dart';
import 'club.dart';
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

  /// Which squad panel is open. Only one at a time: two long lists stacked
  /// meant Team B was always a scroll away.
  String? _openTeam = 'TEAM A';
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
    // Rematch: carry the previous squads (and tracking) into setup so the same
    // XI is preselected and editable, exactly like a fresh setup. One-shot —
    // a plain NEW MATCH still starts with empty squads.
    if (widget.store.presetSquads) {
      widget.store.presetSquads = false;
      _track = d.trackPlayers;
      _squadA.addAll(d.squadA);
      _squadB.addAll(d.squadB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RectAppBar(title: 'Match setup'),
      body: SafeArea(
        child: ResponsiveCenter(
          child: ListView(
            padding: EdgeInsets.all(context.spacing.md),
            children: [
              // TEAMS -----------------------------------------------------
              RectCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionBand('Teams'),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const TeamDot(MatchStore.teamAColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RectField(
                                  label: 'Team A',
                                  controller: a,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  errorText:
                                      _triedSubmit && a.text.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                  onChanged: (v) => setState(
                                    () => cfg.teamA = v.toUpperCase(),
                                  ),
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
                                child: RectField(
                                  label: 'Team B',
                                  controller: b,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  errorText:
                                      _triedSubmit && b.text.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                  onChanged: (v) => setState(
                                    () => cfg.teamB = v.toUpperCase(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const FieldLabel('Batting first'),
                          SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                value: 'A',
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const TeamDot(
                                      MatchStore.teamAColor,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cfg.teamA.isEmpty ? 'BLUE' : cfg.teamA,
                                    ),
                                  ],
                                ),
                              ),
                              ButtonSegment(
                                value: 'B',
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const TeamDot(
                                      MatchStore.teamBColor,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(cfg.teamB.isEmpty ? 'RED' : cfg.teamB),
                                  ],
                                ),
                              ),
                            ],
                            selected: {cfg.battingFirst},
                            onSelectionChanged: (s) =>
                                setState(() => cfg.battingFirst = s.first),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.spacing.sm + context.spacing.xs),

              // FORMAT ----------------------------------------------------
              RectCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionBand('Format', trailing: cfg.sidesLabel),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StepperRow(
                            label: 'Overs',
                            value: cfg.totalOvers,
                            min: 1,
                            max: 50,
                            onChanged: (v) =>
                                setState(() => cfg.totalOvers = v),
                          ),
                          StepperRow(
                            label: 'Players / side',
                            value: cfg.playersPerSide,
                            min: 2,
                            max: 15,
                            onChanged: (v) =>
                                setState(() => cfg.playersPerSide = v),
                          ),
                          const SizedBox(height: 10),
                          const FieldLabel('Double-side player'),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('None')),
                              ButtonSegment(value: 1, label: Text('+1 common')),
                            ],
                            selected: {cfg.commonPlayers},
                            onSelectionChanged: (s) {
                              setState(() {
                                final next = s.first;
                                if (next != cfg.commonPlayers) {
                                  if (next == 1 &&
                                      cfg.commonPlayers == 0 &&
                                      cfg.playersPerSide < 15) {
                                    cfg.playersPerSide += 1;
                                  } else if (next == 0 &&
                                      cfg.commonPlayers == 1 &&
                                      cfg.playersPerSide > 2) {
                                    cfg.playersPerSide -= 1;
                                    final commonIds = _squadA
                                        .where((id) => _squadB.contains(id))
                                        .toList();
                                    for (final id in commonIds) {
                                      _squadA.remove(id);
                                      _squadB.remove(id);
                                    }
                                  }
                                }
                                cfg.commonPlayers = next;
                              });
                            },
                          ),
                          if (_track && cfg.commonPlayers > 0) ...[
                            const SizedBox(height: 10),
                            _commonPlayerPicker(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.spacing.sm + context.spacing.xs),

              // RULES -----------------------------------------------------
              RectCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionBand('Rules'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StepperRow(
                            label: 'Wide penalty',
                            hint: 'Default 1',
                            value: cfg.rules.widePenalty,
                            min: 0,
                            max: 2,
                            onChanged: (v) =>
                                setState(() => cfg.rules.widePenalty = v),
                          ),
                          StepperRow(
                            label: 'No-ball penalty',
                            hint: 'Default 0',
                            value: cfg.rules.noBallPenalty,
                            min: 0,
                            max: 2,
                            onChanged: (v) =>
                                setState(() => cfg.rules.noBallPenalty = v),
                          ),
                        ],
                      ),
                    ),
                    SettingsRow(
                      label: 'Free hit on no-ball',
                      subtitle: 'Next ball is protected',
                      trailing: RectToggle(
                        value: cfg.rules.freeHit,
                        semanticsLabel: 'Free hit on no-ball',
                        onChanged: (v) => setState(() => cfg.rules.freeHit = v),
                      ),
                    ),
                    SettingsRow(
                      label: 'Last man standing',
                      subtitle: 'Bat on alone after the last wicket',
                      trailing: RectToggle(
                        value: cfg.rules.lastManStanding,
                        semanticsLabel: 'Last man standing',
                        onChanged: (v) =>
                            setState(() => cfg.rules.lastManStanding = v),
                      ),
                    ),
                    SettingsRow(
                      label: 'Advanced extras keys',
                      subtitle: 'WD+overthrows, byes, NB+runs',
                      last: true,
                      trailing: RectToggle(
                        value: widget.store.advancedExtras,
                        semanticsLabel: 'Advanced extras keys',
                        onChanged: (v) => widget.store.setAdvancedExtras(v),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.spacing.sm + context.spacing.xs),

              // PLAYERS ---------------------------------------------------
              RectCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionBand('Players + stats'),
                    SettingsRow(
                      label: 'Track players + stats',
                      subtitle: 'Squads + scorecard. Off = fast.',
                      last: !_track,
                      trailing: RectToggle(
                        value: _track,
                        semanticsLabel: 'Track players and stats',
                        onChanged: (v) => setState(() => _track = v),
                      ),
                    ),
                    if (_track)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Squads come from the CLUB roster (${widget.store.clubRoster.length} players).',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: context.tokens.mutedInk,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _teamSquad(
                              'TEAM A',
                              cfg.teamA,
                              _squadA,
                              _squadB,
                              _qa,
                              (v) => setState(() => _qa = v),
                            ),
                            const SizedBox(height: 10),
                            _teamSquad(
                              'TEAM B',
                              cfg.teamB,
                              _squadB,
                              _squadA,
                              _qb,
                              (v) => setState(() => _qb = v),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: context.spacing.md),
              SizedBox(
                height: 60,
                child: RectBtn(
                  onTap: () {
                    setState(() => _triedSubmit = true);
                    if (a.text.trim().isEmpty || b.text.trim().isEmpty) {
                      return;
                    }
                    if (_track && (_squadA.length < 2 || _squadB.length < 2)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pick at least 2 players per side (or turn tracking off).',
                          ),
                        ),
                      );
                      return;
                    }
                    cfg.trackPlayers = _track;
                    cfg.squadA = _squadA.toList();
                    cfg.squadB = _squadB.toList();
                    widget.store.draft = cfg;
                    widget.store.startMatch(cfg);
                    Navigator.pushReplacementNamed(context, '/scoring');
                  },
                  child: const Text(
                    'START SCORING',
                    style: TextStyle(fontSize: 15, letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Two team summary rows, one open at a time.
  ///
  /// The old layout stacked both full squad lists, so Team B was always a
  /// long scroll away and neither team's state was visible at a glance. Now
  /// each team is a row (dot, name, picked count, chevron) and the open team
  /// shows its list underneath.
  Widget _teamSquad(
    String side,
    String team,
    Set<String> sel,
    Set<String> otherSel,
    String query,
    ValueChanged<String> onQuery,
  ) {
    final isA = side == 'TEAM A';
    final color = isA ? MatchStore.teamAColor : MatchStore.teamBColor;
    final open = _openTeam == side;
    final cap = cfg.playersPerSide;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _openTeam = open ? null : side),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              // Open = a solid team slab with white ink, not a 10% wash: a
              // low-alpha tint is unreadable outdoors and is not a state.
              color: open ? Color(color) : Colors.transparent,
              border: Border.all(color: Color(color), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                TeamDot(open ? 0xFFFFFFFF : color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.trim().isEmpty ? side : team.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: open ? Colors.white : null,
                        ),
                      ),
                      Text(
                        '${sel.length} of $cap picked',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: open ? Colors.white : context.tokens.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PICKED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: open ? Colors.white : context.tokens.mutedInk,
                      ),
                    ),
                    Text(
                      '${sel.length}/$cap',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: open ? Colors.white : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                  color: open ? Colors.white : cs.onSurface,
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          _squadPanel(side, team, sel, otherSel, query, onQuery),
        ],
      ],
    );
  }

  /// The open team's list: search, inline add, and the players themselves.
  Widget _squadPanel(
    String side,
    String team,
    Set<String> sel,
    Set<String> otherSel,
    String query,
    ValueChanged<String> onQuery,
  ) {
    final store = widget.store;
    final q = query.toLowerCase().trim();
    // Cross-exclusion: a player picked for one side never appears on the
    // other — unless the match allows a common player, in which case the
    // shared pick stays visible on both.
    final sharedOk = cfg.commonPlayers > 0;
    final pool = store.clubRoster.where((p) {
      if (!p.active) return false;
      // Cross-exclusion: a player picked for the other side is hidden, EXCEPT
      // when a common (double-side) player is still needed — then the team-1
      // players stay visible so the SAME player can be picked in team B (and
      // vice versa). Once the common-player slot is filled, the rest are hidden.
      if (otherSel.contains(p.id)) {
        if (!sharedOk) return false;
        final overlap = sel.where((id) => otherSel.contains(id)).length;
        if (!sel.contains(p.id) && overlap >= cfg.commonPlayers) return false;
      }
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
    // The panel is only built when the team row is OPEN, so the roster is
    // listed straight away. The "More" toggle only widens it. The old code
    // hid the roster until the search field was tapped, which left an open
    // team looking empty.
    final listed = pool;
    // The XI can never exceed players-per-side. Once it is full the remaining
    // players are HIDDEN, not greyed out: a row you cannot tap is noise on a
    // phone, and a dimmed row still invites mis-taps between matches. The
    // picked ones stay listed so a pick can always be undone. Raising
    // players-per-side brings the rest straight back.
    final cap = cfg.playersPerSide;
    final full = sel.length >= cap;
    final listedFull = full
        ? listed.where((p) => sel.contains(p.id)).toList()
        : listed;
    final visible = expanded
        ? listedFull.take(12).toList()
        : listedFull.take(8).toList();
    final hidden = listedFull.length - visible.length;
    final otherLabel = side == 'TEAM A' ? cfg.teamB : cfg.teamA;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _expanded.add(side)),
                child: RectField(
                  label: 'Select players',
                  controller: _searchCtrls.putIfAbsent(
                    side,
                    () => TextEditingController(),
                  ),
                  prefixIcon: Icons.search,
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
                  onChanged: onQuery,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Add player',
              child: InkWell(
                onTap: () async {
                  if (sel.length >= cap) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'XI full at $cap — raise players per side first.',
                        ),
                      ),
                    );
                    return;
                  }
                  final p = await showAddPlayerSheet(
                    context,
                    store,
                    title: 'ADD TO ${team.trim().isEmpty ? side : team.trim()}',
                  );
                  if (p == null || !mounted) return;
                  if (sel.length >= cap) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'XI full at $cap — raise players per side first.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (otherSel.contains(p.id) && cfg.commonPlayers == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Already in the other XI.')),
                    );
                    return;
                  }
                  if (otherSel.contains(p.id) && cfg.commonPlayers > 0) {
                    final overlap = sel
                        .where((id) => otherSel.contains(id))
                        .length;
                    if (overlap >= cfg.commonPlayers) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Only ${cfg.commonPlayers} common player allowed.',
                          ),
                        ),
                      );
                      return;
                    }
                  }
                  setState(() => sel.add(p.id));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    // The side being edited owns the key: a blue + beside the
                    // red team's list read as "add to team A".
                    color: Color(
                      side == 'TEAM A'
                          ? MatchStore.teamAColor
                          : MatchStore.teamBColor,
                    ),
                    borderRadius: BorderRadius.circular(
                      context.spacing.radiusSm,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (pool.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.group_add_outlined,
            title: 'NO PLAYERS YET',
            message: 'Add one with the + above, or build the roster first in CLUB + PLAYERS.',
          ),
        if (full && pool.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'XI full. Raise players/side to pick more, or tap one to remove.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.tokens.mutedInk,
              ),
            ),
          ),
        for (final p in visible)
          Builder(
            builder: (_) {
              final stats = _playerStats(store, p.id);
              return DetailRow(
                title: p.name,
                subtitle:
                    '${_roleName(p.role)} • ${battingStyleLabel(p.battingStyle)} • ${bowlingStyleLabel(p.bowlingStyle)}${otherSel.contains(p.id) ? ' • also in $otherLabel' : ''}',
                valueLabel: stats.$1,
                value: stats.$2,
                trailing: Icon(
                  sel.contains(p.id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: sel.contains(p.id)
                      ? context.tokens.statGoodInk
                      : context.tokens.mutedInk,
                ),
                onTap: () => setState(() {
                  if (sel.contains(p.id)) {
                    sel.remove(p.id);
                  } else {
                    sel.add(p.id);
                  }
                }),
              );
            },
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RectBtn(
              primary: false,
              onTap: () => setState(() => _expanded.add(side)),
              child: Text(expanded ? 'SHOW LESS' : 'MORE ($hidden)'),
            ),
          ),
      ],
    );
  }

  Widget _commonPlayerPicker() {
    final store = widget.store;
    final commonIds = _squadA.where((id) => _squadB.contains(id)).toList();
    final eligible = store.clubRoster
        .where(
          (p) => p.active && !_squadA.contains(p.id) && !_squadB.contains(p.id),
        )
        .toList();
    final cap = cfg.playersPerSide;
    final full = _squadA.length >= cap || _squadB.length >= cap;
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
            constraints: const BoxConstraints(),
            onPressed: () => setState(() {
              for (final id in commonIds) {
                _squadA.remove(id);
                _squadB.remove(id);
              }
            }),
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
              setState(() {
                _squadA.add(id);
                _squadB.add(id);
              });
            },
          ),
        ),
      ],
    );
  }

  /// Compact career form for the squad picker: strike rate once they have
  /// faced a ball, economy once they have bowled. No match count — the umpire
  /// picks on how they play, not how often they turned up.
  (String?, String?) _playerStats(MatchStore store, String id) {
    final bat = store.careerBatting(id);
    final bowl = store.careerBowling(id);
    final sr = bat.strikeRate;
    final eco = bowl.economy;
    if (sr != null && eco != null) {
      return (
        'SR · ECO',
        '${sr.toStringAsFixed(1)} · ${eco.toStringAsFixed(2)}',
      );
    }
    if (sr != null) return ('SR', sr.toStringAsFixed(1));
    if (eco != null) return ('ECO', eco.toStringAsFixed(2));
    return (null, null);
  }

  String _roleName(PlayerRole r) => switch (r) {
    PlayerRole.batter => 'Batter',
    PlayerRole.bowler => 'Bowler',
    PlayerRole.allRounder => 'All-rounder',
    PlayerRole.keeper => 'Keeper',
  };
}
