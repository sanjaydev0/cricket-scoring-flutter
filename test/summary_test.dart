import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/summary.dart';
import 'package:cricket_scoring/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MatchStore trackedStore() {
  final s = MatchStore();
  Player mk(String n) => Player(id: 'p_$n', clubId: 'c', name: n);
  for (final n in ['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3']) {
    s.roster.add(mk(n));
  }
  final cfg = MatchConfig(
      teamA: 'A',
      teamB: 'B',
      totalOvers: 2,
      playersPerSide: 4,
      trackPlayers: true,
      squadA: const ['p_A1', 'p_A2', 'p_A3', 'p_A4'],
      squadB: const ['p_B1', 'p_B2', 'p_B3']);
  s.startMatch(cfg);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('extras line lists only nonzero categories', () {
    final inn = Innings(battingTeam: 'A', bowlingTeam: 'B')
      ..wides = 11
      ..noBalls = 3
      ..byes = 4
      ..legByes = 2;
    expect(extrasLine(inn), 'Extras: b 4, lb 2, w 11, nb 3 — total 20');
    expect(extrasLine(Innings(battingTeam: 'A', bowlingTeam: 'B')), 'Extras 0');
  });

  test('did-not-bat excludes everyone with a batting position', () {
    final s = trackedStore();
    s.setOpeners('p_A1', 'p_A2');
    expect(didNotBat(s, 1), ['p_A3', 'p_A4']);
  });

  test('did-not-bat is empty without squads or sheets', () {
    final s = MatchStore();
    s.startMatch(MatchConfig(teamA: 'A', teamB: 'B'));
    expect(didNotBat(s, 1), isEmpty);
  });

  test('retired-hurt counts as batted', () {
    final s = trackedStore();
    s.setOpeners('p_A1', 'p_A2');
    final sheet = s.currentSheet!;
    sheet.batting['p_A3']!
      ..position = 3
      ..isNotOut = false
      ..dismissal = DismissalType.retiredHurt;
    expect(didNotBat(s, 1), ['p_A4']);
  });
}
