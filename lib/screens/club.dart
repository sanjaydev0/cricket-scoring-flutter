import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/players.dart';
import '../store.dart';
import 'widgets.dart';

/// CLUB: profiles (local PIN unlock), the club, and its roster.
///
/// Everything here is on-device and offline. The roster ids created here are
/// stable for life, which is what lets career figures survive a rename.
class ClubScreen extends StatefulWidget {
  final MatchStore store;
  const ClubScreen(this.store, {super.key});
  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _bulk = TextEditingController();
  PlayerRole _role = PlayerRole.allRounder;
  String _tab = 'players'; // players | stats

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _bulk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (_, __) {
        final store = widget.store;
        return Scaffold(
          appBar: AppBar(title: const Text('CLUB')),
          body: SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _profileCard(context, store),
                  const SizedBox(height: 12),
                  _clubCard(context, store),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RectBtn(
                          primary: _tab == 'players',
                          onTap: () => setState(() => _tab = 'players'),
                          child: const Text('PLAYERS'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RectBtn(
                          primary: _tab == 'stats',
                          onTap: () => setState(() => _tab = 'stats'),
                          child: const Text('STATS'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_tab == 'players')
                    _players(context, store)
                  else
                    _statsList(context, store),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profileCard(BuildContext context, MatchStore store) {
    if (store.profiles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('LOCAL PROFILE',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                'Unlocks the app on this phone only. Never required — skip to score straight away.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              RectBtn(
                onTap: () => _profileSheet(context, store, null),
                child: const Text('CREATE PROFILE'),
              ),
              const SizedBox(height: 8),
              RectBtn(
                primary: false,
                onTap: () => store.useWithoutProfile(),
                child: const Text('CONTINUE WITHOUT'),
              ),
            ],
          ),
        ),
      );
    }
    final active = store.profiles.where((p) => p.id == store.activeProfileId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LOCAL PROFILE',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in store.profiles)
                  ChoiceChip(
                    label: Text(p.name),
                    selected: store.activeProfileId == p.id,
                    onSelected: (_) => _profileSheet(context, store, p),
                  ),
                ActionChip(
                  label: const Text('+ New'),
                  onPressed: () => _profileSheet(context, store, null),
                ),
              ],
            ),
            if (active.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Unlocked as ${active.first.name}',
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  void _profileSheet(
      BuildContext context, MatchStore store, ClubProfile? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final pin = TextEditingController();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'NEW PROFILE' : 'UNLOCK ${existing.name}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (existing == null)
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Your name', border: OutlineInputBorder()),
                ),
              if (existing == null) const SizedBox(height: 10),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: '4-digit PIN', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              RectBtn(
                onTap: () {
                  if (existing == null) {
                    if (name.text.trim().isEmpty || pin.text.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Name + 4-digit PIN needed')));
                      return;
                    }
                    store.createProfile(
                        name: name.text.trim(), pin: pin.text.trim());
                  } else {
                    if (!store.unlockProfile(existing.id, pin.text.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Wrong PIN')));
                      return;
                    }
                  }
                  Navigator.pop(context);
                },
                child: Text(existing == null ? 'CREATE' : 'UNLOCK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clubCard(BuildContext context, MatchStore store) {
    if (store.clubs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('CLUB', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('One club per profile. Players belong to the club.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              RectBtn(
                onTap: () => _clubSheet(context, store),
                child: const Text('CREATE CLUB'),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CLUB', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in store.clubs)
                  ChoiceChip(
                    label: Text(c.name),
                    selected: store.activeClubId == c.id,
                    onSelected: (_) => store.selectClub(c.id),
                  ),
                ActionChip(
                  label: const Text('+ New'),
                  onPressed: () => _clubSheet(context, store),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clubSheet(BuildContext context, MatchStore store) {
    final name = TextEditingController();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('NEW CLUB',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Club name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              RectBtn(
                onTap: () {
                  if (name.text.trim().isEmpty) return;
                  store.createClub(name: name.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('CREATE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _players(BuildContext context, MatchStore store) {
    final q = _search.text;
    final list = store.searchRoster(q);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Search players',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Add player', border: OutlineInputBorder()),
                onSubmitted: (_) => _add(store),
              ),
            ),
            const SizedBox(width: 8),
            RectBtn(onTap: () => _add(store), child: const Text('+ ADD')),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final r in PlayerRole.values)
              ChoiceChip(
                label: Text(_roleName(r)),
                selected: _role == r,
                onSelected: (_) => setState(() => _role = r),
              ),
          ],
        ),
        const SizedBox(height: 6),
        RectBtn(
          primary: false,
          onTap: () => _bulkSheet(context, store),
          child: const Text('BULK ADD (paste a list)'),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No players yet — add your first above.',
                  textAlign: TextAlign.center),
            ),
          ),
        for (final p in list)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(_initials(p.name))),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                  '${_roleName(p.role)} • ${store.careerMatches(p.id)} matches'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                        p.active ? Icons.check_circle : Icons.cancel_outlined),
                    tooltip: p.active ? 'Active' : 'Inactive',
                    onPressed: () => store.setPlayerActive(p.id, !p.active),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _renameSheet(context, store, p),
                  ),
                ],
              ),
              onTap: () => _playerSheet(context, store, p),
            ),
          ),
      ],
    );
  }

  void _add(MatchStore store) {
    if (_name.text.trim().isEmpty) return;
    store.addPlayer(name: _name.text.trim(), role: _role);
    _name.clear();
    setState(() {});
  }

  void _bulkSheet(BuildContext context, MatchStore store) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('BULK ADD',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('One per line. Optional role: "Name - bowler".',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _bulk,
                maxLines: 6,
                decoration: const InputDecoration(
                    hintText: 'Rohit Sharma\nRavi Patel - bowler',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              RectBtn(
                onTap: () {
                  final added = store.addPlayersBulk(_bulk.text);
                  _bulk.clear();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${added.length} added')));
                  setState(() {});
                },
                child: const Text('ADD ALL'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _renameSheet(BuildContext context, MatchStore store, Player p) {
    final c = TextEditingController(text: p.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('RENAME'),
        content: TextField(
            controller: c,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          RectBtn(
            primary: false,
            onTap: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RectBtn(
            onTap: () {
              if (c.text.trim().isNotEmpty) {
                store.renamePlayer(p.id, c.text.trim());
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _statsList(BuildContext context, MatchStore store) {
    final list = store.clubRoster.toList()
      ..sort((a, b) => store
          .careerBatting(b.id)
          .runs
          .compareTo(store.careerBatting(a.id).runs));
    if (list.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No players yet.', textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        for (final p in list)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(_initials(p.name))),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_careerLine(store, p.id)),
              onTap: () => _playerSheet(context, store, p),
            ),
          ),
      ],
    );
  }

  String _careerLine(MatchStore store, String id) {
    final b = store.careerBatting(id);
    final w = store.careerBowling(id);
    final m = store.careerMatches(id);
    if (m == 0) return 'No matches yet';
    final parts = <String>['$m matches', '${b.runs} runs'];
    if (w.innings > 0) parts.add('${w.wickets} wkts');
    return parts.join(' • ');
  }

  void _playerSheet(BuildContext context, MatchStore store, Player p) {
    final b = store.careerBatting(p.id);
    final w = store.careerBowling(p.id);
    final m = store.careerMatches(p.id);
    var fC = 0, fR = 0, fS = 0;
    for (final s in store.sheets.values) {
      final f = s.fielding[p.id];
      if (f != null) {
        fC += f.catches;
        fR += f.runOuts;
        fS += f.stumpings;
      }
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name.toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18)),
              Text('${_roleName(p.role)} • $m matches',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              const Text('BATTING',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              _grid({
                'Innings': '${b.innings}',
                'Runs': '${b.runs}',
                'Balls': '${b.balls}',
                'Outs': '${b.outs}',
                'NO': '${b.notOuts}',
                'Avg': _num(b.average),
                'SR': _num(b.strikeRate),
                '4s': '${b.fours}',
                '6s': '${b.sixes}',
                'Dots': '${b.dots}',
                'HS': '${b.hs}',
                '50s': '${b.fifties}',
              }),
              const SizedBox(height: 12),
              const Text('BOWLING',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              _grid({
                'Innings': '${w.innings}',
                'Overs': w.overs,
                'Runs': '${w.runs}',
                'Wkts': '${w.wickets}',
                'Avg': _num(w.average),
                'Econ': _num(w.economy),
                'SR': _num(w.strikeRate),
                'Maidens': '${w.maidens}',
                'Wd': '${w.wides}',
                'Nb': '${w.noBalls}',
                'Best': w.bestW > 0 ? '${w.bestW}/${w.bestR}' : '—',
                '3w': '${w.threeHauls}',
              }),
              const SizedBox(height: 12),
              const Text('FIELDING',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              _grid({
                'Catches': '$fC',
                'Run outs': '$fR',
                'Stumpings': '$fS',
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(Map<String, String> cells) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in cells.entries)
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800)),
                Text(e.value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
      ],
    );
  }

  String _num(double? v) => v == null ? '—' : v.toStringAsFixed(1);
  String _roleName(PlayerRole r) => switch (r) {
        PlayerRole.batter => 'Batter',
        PlayerRole.bowler => 'Bowler',
        PlayerRole.allRounder => 'All-rounder',
        PlayerRole.keeper => 'Keeper',
      };
  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
