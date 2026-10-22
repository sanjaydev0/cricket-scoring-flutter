import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/player_sheets.dart';
import 'package:cricket_scoring/store.dart';

/// Mid-over batter changes, and the setup defaults that came with them.
///
/// A substitution is not a wicket and not a run: the newcomer stands where the
/// departing man stood, nobody moves ends, and one undo puts both men back.
/// The two failure modes these tests exist for: the newcomer landing at the
/// WRONG end (the striker's end swallowed the non-striker's replacement), and
/// a change that could not be undone in one tap.

MatchStore _fixture({int players = 5}) {
  final s = MatchStore(sync: FakeSync());
  s.hapticsOn = false;
  s.createClub(name: 'Gully Kings');
  final a = [for (var i = 1; i <= players; i++) s.addPlayer(name: 'A$i')!.id];
  final b = [for (var i = 1; i <= players; i++) s.addPlayer(name: 'B$i')!.id];
  s.draft = MatchConfig(
      teamA: 'Lions',
      teamB: 'Tigers',
      totalOvers: 2,
      playersPerSide: players,
      trackPlayers: true,
      squadA: a,
      squadB: b);
  s.startMatch(s.draft);
  s.setOpeners(a[0], a[1]);
  s.setBowler(b[0]);
  return s;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('mid-over batter change', () {
    test('a new batter is BLUE and RED by default', () {
      final cfg = MatchConfig();
      expect(cfg.teamA, 'BLUE');
      expect(cfg.teamB, 'RED');
      // Old saves keep the names they were played with.
      final old = MatchConfig.fromJson(
          <String, dynamic>{'teamA': 'EAGLES XI', 'teamB': 'TITANS'});
      expect(old.teamA, 'EAGLES XI');
      expect(old.teamB, 'TITANS');
    });

    test('the striker is replaced by a man who faces the next ball', () {
      final s = _fixture();
      final sheet = s.currentSheet!;
      final incoming = s.squadForTeam('Lions')[2].id;
      expect(sheet.strikerId, s.squadForTeam('Lions')[0].id);

      expect(
          s.substituteBatter(atStrikerEnd: true, newcomerId: incoming), isNull);

      expect(sheet.strikerId, incoming, reason: 'the newcomer takes his end');
      expect(sheet.nonStrikerId, s.squadForTeam('Lions')[1].id,
          reason: 'the other end does not move');
      // The ball after the change belongs to the newcomer.
      s.score(action: 'RUNS', runs: 1);
      expect(sheet.batting[incoming]!.runs, 1,
          reason: 'the newcomer faced the ball');
      expect(sheet.batting[incoming]!.balls, 1);
    });

    test('the non-striker is replaced and the striker keeps his strike', () {
      final s = _fixture();
      final sheet = s.currentSheet!;
      final incoming = s.squadForTeam('Lions')[2].id;
      final striker = s.squadForTeam('Lions')[0].id;

      expect(s.substituteBatter(atStrikerEnd: false, newcomerId: incoming),
          isNull);

      expect(sheet.nonStrikerId, incoming);
      expect(sheet.strikerId, striker, reason: 'the striker keeps his end');
      s.score(action: 'DOT');
      expect(sheet.striker!.playerId, striker,
          reason: 'and he is still the one facing');
    });

    test('the man at the other end cannot be the replacement', () {
      final s = _fixture();
      final sheet = s.currentSheet!;
      final striker = s.squadForTeam('Lions')[0].id;
      final options =
          sheet.replacementOptions(s.squadForTeam('Lions')[1].id, striker);
      expect(options.contains(striker), isFalse);
      expect(options.contains(s.squadForTeam('Lions')[1].id), isFalse);
      expect(options.contains(s.squadForTeam('Lions')[2].id), isTrue);
      // And the store refuses it, not just the picker.
      expect(s.substituteBatter(atStrikerEnd: false, newcomerId: striker),
          isNotNull);
    });

    test('retired hurt is not a wicket, retired out is', () {
      final s = _fixture();
      final incoming = s.squadForTeam('Lions')[2].id;
      final wicketsBefore = s.innings!.wickets;

      s.substituteBatter(atStrikerEnd: true, newcomerId: incoming);
      expect(s.innings!.wickets, wicketsBefore,
          reason: 'a substitution is not a dismissal');
      expect(s.currentSheet!.batting[s.squadForTeam('Lions')[0].id]!.dismissal,
          DismissalType.retiredHurt);

      // A retired-hurt man may come back later; a retired-out man may not.
      final options = s.currentSheet!
          .replacementOptions(incoming, s.squadForTeam('Lions')[1].id);
      expect(options.contains(s.squadForTeam('Lions')[0].id), isTrue);

      final s2 = _fixture();
      s2.substituteBatter(
          atStrikerEnd: true,
          newcomerId: s2.squadForTeam('Lions')[2].id,
          retireAs: DismissalType.retiredOut);
      expect(s2.innings!.wickets, wicketsBefore + 1,
          reason: 'retired out falls a team wicket');
      expect(
          s2.currentSheet!.batting[s2.squadForTeam('Lions')[0].id]!.dismissal,
          DismissalType.retiredOut);
    });

    test('one undo puts both men back', () async {
      final s = _fixture();
      final incoming = s.squadForTeam('Lions')[2].id;
      s.substituteBatter(atStrikerEnd: true, newcomerId: incoming);
      expect(s.currentSheet!.strikerId, incoming);
      expect(s.lastChange, isNotNull,
          reason: 'the players sheet shows what changed');

      await s.undo();
      // Undo rebuilds the sheet from the snapshot, so the state is read fresh.
      final back = s.currentSheet!;
      expect(back.strikerId, s.squadForTeam('Lions')[0].id,
          reason: 'the striker is back');
      expect(back.nonStrikerId, s.squadForTeam('Lions')[1].id);
      expect(s.lastChange, isNull,
          reason: 'the undo banner goes with the change it described');
    });

    test('a change is refused while the next bowler is still owed', () {
      final s = _fixture();
      for (var i = 0; i < 6; i++) {
        s.score(action: 'DOT');
      }
      expect(s.currentSheet!.needsNewBowler, isTrue);
      final incoming = s.squadForTeam('Lions')[2].id;
      expect(s.substituteBatter(atStrikerEnd: true, newcomerId: incoming),
          isNotNull);
    });
  });

  group('innings-start selection', () {
    testWidgets('a pick can be taken back and changed without leaving',
        (tester) async {
      final s = _fixture();
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showInningsStartSheet(context, s),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Pick the striker.
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      // A5 is listed by the striker group AND by the still-open non-striker
      // group; once the striker group collapses to its pick, only the
      // non-striker group lists him.
      expect(find.text('A5'), findsNWidgets(1),
          reason: 'the striker group collapses to the pick');
      expect(find.text('A1'), findsNWidgets(2),
          reason: 'the pick is shown, and still listed by the other group');

      // Tap the chosen row: the list must come BACK. It used to promise
      // "Tap to change" and nothing reopened it.
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      expect(find.text('A5'), findsNWidgets(2),
          reason: 'the list reopens so another name can be chosen');

      // Tap the selected name again: it is un-picked.
      await tester.tap(find.text('A1').first);
      await tester.pumpAndSettle();
      expect(find.text('A5'), findsNWidgets(2),
          reason: 'the list stays open after an un-pick');
      expect(find.text('PICK ALL THREE'), findsOneWidget,
          reason: 'START is locked until all three are chosen');
    });
  });
}
