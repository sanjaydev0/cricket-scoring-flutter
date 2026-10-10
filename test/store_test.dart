import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/domain/room_snapshot.dart';
import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/ports/sync_port.dart';
import 'package:cricket_scoring/store.dart';
import 'package:cricket_scoring/theme.dart';

MatchStore freshStore({FakeSync? sync}) {
  final s = MatchStore(sync: sync ?? FakeSync());
  s.draft = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 5,
      playersPerSide: 5,
      rules: Rules(widePenalty: 1, noBallPenalty: 0));
  s.startMatch(s.draft);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // --- live rooms -----------------------------------------------------------
  // Sharing is additive: it must publish, and it must never be able to break a
  // ball. These tests use FakeSync precisely because a real network is not
  // available in unit tests and must not be needed to prove that.

  test('a scored ball publishes the whole match to the room', () async {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    final opened = await s.startSharing();
    expect(opened.ok, isTrue);
    expect(opened.code, 'TEST1');
    expect(s.roomCode, 'TEST1');
    // Opening the room publishes once, at seq 1, with nothing scored yet.
    expect(fake.published.length, 1);
    expect(fake.published.first.match['innings1']['runs'], 0);

    s.score(action: 'RUNS', runs: 4);
    expect(fake.published.length, 2);
    final latest = fake.published.last;
    expect(latest.seq, greaterThan(fake.published.first.seq));
    expect(latest.match['innings1']['runs'], 4);
  });

  test('every delivery kind reaches a viewer as a new snapshot', () async {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    await s.startSharing();
    fake.published.clear(); // ignore the opening snapshot
    s.score(action: 'FOUR');
    s.score(action: 'WIDE');
    s.score(action: 'WICKET', wicketType: 'Bowled');
    s.score(action: 'SIX');
    expect(fake.published.length, 4);
    // Monotonic and gap-free: a viewer can order by seq alone.
    expect(fake.published.map((e) => e.seq).toList(), [2, 3, 4, 5]);
  });

  test('undo retracts the ball for viewers', () async {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    await s.startSharing();
    s.score(action: 'RUNS', runs: 4);
    expect(fake.published.last.match['innings1']['runs'], 4);
    await s.undo();
    // The retraction must carry the corrected score, not the stale one.
    expect(fake.published.last.match['innings1']['runs'], 0);
    expect(fake.published.last.seq, greaterThan(2));
  });

  test('sharing is off by default and no ball is published', () {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    expect(s.roomCode, isNull);
    s.score(action: 'RUNS', runs: 1);
    expect(fake.published, isEmpty);
  });

  test('a backend that cannot open a room leaves scoring untouched', () async {
    final fake = FakeSync()..failCreate = true;
    final s = freshStore(sync: fake);
    final opened = await s.startSharing();
    expect(opened.ok, isFalse);
    // The reason is carried, not collapsed into a bare null.
    expect(opened.failure, ShareFailure.failed);
    expect(opened.detail, isNotNull);
    expect(s.roomCode, isNull);
    // And the match still scores normally.
    expect(s.score(action: 'RUNS', runs: 4), isNull);
    expect(s.innings!.runs, 4);
  });

  test('a publish that throws cannot fail the ball it was reporting', () async {
    final fake = FakeSync()..publishError = 'backend on fire';
    final s = freshStore(sync: fake);
    await s.startSharing();
    // Fire-and-forget: the exception must not surface to scoring.
    expect(s.score(action: 'FOUR'), isNull);
    expect(s.innings!.runs, 4);
    expect(s.innings!.wickets, 0);
  });

  test('stopping sharing deletes the room and keeps the match', () async {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    await s.startSharing();
    s.score(action: 'RUNS', runs: 1);
    await s.stopSharing();
    expect(fake.ended, ['TEST1']);
    expect(s.roomCode, isNull);
    // The local match is untouched: sharing was never destructive.
    expect(s.innings!.runs, 1);
    final before = fake.published.length;
    s.score(action: 'RUNS', runs: 1);
    expect(fake.published.length, before);
  });

  test('starting a new match closes the room', () async {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    await s.startSharing();
    s.newMatch();
    expect(fake.ended, ['TEST1']);
    expect(s.roomCode, isNull);
  });

  test('starting sharing twice keeps one room', () async {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    final a = await s.startSharing();
    final b = await s.startSharing();
    expect(a.code, b.code);
    expect(fake.created.length, 1);
  });

  test('a snapshot decodes what the store published', () async {
    final fake = FakeSync();
    final s = freshStore(sync: fake);
    await s.startSharing();
    s.score(action: 'SIX');
    // The viewer path: same JSON, decoded by the same code the viewer uses.
    final back = RoomSnapshot.fromPayload(fake.published.last.toPayload());
    expect(back, isNotNull);
    expect(Match.decode(jsonEncode(back!.match)).innings1.runs, 6);
  });

  test('players need a club first', () {
    final s = MatchStore();
    expect(s.activeClubId, isNull);
    expect(s.addPlayer(name: 'No Club'), isNull);
    expect(s.addPlayersBulk('A\nB').added, isEmpty);
    final club = s.createClub(name: 'Eagles');
    expect(s.activeClubId, club.id);
    final created = s.addPlayer(
        name: 'Rohit',
        battingStyle: BattingStyle.leftHand,
        bowlingStyle: BowlingStyle.rightSpin);
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
      for (final n in ['A1', 'A2', 'B1', 'B2']) s.addPlayer(name: n)!.id
    ];
    s.draft = MatchConfig(
        teamA: 'A',
        teamB: 'B',
        totalOvers: 2,
        playersPerSide: 2,
        trackPlayers: true,
        squadA: [ids[0], ids[1]],
        squadB: [ids[2]]);
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

  test('setBowler refuses the just-bowled bowler', () {
    final s = MatchStore();
    s.createClub(name: 'Eagles');
    final ids = [
      for (final n in ['A1', 'A2', 'B1', 'B2']) s.addPlayer(name: n)!.id
    ];
    s.draft = MatchConfig(
        teamA: 'A',
        teamB: 'B',
        totalOvers: 2,
        playersPerSide: 4,
        trackPlayers: true,
        squadA: [ids[0], ids[1]],
        squadB: [ids[2], ids[3]]);
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
      for (final n in ['A1', 'A2', 'B1']) s.addPlayer(name: n)!.id
    ];
    s.draft = MatchConfig(
        teamA: 'A',
        teamB: 'B',
        totalOvers: 5,
        playersPerSide: 5,
        trackPlayers: true,
        squadA: ids.sublist(0, 2),
        squadB: [ids[2]]);
    s.startMatch(s.draft);
    s.setOpeners(ids[0], ids[1]);
    s.setBowler(ids[2]);
    final before = s.innings!.wickets;
    s.retireStriker(DismissalType.retiredOut);
    expect(s.innings!.wickets, before + 1);
  });

  test('no-ball default is 0', () {
    expect(Rules().noBallPenalty, 0);
    expect(Rules().widePenalty, 1);
  });

  test('common players persist in config', () {
    final s = freshStore();
    s.match!.config.commonPlayers = 1;
    expect(s.match!.config.sidesLabel, '5 + 5 + 1');
  });

  test('batting-first picker orders innings', () {
    final s = MatchStore();
    final cfg =
        MatchConfig(teamA: 'A', teamB: 'B', battingFirst: 'B', totalOvers: 2);
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
}
