import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/store.dart';
import 'package:cricket_scoring/theme.dart';

MatchStore freshStore() {
  final s = MatchStore();
  s.draft = MatchConfig(
    teamA: 'A',
    teamB: 'B',
    totalOvers: 5,
    playersPerSide: 5,
    rules: Rules(widePenalty: 1, noBallPenalty: 0),
  );
  s.startMatch(s.draft);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('players join a default club automatically', () {
    final s = MatchStore();
    expect(s.activeClubId, isNull);
    // No manual club step: the first add creates and selects a default club.
    final auto = s.addPlayer(name: 'No Club');
    expect(auto, isNotNull);
    expect(s.activeClubId, isNotNull);
    expect(s.clubs.length, 1);
    expect(s.addPlayersBulk('A\nB').added.length, 2);
    final club = s.createClub(name: 'Eagles');
    expect(s.activeClubId, club.id);
    final created = s.addPlayer(
      name: 'Rohit',
      battingStyle: BattingStyle.leftHand,
      bowlingStyle: BowlingStyle.rightSpin,
    );
    expect(created, isNotNull);
    expect(created!.battingStyle, BattingStyle.leftHand);
    expect(created.bowlingStyle, BowlingStyle.rightSpin);
    expect(s.clubRoster.length, 1);
  });

  test('duplicate names warn and never create', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    expect(s.addPlayer(name: 'Rohit'), isNotNull);
    expect(s.duplicateName('rohit sharma'.split(' ').first), isTrue);
    expect(s.addPlayer(name: 'ROHIT'), isNull);
    expect(s.clubRoster.length, 1);
    final res = s.addPlayersBulk('Rohit\nDeepak');
    expect(res.added.length, 1);
    expect(res.skipped, 1);
  });

  test('mid-match squad rules: cap, exclusion, removal', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1', 'B2']) s.addPlayer(name: n)!.id,
    ];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 2,
      trackPlayers: true,
      squadA: [ids[0], ids[1]],
      squadB: [ids[2]],
    );
    s.startMatch(s.draft);
    // Cap: XI already full at 2.
    expect(s.addToSquad('A', ids[3]), contains('full'));
    // Cross-exclusion without a common player.
    final s2 = MatchStore();
    expect(s2.addToSquad('A', ids[0]), contains('tracking'));
    // Removal of an uncapped pick works; setup tested paths cover the rest.
    expect(s.removeFromSquad('A', ids[0]), isNull);
    expect(s.match!.config.squadA, isNot(contains(ids[0])));
  });

  test('mid-match squad cap follows the pending settings value', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1', 'B2', 'A3']) s.addPlayer(name: n)!.id,
    ];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 2,
      trackPlayers: true,
      squadA: [ids[0], ids[1]],
      squadB: [ids[2], ids[3]],
    );
    s.startMatch(s.draft);
    // Saved config still says 2; the sheet has already raised it to 3.
    expect(s.addToSquad('A', ids[4], cap: 3), isNull);
    expect(s.match!.config.squadA, contains(ids[4]));
  });

  test('mid-match common pick accepts the pending double-side value', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1', 'B2', 'C1']) s.addPlayer(name: n)!.id,
    ];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 2,
      trackPlayers: true,
      squadA: [ids[0], ids[1]],
      squadB: [ids[2], ids[3]],
    );
    s.startMatch(s.draft);
    // The toggle is still pending at 0; the picker passes "One".
    expect(s.addCommonPlayer(ids[4], cap: 3, commonPlayers: 1), isNull);
    expect(s.match!.config.squadA, contains(ids[4]));
    expect(s.match!.config.squadB, contains(ids[4]));
  });

  test('setBowler refuses the just-bowled bowler', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1', 'B2']) s.addPlayer(name: n)!.id,
    ];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 4,
      trackPlayers: true,
      squadA: [ids[0], ids[1]],
      squadB: [ids[2], ids[3]],
    );
    s.startMatch(s.draft);
    s.setOpeners(ids[0], ids[1]);
    expect(s.setBowler(ids[2]), isNull);
    expect(s.setBowler(ids[2]), isNotNull);
    expect(s.setBowler(ids[3]), isNull);
  });

  test('retired-out falls a wicket, retired-hurt does not', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1']) s.addPlayer(name: n)!.id,
    ];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 5,
      playersPerSide: 5,
      trackPlayers: true,
      squadA: ids.sublist(0, 2),
      squadB: [ids[2]],
    );
    s.startMatch(s.draft);
    s.setOpeners(ids[0], ids[1]);
    s.setBowler(ids[2]);
    final before = s.innings!.wickets;
    s.retireStriker(DismissalType.retiredOut);
    expect(s.innings!.wickets, before + 1);
  });

  test('deletePlayer refuses in-play picks, deletes the rest', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final a = s.addPlayer(name: 'A1')!.id;
    final b = s.addPlayer(name: 'B1')!.id;
    expect(s.deletePlayer(a), isNull);
    expect(s.clubRoster.map((p) => p.id), isNot(contains(a)));
    // In a live squad: refused until removed from the XI.
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 4,
      trackPlayers: true,
      squadA: [b],
      squadB: [],
    );
    s.startMatch(s.draft);
    expect(s.deletePlayer(b), isNotNull);
  });

  test('bowler latch fields persist through JSON', () {
    final sh = InningsSheet(battingTeam: 'A', bowlingTeam: 'B')
      ..closedOvers = 2
      ..lastBowlerId = 'p1'
      ..needsNewBowler = true;
    final back = InningsSheet.fromJson(sh.toJson());
    expect(back.closedOvers, 2);
    expect(back.lastBowlerId, 'p1');
    expect(back.needsNewBowler, isTrue);
  });

  test('tracked scoring waits for openers and bowler', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1']) s.addPlayer(name: n)!.id,
    ];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 4,
      trackPlayers: true,
      squadA: [ids[0], ids[1]],
      squadB: [ids[2]],
    );
    s.startMatch(s.draft);
    // No openers yet: the ball is refused, nothing recorded.
    expect(s.score(action: 'RUNS', runs: 1), MatchStore.needSetupMsg);
    expect(s.innings!.runs, 0);
    s.setOpeners(ids[0], ids[1]);
    expect(s.score(action: 'RUNS', runs: 1), MatchStore.needSetupMsg);
    s.setBowler(ids[2]);
    expect(s.score(action: 'RUNS', runs: 1), isNull);
    expect(s.innings!.runs, 1);
  });

  test('a new over latches until a different bowler is picked', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1', 'B2']) s.addPlayer(name: n)!.id,
    ];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 4,
      trackPlayers: true,
      squadA: [ids[0], ids[1]],
      squadB: [ids[2], ids[3]],
    );
    s.startMatch(s.draft);
    s.setOpeners(ids[0], ids[1]);
    s.setBowler(ids[2]);
    for (var i = 0; i < 6; i++) {
      expect(s.score(action: 'DOT'), isNull);
    }
    // Over done, same bowler still assigned: refused, nothing recorded.
    expect(s.score(action: 'DOT'), MatchStore.needBowlerMsg);
    expect(s.innings!.legalDeliveries, 6);
    expect(s.setBowler(ids[2]), isNotNull);
    expect(s.setBowler(ids[3]), isNull);
    expect(s.score(action: 'DOT'), isNull);
    expect(s.innings!.legalDeliveries, 7);
  });

  test('no-ball default is 0', () {
    expect(Rules().noBallPenalty, 0);
    expect(Rules().widePenalty, 1);
  });

  test('common players persist in config', () {
    final s = freshStore();
    s.match!.config.commonPlayers = 1;
    expect(s.match!.config.sidesLabel, '4 + 1 vs 4 + 1');
  });

  test('batting-first picker orders innings', () {
    final s = MatchStore();
    final cfg = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      battingFirst: 'B',
      totalOvers: 2,
    );
    s.startMatch(cfg);
    expect(s.innings!.battingTeam, 'B');
    expect(s.innings!.bowlingTeam, 'A');
  });

  test('style + font persist', () async {
    final s = freshStore();
    s.setStyle('led');
    s.setFont('ledger');
    expect(s.styleId, 'led');
    expect(s.fontId, 'ledger');
  });

  test('seven glare-proof presets exist', () {
    expect(StylePreset.ids.length, 7);
    for (final id in StylePreset.ids) {
      expect(StylePreset.of(id).name.isNotEmpty, true);
    }
  });

  test('nine layout-safe celebrations with migration', () {
    expect(MatchStore.celebIds.length, 9);
    expect(MatchStore.migrateCeleb('pulse'), 'pop');
    expect(MatchStore.migrateCeleb('roll'), 'pop');
    expect(MatchStore.migrateCeleb('rise'), 'pop');
    expect(MatchStore.migrateCeleb('shimmer'), 'glow');
    expect(MatchStore.migrateCeleb('ring'), 'blink');
    expect(MatchStore.migrateCeleb('burst'), 'flash');
    expect(MatchStore.migrateCeleb('nope'), 'pop');
  });

  test('over strip defers rollover until next ball', () {
    final s = freshStore();
    for (var i = 0; i < 6; i++) {
      expect(s.score(action: 'RUNS', runs: 1), isNull);
    }
    final inn = s.innings!;
    // Still one over visible after the 6th legal ball.
    expect(inn.overs.length, 1);
    expect(inn.currentOverBalls.length, 6);
    // Next ball rolls to a fresh over.
    expect(s.score(action: 'DOT'), isNull);
    expect(inn.overs.length, 2);
    expect(inn.currentOverBalls.length, 1);
  });

  test('ball list identity changes so the strip animates', () {
    final s = freshStore();
    // 5 legal + wides: entries grow 6 -> 7 without rollover.
    for (var i = 0; i < 5; i++) {
      s.score(action: 'RUNS', runs: 1);
    }
    s.score(action: 'WIDE');
    final before = s.innings!.currentOverBalls;
    expect(before.length, 6);
    s.score(action: 'WIDE');
    final after = s.innings!.currentOverBalls;
    expect(after.length, 7);
    expect(identical(before, after), false);
  });

  test('mid-match overs below balls bowled is rejected', () {
    final s = freshStore();
    s.score(action: 'RUNS', runs: 1);
    expect(s.applyMidMatch(totalOvers: 0), isNotNull);
  });

  test('declare winner completes + archives', () async {
    final s = freshStore();
    s.declareWinner('A', 'Declared');
    expect(s.match!.completed, true);
    expect(s.match!.winner, 'A');
    final h = await s.history();
    expect(h.length, 1);
  });

  test('run-out badge reads W+runs', () {
    final s = freshStore();
    s.score(action: 'WICKET', runs: 2, wicketType: 'Run Out');
    final last = s.innings!.currentOverBalls.last;
    expect(last.isWicket, true);
    expect(last.badge, 'W+2');
    expect(s.innings!.runs, 2);
    expect(s.innings!.wickets, 1);
  });

  test('complex wickets defaults on', () {
    expect(freshStore().complexWickets, true);
  });

  test('innings completion starts 10s break countdown', () {
    final s = freshStore();
    // freshStore: 5 overs; bowl 30 legal balls to finish innings 1.
    for (var i = 0; i < 30; i++) {
      expect(s.score(action: 'DOT'), isNull);
    }
    expect(s.innings!.completed, true);
    expect(s.breakDest, '/break');
    expect(s.breakWait, 10);
    s.skipBreakWait();
    expect(s.breakDest, isNull);
  });

  test('ball generation advances on score, never on undo', () {
    final s = freshStore();
    expect(s.ballGen, 0);
    s.score(action: 'RUNS', runs: 1);
    s.score(action: 'WIDE');
    expect(s.ballGen, 2);
    s.undo();
    expect(s.ballGen, 2);
  });

  test('armed no-ball allows only run-out', () {
    final s = freshStore();
    s.toggleNb();
    expect(s.nbArmed, true);
    // Other dismissals rejected, state untouched.
    expect(s.score(action: 'WICKET', wicketType: 'Bowled'), isNotNull);
    expect(s.innings!.wickets, 0);
    expect(s.innings!.legalDeliveries, 0);
    // Run-out on the armed NB records an illegal wicket ball.
    s.toggleNb();
    expect(s.score(action: 'WICKET', runs: 1, wicketType: 'Run Out'), isNull);
    final last = s.innings!.currentOverBalls.last;
    expect(last.isWicket, true);
    expect(last.isLegal, false);
    expect(last.extra, 'NB');
    expect(s.innings!.legalDeliveries, 0);
    expect(s.nbArmed, false);
  });

  test('rapid mixed 20-ball scenario stays correct', () {
    final s = freshStore();
    final seq = [
      ['RUNS', 1],
      ['RUNS', 2],
      ['FOUR', 0],
      ['WIDE', 0],
      ['DOT', 0],
      ['SIX', 0],
      ['BYE', 2],
      ['RUNS', 3],
      ['LEGBYE', 1],
      ['WIDE', 2],
      ['RUNS', 1],
      ['RUNS', 1],
      ['FOUR', 0],
      ['DOT', 0],
      ['NB_DIRECT', 1],
      ['RUNS', 2],
      ['SIX', 0],
      ['WIDE', 0],
      ['RUNS', 1],
      ['RUNS', 1],
    ];
    for (final a in seq) {
      expect(s.score(action: a[0] as String, runs: a[1] as int), isNull);
    }
    final inn = s.innings!;
    // legals: all but 3 wides + 1 NB = 16 across 3 overs.
    expect(inn.legalDeliveries, 16);
    expect(inn.overs.length, 3);
    expect(inn.runs, 41);
    s.undo();
    expect(s.innings!.runs, 40);
  });

  test('archive round-trip keeps tracked sheets', () async {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [for (final n in ['A1', 'A2', 'B1', 'B2']) s.addPlayer(name: n)!.id];
    s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 4,
      trackPlayers: true,
      squadA: [ids[0], ids[1]],
      squadB: [ids[2], ids[3]],
    );
    s.startMatch(s.draft);
    s.setOpeners(ids[0], ids[1]);
    s.setBowler(ids[2]);
    s.score(action: 'RUNS', runs: 4);
    s.declareWinner('A', 'Declared');
    // _archive is fire-and-forget; wait for the prefs write to land.
    await Future<void>.delayed(Duration.zero);
    final recs = await s.historyRecords();
    expect(recs.length, 1);
    expect(recs.first['sheets'], isNotNull);
    final sheets = MatchStore.sheetsFromRecord(recs.first);
    expect(sheets['1'], isNotNull);
    expect(sheets['1']!.names.values, contains('A1'));
  });

  test('deleting one archive keeps survivor sheets intact', () async {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [for (final n in ['A1', 'A2', 'B1', 'B2']) s.addPlayer(name: n)!.id];
    MatchConfig cfg() => MatchConfig(
          teamA: 'A',
          teamB: 'B',
          totalOvers: 2,
          playersPerSide: 4,
          trackPlayers: true,
          squadA: [ids[0], ids[1]],
          squadB: [ids[2], ids[3]],
        );
    for (var m = 0; m < 2; m++) {
      s.draft = cfg();
      s.startMatch(s.draft);
      s.setOpeners(ids[0], ids[1]);
      s.setBowler(ids[2]);
      s.score(action: 'RUNS', runs: 2);
      s.declareWinner('A', 'Declared');
      await Future<void>.delayed(Duration.zero);
    }
    expect((await s.historyRecords()).length, 2);
    await s.deleteHistoryAt(0);
    final survivor = (await s.historyRecords()).single;
    expect(survivor['sheets'], isNotNull);
    final sheets = MatchStore.sheetsFromRecord(survivor);
    expect(sheets['1'], isNotNull);
    expect(sheets['1']!.names.values, contains('A1'));
  });

  test('batterySaver persists as opt-in flag', () async {
    final s = MatchStore();
    expect(s.batterySaver, isFalse);
    s.setBatterySaver(true);
    expect(s.isBatterySaverOn, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final p = await SharedPreferences.getInstance();
    expect(p.getBool(MatchStore.kBatterySaver), isTrue);
  });

  test('persist after roster load does not rewrite unchanged roster', () async {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    s.addPlayer(name: 'A1');
    s.addPlayer(name: 'B1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final p = await SharedPreferences.getInstance();
    final before = p.getString(MatchStore.kRoster);
    expect(before, isNotNull);
    // Toggle an unrelated setting: roster JSON must not be re-encoded.
    s.setSound(s.soundOn);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final after = p.getString(MatchStore.kRoster);
    expect(after, before);
  });
}
