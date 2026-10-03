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

  test('style + font persist', () async {
    final s = freshStore();
    s.setStyle('led');
    s.setFont('ledger');
    expect(s.styleId, 'led');
    expect(s.fontId, 'ledger');
  });

  test('ten glare-proof presets exist', () {
    expect(StylePreset.ids.length, 10);
    for (final id in StylePreset.ids) {
      expect(StylePreset.of(id).name.isNotEmpty, true);
    }
  });

  test('eleven celebrations with legacy migration', () {
    expect(MatchStore.celebIds.length, 11);
    expect(MatchStore.migrateCeleb('pulse'), 'pop');
    expect(MatchStore.migrateCeleb('shimmer'), 'sweep');
    expect(MatchStore.migrateCeleb('glow'), 'glow');
    expect(MatchStore.migrateCeleb('nope'), 'rise');
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
    // 6 legal + 1 wide = 7 entries, strip must see 6 -> 7 growth.
    for (var i = 0; i < 6; i++) {
      s.score(action: 'RUNS', runs: 1);
    }
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
}
