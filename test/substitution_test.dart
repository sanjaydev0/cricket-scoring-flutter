import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/player_sheets.dart';
import 'package:cricket_scoring/screens/widgets.dart';
import 'package:cricket_scoring/store.dart';

/// Mid-over batter changes, and the setup defaults that came with them.
///
/// A substitution is not a wicket and not a run: the newcomer stands where the
/// departing man stood, nobody moves ends, and one undo puts both men back.
/// The two failure modes these tests exist for: the newcomer landing at the
/// WRONG end (the striker's end swallowed the non-striker's replacement), and
/// a change that could not be undone in one tap.

MatchStore _fixture({int players = 5, bool openers = true}) {
  final s = MatchStore();
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
    squadB: b,
  );
  s.startMatch(s.draft);
  if (openers) {
    s.setOpeners(a[0], a[1]);
    s.setBowler(b[0]);
  }
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
      final old = MatchConfig.fromJson(<String, dynamic>{
        'teamA': 'EAGLES XI',
        'teamB': 'TITANS',
      });
      expect(old.teamA, 'EAGLES XI');
      expect(old.teamB, 'TITANS');
    });

    test('the striker is replaced by a man who faces the next ball', () {
      final s = _fixture();
      final sheet = s.currentSheet!;
      final incoming = s.squadForTeam('Lions')[2].id;
      expect(sheet.strikerId, s.squadForTeam('Lions')[0].id);

      expect(
        s.substituteBatter(atStrikerEnd: true, newcomerId: incoming),
        isNull,
      );

      expect(sheet.strikerId, incoming, reason: 'the newcomer takes his end');
      expect(
        sheet.nonStrikerId,
        s.squadForTeam('Lions')[1].id,
        reason: 'the other end does not move',
      );
      // The ball after the change belongs to the newcomer.
      s.score(action: 'RUNS', runs: 1);
      expect(
        sheet.batting[incoming]!.runs,
        1,
        reason: 'the newcomer faced the ball',
      );
      expect(sheet.batting[incoming]!.balls, 1);
    });

    test('the non-striker is replaced and the striker keeps his strike', () {
      final s = _fixture();
      final sheet = s.currentSheet!;
      final incoming = s.squadForTeam('Lions')[2].id;
      final striker = s.squadForTeam('Lions')[0].id;

      expect(
        s.substituteBatter(atStrikerEnd: false, newcomerId: incoming),
        isNull,
      );

      expect(sheet.nonStrikerId, incoming);
      expect(sheet.strikerId, striker, reason: 'the striker keeps his end');
      s.score(action: 'DOT');
      expect(
        sheet.striker!.playerId,
        striker,
        reason: 'and he is still the one facing',
      );
    });

    test('the man at the other end cannot be the replacement', () {
      final s = _fixture();
      final sheet = s.currentSheet!;
      final striker = s.squadForTeam('Lions')[0].id;
      final options = sheet.replacementOptions(
        s.squadForTeam('Lions')[1].id,
        striker,
      );
      expect(options.contains(striker), isFalse);
      expect(options.contains(s.squadForTeam('Lions')[1].id), isFalse);
      expect(options.contains(s.squadForTeam('Lions')[2].id), isTrue);
      // And the store refuses it, not just the picker.
      expect(
        s.substituteBatter(atStrikerEnd: false, newcomerId: striker),
        isNotNull,
      );
    });

    test('retired hurt is not a wicket, retired out is', () {
      final s = _fixture();
      final incoming = s.squadForTeam('Lions')[2].id;
      final wicketsBefore = s.innings!.wickets;

      s.substituteBatter(atStrikerEnd: true, newcomerId: incoming);
      expect(
        s.innings!.wickets,
        wicketsBefore,
        reason: 'a substitution is not a dismissal',
      );
      expect(
        s.currentSheet!.batting[s.squadForTeam('Lions')[0].id]!.dismissal,
        DismissalType.retiredHurt,
      );

      // A retired-hurt man may come back later; a retired-out man may not.
      final options = s.currentSheet!.replacementOptions(
        incoming,
        s.squadForTeam('Lions')[1].id,
      );
      expect(options.contains(s.squadForTeam('Lions')[0].id), isTrue);

      final s2 = _fixture();
      s2.substituteBatter(
        atStrikerEnd: true,
        newcomerId: s2.squadForTeam('Lions')[2].id,
        retireAs: DismissalType.retiredOut,
      );
      expect(
        s2.innings!.wickets,
        wicketsBefore + 1,
        reason: 'retired out falls a team wicket',
      );
      expect(
        s2.currentSheet!.batting[s2.squadForTeam('Lions')[0].id]!.dismissal,
        DismissalType.retiredOut,
      );
    });

    test('one undo puts both men back', () async {
      final s = _fixture();
      final incoming = s.squadForTeam('Lions')[2].id;
      s.substituteBatter(atStrikerEnd: true, newcomerId: incoming);
      expect(s.currentSheet!.strikerId, incoming);
      expect(
        s.lastChange,
        isNotNull,
        reason: 'the players sheet shows what changed',
      );

      await s.undo();
      // Undo rebuilds the sheet from the snapshot, so the state is read fresh.
      final back = s.currentSheet!;
      expect(
        back.strikerId,
        s.squadForTeam('Lions')[0].id,
        reason: 'the striker is back',
      );
      expect(back.nonStrikerId, s.squadForTeam('Lions')[1].id);
      expect(
        s.lastChange,
        isNull,
        reason: 'the undo banner goes with the change it described',
      );
    });

    test('a change is refused while the next bowler is still owed', () {
      final s = _fixture();
      for (var i = 0; i < 6; i++) {
        s.score(action: 'DOT');
      }
      expect(s.currentSheet!.needsNewBowler, isTrue);
      final incoming = s.squadForTeam('Lions')[2].id;
      expect(
        s.substituteBatter(atStrikerEnd: true, newcomerId: incoming),
        isNotNull,
      );
    });
  });

  group('innings-start selection', () {
    Future<void> openSheet(WidgetTester tester, MatchStore s) async {
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a picked name leaves the pool instead of being locked', (
      tester,
    ) async {
      final s = _fixture(openers: false);
      await openSheet(tester, s);
      expect(find.byType(PlayerRow), findsNWidgets(5));

      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();

      // A1 is in the striker slot and nowhere else: not in the list, not as a
      // greyed-out "already the striker" row, not in the non-striker pool.
      expect(find.text('A1'), findsOneWidget);
      expect(find.byType(PlayerRow), findsNWidgets(4));
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('a pick advances to the next empty answer', (tester) async {
      final s = _fixture(openers: false);
      await openSheet(tester, s);

      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();
      // The pool is now the non-striker pool: A2 fills that slot.
      await tester.tap(find.text('A2'));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      // The pair is in, so the pool has already switched to the bowling XI:
      // no Lion is listed any more, not even as a locked row.
      expect(find.byType(PlayerRow), findsNWidgets(5));
      expect(find.text('A3'), findsNothing);

      // Third pick fills the bowler slot; the pool keeps the bowling XI and
      // drops the man now in it.
      expect(find.text('B1'), findsOneWidget);
      await tester.tap(find.text('B1'));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.byType(PlayerRow), findsNWidgets(4));
      expect(find.text('B1'), findsOneWidget, reason: 'in the bowler slot');
      expect(find.text('START INNINGS'), findsOneWidget);
      expect(find.text('PICK ALL THREE'), findsNothing);
    });

    testWidgets('tapping a filled slot takes the answer back', (tester) async {
      final s = _fixture(openers: false);
      await openSheet(tester, s);
      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);

      await tester.tap(find.text('STRIKER'));
      await tester.pumpAndSettle();

      expect(find.text('0/3'), findsOneWidget);
      expect(find.text('A1'), findsOneWidget, reason: 'back in the pool');
      expect(find.byType(PlayerRow), findsNWidgets(5));
    });

    testWidgets('CLEAR ALL empties all three answers', (tester) async {
      final s = _fixture();
      await openSheet(tester, s);
      expect(find.text('3/3'), findsOneWidget);

      await tester.tap(find.text('CLEAR ALL'));
      await tester.pumpAndSettle();

      expect(find.text('0/3'), findsOneWidget);
      expect(find.text('PICK ALL THREE'), findsOneWidget);
      expect(find.byType(PlayerRow), findsNWidgets(5));
    });

    testWidgets('START commits all three in one store call', (tester) async {
      final s = _fixture(openers: false);
      await openSheet(tester, s);
      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START INNINGS'));
      await tester.pumpAndSettle();

      final sheet = s.currentSheet!;
      expect(sheet.strikerId, s.squadForTeam('Lions')[0].id);
      expect(sheet.nonStrikerId, s.squadForTeam('Lions')[1].id);
      expect(sheet.bowlerId, s.squadForTeam('Tigers')[0].id);
      expect(find.text('START INNINGS'), findsNothing, reason: 'sheet closed');
    });
  });

  group('innings-start commit', () {
    test('one snapshot covers the pair and the bowler', () {
      final s = _fixture(openers: false);
      final a = s.squadForTeam('Lions');
      final b = s.squadForTeam('Tigers');
      expect(
        s.startInnings(striker: a[0].id, nonStriker: a[1].id, bowler: b[0].id),
        isNull,
      );
      expect(s.currentSheet!.bowlerId, b[0].id);

      s.undo();

      expect(s.currentSheet!.strikerId, isNull);
      expect(s.currentSheet!.nonStrikerId, isNull);
      expect(
        s.currentSheet!.bowlerId,
        isNull,
        reason: 'one undo puts all three back, not just the bowler',
      );
    });

    test('the same man cannot hold both ends', () {
      final s = _fixture(openers: false);
      final a = s.squadForTeam('Lions');
      final b = s.squadForTeam('Tigers');
      expect(
        s.startInnings(striker: a[0].id, nonStriker: a[0].id, bowler: b[0].id),
        isNotNull,
      );
    });

    test('the pair is refused once a ball has been bowled', () {
      final s = _fixture();
      final a = s.squadForTeam('Lions');
      s.score(action: 'DOT');
      expect(
        s.startInnings(
          striker: a[2].id,
          nonStriker: a[3].id,
          bowler: s.squadForTeam('Tigers')[0].id,
        ),
        isNotNull,
      );
    });

    test('re-picking an opener before ball one leaves no ghost card', () {
      final s = _fixture();
      final a = s.squadForTeam('Lions');
      final b = s.squadForTeam('Tigers');
      expect(s.currentSheet!.strikerId, a[0].id);

      expect(
        s.startInnings(striker: a[2].id, nonStriker: a[3].id, bowler: b[0].id),
        isNull,
      );

      final sheet = s.currentSheet!;
      expect(sheet.strikerId, a[2].id);
      expect(sheet.nonStrikerId, a[3].id);
      // The replaced pair never batted, so they must not appear as
      // "not out 0 (0)" on the scorecard.
      expect(sheet.battingCards.length, 2);
      expect(sheet.batting[a[0].id]!.position, 0);
      expect(sheet.batting[a[1].id]!.position, 0);
      expect(sheet.batting[a[2].id]!.position, 1);
      expect(sheet.batting[a[3].id]!.position, 2);
    });
  });
}
