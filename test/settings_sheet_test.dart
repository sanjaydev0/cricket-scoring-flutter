import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/sheets.dart';
import 'package:cricket_scoring/store.dart';

/// The mid-match config sheet is the one screen an umpire opens with a match
/// already running, so it has to be readable on a phone, honest about unsaved
/// rule edits, and explicit about the two irreversible actions at the bottom.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  /// Two four-man XIs with room to grow, plus two players parked on the bench.
  MatchStore fixture() {
    final s = MatchStore();
    s.hapticsOn = false;
    s.createClub(name: 'Gully Kings');
    final a = [for (var i = 1; i <= 4; i++) s.addPlayer(name: 'Blue $i')!.id];
    final b = [for (var i = 1; i <= 4; i++) s.addPlayer(name: 'Red $i')!.id];
    s.addPlayer(name: 'Naveen');
    s.addPlayer(name: 'Murali');
    s.draft = MatchConfig(
      teamA: 'BLUE',
      teamB: 'RED',
      totalOvers: 3,
      playersPerSide: 6,
      trackPlayers: true,
      squadA: a,
      squadB: b,
    );
    s.startMatch(s.draft);
    s.setOpeners(a[0], a[1]);
    s.setBowler(b[0]);
    return s;
  }

  Future<void> openSheet(
    WidgetTester tester,
    MatchStore store, {
    Size size = const Size(1080, 1920),
    double dpr = 2.625,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => showSettingsSheet(ctx, store),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the bento config fits a 411dp phone', (tester) async {
    final s = fixture();
    await openSheet(tester, s);

    expect(tester.takeException(), isNull, reason: 'no overflow');
    expect(find.text('MID-MATCH CONFIG'), findsOneWidget);
    expect(find.text('OVERS'), findsOneWidget);
    expect(find.text('PLAYERS / SIDE'), findsOneWidget);
    // Five rules as chips, each reading its state.
    for (final chip in ['DOUBLE', 'WIDE', 'NO-BALL', 'FREE HIT', 'LAST MAN']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    // Both XIs side by side, each with its count against the pending cap.
    expect(find.text('BLUE'), findsWidgets);
    expect(find.text('RED'), findsWidgets);
    expect(find.text('4/6'), findsNWidgets(2));
    expect(find.text('BENCH / ROSTER'), findsOneWidget);
  });

  testWidgets('the same sheet survives a 320dp screen by stacking', (
    tester,
  ) async {
    final s = fixture();
    await openSheet(
      tester,
      s,
      size: const Size(960, 1920),
      dpr: 3.0,
    );
    expect(tester.takeException(), isNull, reason: 'no overflow at 320dp');
    expect(find.text('OVERS'), findsOneWidget);
    expect(find.text('BENCH / ROSTER'), findsOneWidget);
  });

  testWidgets('a clean exit closes without asking', (tester) async {
    final s = fixture();
    await openSheet(tester, s);
    await reveal(tester, find.text('CANCEL'));
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('SAVE CHANGES?'), findsNothing);
    expect(find.text('MID-MATCH CONFIG'), findsNothing);
  });

  testWidgets('leaving with a changed rule asks, and discard keeps the old', (
    tester,
  ) async {
    final s = fixture();
    await openSheet(tester, s);
    await tester.tap(find.byTooltip('Increase overs'));
    await tester.pumpAndSettle();
    expect(find.text('UNSAVED'), findsOneWidget);

    await reveal(tester, find.text('CANCEL'));
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('SAVE CHANGES?'), findsOneWidget);
    expect(find.text('NO, DISCARD'), findsOneWidget);
    expect(find.text('YES, SAVE'), findsOneWidget);

    await tester.tap(find.text('NO, DISCARD'));
    await tester.pumpAndSettle();
    expect(find.text('MID-MATCH CONFIG'), findsNothing);
    expect(s.match!.config.totalOvers, 3, reason: 'discard changed nothing');
  });

  testWidgets('saving from the prompt applies the pending rule', (
    tester,
  ) async {
    final s = fixture();
    await openSheet(tester, s);
    await tester.tap(find.byTooltip('Increase overs'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('CANCEL'));
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YES, SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('MID-MATCH CONFIG'), findsNothing);
    expect(s.match!.config.totalOvers, 4);
  });

  testWidgets('declare winner confirms with a named yes', (tester) async {
    final s = fixture();
    await openSheet(tester, s);
    await reveal(tester, find.text('DECLARE WINNER'));
    await tester.tap(find.text('BLUE').last);
    await tester.pumpAndSettle();

    expect(find.text('DECLARE BLUE WINNER?'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);
    expect(find.text('YES — BLUE WINS'), findsOneWidget);
    // Saying no leaves the match exactly as it was.
    await tester.tap(find.text('NO'));
    await tester.pumpAndSettle();
    expect(s.match!.completed, isFalse);
    expect(s.match!.winner, isNull);
  });

  testWidgets('abandon warns that nothing is archived', (tester) async {
    final s = fixture();
    await openSheet(tester, s);
    await reveal(tester, find.text('ABANDON MATCH'));
    await tester.tap(find.text('ABANDON MATCH'));
    await tester.pumpAndSettle();

    expect(find.text('ABANDON MATCH?'), findsOneWidget);
    expect(find.textContaining('Nothing is archived'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);
    expect(find.text('YES, ABANDON'), findsOneWidget);
    await tester.tap(find.text('NO'));
    await tester.pumpAndSettle();
    expect(s.match, isNotNull, reason: 'no survived the no');
  });

  testWidgets('one tap assigns a bench player to one XI only', (tester) async {
    final s = fixture();
    await openSheet(tester, s);
    final assign = find.text('+BLUE');
    await reveal(tester, assign.first);
    await tester.tap(assign.first);
    await tester.pumpAndSettle();

    expect(s.match!.config.squadA.length, 5);
    expect(s.match!.config.squadB.length, 4, reason: 'one XI only');
    expect(find.text('5/6'), findsOneWidget);
    expect(find.text('4/6'), findsOneWidget);
  });

  testWidgets('creating mid-match lands on the bench, not in an XI', (
    tester,
  ) async {
    final s = fixture();
    await openSheet(tester, s);
    final create = find.text('＋ NEW');
    await reveal(tester, create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('NEW PLAYER'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Srikanth');
    await tester.tap(find.text('ADD TO BENCH'));
    await tester.pumpAndSettle();

    expect(find.text('NEW PLAYER'), findsNothing);
    expect(s.clubRoster.map((p) => p.name), contains('Srikanth'));
    expect(s.match!.config.squadA.length, 4);
    expect(s.match!.config.squadB.length, 4);
    // And he is now assignable from the pool.
    expect(find.text('+BLUE'), findsWidgets);
  });
}
