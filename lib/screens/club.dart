import 'package:flutter/material.dart';

import '../domain/players.dart';
import '../store.dart';
import '../theme.dart';
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
  BattingStyle _bat = BattingStyle.rightHand;
  BowlingStyle _bowl = BowlingStyle.none;
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
      builder: (_, _) {
        final store = widget.store;
        return Scaffold(
          appBar: RectAppBar(title: 'Club'),
          body: SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _clubCard(context, store),
                  if (store.activeClubId != null) ...[
                    const SizedBox(height: 12),
                    UnderlineTabs(
                      labels: const ['PLAYERS', 'STATS'],
                      selected: _tab == 'players' ? 0 : 1,
                      onChanged: (i) =>
                          setState(() => _tab = i == 0 ? 'players' : 'stats'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (store.activeClubId == null)
                    RectCard(
                      child: Text(
                        'Players, stats and squads unlock once the club exists.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: context.tokens.mutedInk,
                        ),
                      ),
                    )
                  else if (_tab == 'players')
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

  Widget _clubCard(BuildContext context, MatchStore store) {
    if (store.clubs.isEmpty) {
      return RectCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionBand('Club'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Players belong to the club. Create one to start a roster.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: context.tokens.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RectBtn(
                    onTap: () => _clubSheet(context, store),
                    child: const Text('CREATE CLUB'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // Clubs are rows, not chips: a club is a name you pick, and the list must
    // carry the edit and delete actions that chips have no room for.
    return RectCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionBand('Club', trailing: '${store.clubs.length}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in store.clubs)
                  PlayerRow(
                    name: c.name,
                    subtitle: store.activeClubId == c.id
                        ? 'DEFAULT CLUB — new players are added here'
                        : 'Tap to set as default club',
                    selected: store.activeClubId == c.id,
                    enabled: store.activeClubId != c.id,
                    blockedReason: 'DEFAULT CLUB',
                    onTap: () => store.selectClub(c.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Rename club',
                          onPressed: () => _renameClubSheet(context, store, c),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: context.colors.error,
                          ),
                          tooltip: 'Delete club',
                          onPressed: () =>
                              _deleteClubConfirm(context, store, c),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          store.activeClubId == c.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: store.activeClubId == c.id
                              ? context.tokens.statGoodInk
                              : context.tokens.mutedInk,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                RectBtn(
                  primary: false,
                  onTap: () => _clubSheet(context, store),
                  child: const Text('+ NEW CLUB'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renames a club and regenerates its handle.
  void _renameClubSheet(BuildContext context, MatchStore store, Club c) {
    final name = TextEditingController(text: c.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('RENAME CLUB'),
        content: TextField(
          controller: name,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Club name'),
        ),
        actions: [
          RectBtn(
            primary: false,
            onTap: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RectBtn(
            onTap: () {
              final err = store.renameClub(c.id, name.text);
              Navigator.pop(context);
              if (err != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Deleting a club deletes its players too, so this states the blast radius
  /// and the store still refuses while a live match needs them.
  void _deleteClubConfirm(BuildContext context, MatchStore store, Club c) {
    final members = store.clubRoster.where((p) => p.clubId == c.id).length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('DELETE ${c.name}?'),
        content: Text(
          members == 0
              ? 'This club is empty. Nothing else is removed.'
              : 'This also deletes $members player${members == 1 ? '' : 's'} from the club, and their career stats. Saved matches keep their names. This cannot be undone.',
        ),
        actions: [
          RectBtn(
            primary: false,
            onTap: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          RectBtn(
            danger: true,
            onTap: () {
              final err = store.deleteClub(c.id);
              Navigator.pop(context);
              if (err != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                setState(() {});
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _clubSheet(BuildContext context, MatchStore store) {
    final name = TextEditingController();
    showAppSheet(
      context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(title: 'New club'),
              const SizedBox(height: 16),
              RectField(
                label: 'Club name',
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
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
        RectField(
          label: 'Search players',
          controller: _search,
          prefixIcon: Icons.search,
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Clear search',
                  onPressed: () => setState(_search.clear),
                ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: RectField(
                label: 'Add player',
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _add(store),
              ),
            ),
            const SizedBox(width: 8),
            RectBtn(onTap: () => _add(store), child: const Text('+ ADD')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<BattingStyle>(
                isExpanded: true,
                initialValue: _bat,
                decoration: const InputDecoration(labelText: 'Batting'),
                items: const [
                  DropdownMenuItem(
                    value: BattingStyle.rightHand,
                    child: Text('Right-hand bat'),
                  ),
                  DropdownMenuItem(
                    value: BattingStyle.leftHand,
                    child: Text('Left-hand bat'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _bat = v ?? BattingStyle.rightHand),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<BowlingStyle>(
                isExpanded: true,
                initialValue: _bowl,
                decoration: const InputDecoration(labelText: 'Bowling'),
                items: [
                  for (final b in BowlingStyle.values)
                    DropdownMenuItem(
                      value: b,
                      child: Text(bowlingStyleName(b)),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _bowl = v ?? BowlingStyle.none),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const FieldLabel('Role'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in PlayerRole.values)
              ChoiceChip(
                label: Text(_roleName(r)),
                selected: _role == r,
                onSelected: (_) => setState(() => _role = r),
              ),
          ],
        ),
        const SizedBox(height: 10),
        RectBtn(
          primary: false,
          onTap: () => _bulkSheet(context, store),
          child: const Text('BULK ADD (paste a list)'),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          RectCard(
            child: Text(
              'No players yet — add your first above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.tokens.mutedInk,
              ),
            ),
          )
        else
          // One card, one table: the roster is a homogeneous list, so the rows
          // share a single frame and a single rule between them. A card per
          // player made twelve boxes for twelve lines.
          RectCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  DetailRow(
                    // Inactive players stay LISTED and stay tappable. They
                    // still hold their name, so hiding them made the name look
                    // free and then refuse to be used. Locked, never faded.
                    title: list[i].active
                        ? list[i].name
                        : '${list[i].name}  •  INACTIVE',
                    subtitle:
                        '${_roleName(list[i].role)} • ${battingStyleLabel(list[i].battingStyle)} • ${bowlingStyleLabel(list[i].bowlingStyle)}',
                    valueLabel: 'MATCHES',
                    value: '${store.careerMatches(list[i].id)}',
                    dimmed: !list[i].active,
                    last: i == list.length - 1,
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.tokens.mutedInk,
                    ),
                    onTap: () => _playerSheet(context, store, list[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _add(MatchStore store) {
    if (_name.text.trim().isEmpty) return;
    // "Already exists" used to be a dead end: the blocking player was often
    // INACTIVE, which the list filtered out, so the name looked free and was
    // not. Offer the player instead of only naming them.
    final clash = store.playerByName(_name.text.trim());
    if (clash != null) {
      _name.clear();
      setState(() {});
      _duplicateSheet(context, store, clash);
      return;
    }
    final created = store.addPlayer(
      name: _name.text.trim(),
      role: _role,
      battingStyle: _bat,
      bowlingStyle: _bowl,
    );
    if (created == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Already in the club.')));
      return;
    }
    _name.clear();
    setState(() {});
  }

  void _bulkSheet(BuildContext context, MatchStore store) {
    showAppSheet(
      context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(
                title: 'Bulk add',
                caption: 'One per line. Optional role: "Name - bowler".',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bulk,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Players',
                  hintText: 'Rohit Sharma\nRavi Patel - bowler',
                ),
              ),
              const SizedBox(height: 10),
              RectBtn(
                onTap: () {
                  final res = store.addPlayersBulk(_bulk.text);
                  _bulk.clear();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res.skipped > 0
                            ? '${res.added.length} added, ${res.skipped} already existed'
                            : '${res.added.length} added',
                      ),
                    ),
                  );
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

  void _deleteConfirm(BuildContext context, MatchStore store, Player p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('DELETE ${p.name}?'),
        content: const Text(
          'Removes them from the roster and club lists. Past matches keep their name.',
        ),
        actions: [
          RectBtn(
            primary: false,
            onTap: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          RectBtn(
            danger: true,
            onTap: () {
              final err = store.deletePlayer(p.id);
              Navigator.pop(context);
              if (err != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              } else {
                setState(() {});
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Resolves a name clash by showing the player that holds the name, with
  /// the two actions that actually clear it.
  void _duplicateSheet(BuildContext context, MatchStore store, Player clash) {
    showAppSheet(
      context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(
                title: 'Name already taken',
                caption: 'Pick one of these instead',
              ),
              const SizedBox(height: 12),
              Text(
                '${clash.name} is already in ${store.activeClub?.name ?? 'the club'}'
                '${clash.active ? '' : ' (marked INACTIVE)'}'
                '${store.careerMatches(clash.id) > 0 ? ' • ${store.careerMatches(clash.id)} matches played' : ''}.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              RectBtn(
                onTap: () {
                  Navigator.pop(context);
                  _renameSheet(context, store, clash);
                },
                child: const Text('RENAME THAT PLAYER'),
              ),
              const SizedBox(height: 8),
              RectBtn(
                primary: false,
                onTap: () {
                  Navigator.pop(context);
                  _deleteConfirm(context, store, clash);
                },
                child: const Text('DELETE THAT PLAYER'),
              ),
              const SizedBox(height: 8),
              RectBtn(
                primary: false,
                onTap: () => Navigator.pop(context),
                child: const Text('CANCEL'),
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
          decoration: const InputDecoration(),
        ),
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
      ..sort(
        (a, b) => store
            .careerBatting(b.id)
            .runs
            .compareTo(store.careerBatting(a.id).runs),
      );
    if (list.isEmpty) {
      return RectCard(
        padding: EdgeInsets.zero,
        child: const EmptyState(
          icon: Icons.groups_outlined,
          title: 'NO PLAYERS YET',
          message: 'Add a player, or bulk-add your whole roster from a pasted list. Career figures build up as you score.',
        ),
      );
    }
    return RectCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++)
            DetailRow(
              title: list[i].name,
              subtitle: _careerLine(store, list[i].id),
              leading: _Initials(_initials(list[i].name)),
              last: i == list.length - 1,
              trailing: Icon(
                Icons.chevron_right,
                size: 20,
                color: context.tokens.mutedInk,
              ),
              onTap: () => _playerSheet(context, store, list[i]),
            ),
        ],
      ),
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
    showAppSheet(
      context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SheetHeader(
                title: p.name,
                caption: '${_roleName(p.role)} • $m matches',
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              SectionBand('Batting'),
              const SizedBox(height: 8),
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
              SectionBand('Bowling'),
              const SizedBox(height: 8),
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
              SectionBand('Fielding'),
              const SizedBox(height: 8),
              _grid({'Catches': '$fC', 'Run outs': '$fR', 'Stumpings': '$fS'}),
              const SizedBox(height: 16),
              // The row shows the player; the actions live here so the roster
              // stays one clean line per person.
              Row(
                children: [
                  Expanded(
                    child: RectBtn(
                      primary: false,
                      onTap: () {
                        Navigator.pop(context);
                        _renameSheet(context, store, p);
                      },
                      child: const Text('RENAME'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RectBtn(
                      primary: false,
                      onTap: () {
                        store.setPlayerActive(p.id, !p.active);
                        Navigator.pop(context);
                      },
                      child: Text(p.active ? 'DEACTIVATE' : 'ACTIVATE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RectBtn(
                      danger: true,
                      onTap: () {
                        Navigator.pop(context);
                        _deleteConfirm(context, store, p);
                      },
                      child: const Text('DELETE'),
                    ),
                  ),
                ],
              ),
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
              border: Border.all(color: context.tokens.borderRow),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: context.tokens.mutedInk,
                  ),
                ),
                Text(
                  e.value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
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

/// Shared "add player" sheet.
///
/// Used by the club roster and by the match-setup squad picker, so a player
/// created while picking a XI is a REAL club player — the old flow forced a
/// trip to CLUB first, which is where people got stuck.
Future<Player?> showAddPlayerSheet(
  BuildContext context,
  MatchStore store, {
  String title = 'ADD PLAYER',
}) async {
  final nameCtl = TextEditingController();
  var role = PlayerRole.allRounder;
  var bat = BattingStyle.rightHand;
  var bowl = BowlingStyle.none;
  Player? created;
  String? error;

  await showAppSheet(
    context,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Saved to the club roster and this XI.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<BattingStyle>(
                        isExpanded: true,
                        initialValue: bat,
                        decoration: const InputDecoration(labelText: 'Batting'),
                        items: const [
                          DropdownMenuItem(
                            value: BattingStyle.rightHand,
                            child: Text('Right-hand bat'),
                          ),
                          DropdownMenuItem(
                            value: BattingStyle.leftHand,
                            child: Text('Left-hand bat'),
                          ),
                        ],
                        onChanged: (v) =>
                            setSheet(() => bat = v ?? BattingStyle.rightHand),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<BowlingStyle>(
                        isExpanded: true,
                        initialValue: bowl,
                        decoration: const InputDecoration(labelText: 'Bowling'),
                        items: [
                          for (final b in BowlingStyle.values)
                            DropdownMenuItem(
                              value: b,
                              child: Text(bowlingStyleName(b)),
                            ),
                        ],
                        onChanged: (v) =>
                            setSheet(() => bowl = v ?? BowlingStyle.none),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in PlayerRole.values)
                      ChoiceChip(
                        label: Text(_roleNameOf(r)),
                        selected: role == r,
                        onSelected: (_) => setSheet(() => role = r),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                RectBtn(
                  onTap: () {
                    final name = nameCtl.text.trim();
                    if (name.isEmpty) {
                      setSheet(() => error = 'Name required');
                      return;
                    }
                    final clash = store.playerByName(name);
                    if (clash != null) {
                      setSheet(() => error = 'Already in the club');
                      return;
                    }
                    final p = store.addPlayer(
                      name: name,
                      role: role,
                      battingStyle: bat,
                      bowlingStyle: bowl,
                    );
                    if (p == null) {
                      setSheet(() => error = 'Already in the club');
                      return;
                    }
                    created = p;
                    Navigator.pop(sheetCtx);
                  },
                  child: const Text('ADD PLAYER'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  nameCtl.dispose();
  return created;
}

/// Role label shared by the club form and the add-player sheet.
String _roleNameOf(PlayerRole r) => switch (r) {
  PlayerRole.batter => 'Batter',
  PlayerRole.bowler => 'Bowler',
  PlayerRole.allRounder => 'All-rounder',
  PlayerRole.keeper => 'Keeper',
};

/// A 32dp initials disc for a roster row. Never a name in a pill.
class _Initials extends StatelessWidget {
  final String text;
  const _Initials(this.text);

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.tokens.lockedFill,
      shape: BoxShape.circle,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: context.tokens.lockedInk,
      ),
    ),
  );
}
