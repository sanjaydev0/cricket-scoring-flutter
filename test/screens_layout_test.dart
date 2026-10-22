import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/player_sheets.dart';
import 'package:cricket_scoring/screens/scorecard.dart';
import 'package:cricket_scoring/screens/setup.dart';
import 'package:cricket_scoring/store.dart';

/// The new screens must survive a narrow phone. A RenderFlex overflow is an
/// exception in a widget test, so these fail loudly instead of shipping a
/// screen with clipped rows.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  MatchStore fixture() {
    final s = MatchStore(sync: FakeSync());
    s.hapticsOn = false;
    s.createClub(name: 'Gully Kings');
    final a = [for (var i = 1; i <= 6; i++) s.addPlayer(name: 'Player $i')!.id];
    final b = [for (var i = 1; i <= 6; i++) s.addPlayer(name: 'Batter $i')!.id];
    s.draft = MatchConfig(
        teamA: 'BLUE',
        teamB: 'RED',
        totalOvers: 3,
        playersPerSide: 6,
        trackPlayers: true,
        squadA: a,
        squadB: b);
    s.startMatch(s.draft);
    s.setOpeners(a[0], a[1]);
    s.setBowler(b[0]);
    return s;
  }

  Future<void> phone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  /// Scrolls the setup list until [finder] is on screen.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first);
  }

  testWidgets('the setup screen fits a phone with both squads', (tester) async {
    final s = fixture();
    await phone(tester, SetupScreen(s));
    // Turn tracking on so the squad rows are on screen.
    await scrollTo(tester, find.text('Track players + stats'));
    await tester.tap(find.text('Track players + stats'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('+ ADD PLAYER'));
    expect(find.text('+ ADD PLAYER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the team rows switch which squad is open', (tester) async {
    final s = fixture();
    await phone(tester, SetupScreen(s));
    await scrollTo(tester, find.text('Track players + stats'));
    await tester.tap(find.text('Track players + stats'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('+ ADD PLAYER'));
    // Team A is open by default: its players are listed.
    expect(find.textContaining('Player 1'), findsWidgets);
    // Opening Team B swaps the list over.
    await tester.ensureVisible(find.text('RED'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RED'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Batter 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the players sheet fits and shows the crease', (tester) async {
    final s = fixture();
    await phone(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPlayerStatsSheet(context, s),
                child: const Text('open'),
              ),
            ),
          ),
        ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Player 1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scorecard fits and lists both sides', (tester) async {
    final s = fixture();
    s.score(action: 'FOUR');
    await phone(tester, ScorecardScreen(store: s, inningsNo: 1));
    expect(find.text('BOWLING'), findsWidgets);
    expect(find.text('RUNS (BALLS)'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
