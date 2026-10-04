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
      totalOvers: 2,
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
    final cfg = MatchConfig(
        teamA: 'A', teamB: 'B', battingFirst: 'B', totalOvers: 2);
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

  test('twelve glare-proof presets exist', () {
    expect(StylePreset.ids.length, 12);
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
}
