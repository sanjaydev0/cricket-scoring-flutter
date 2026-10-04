import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      rules: Rules(widePenalty: 1, noBallPenalty: 0));
  s.startMatch(s.draft);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
