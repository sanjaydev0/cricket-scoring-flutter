import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/scoreboard.dart';
import 'package:cricket_scoring/screens/scorecard.dart';
import 'package:cricket_scoring/screens/scoring.dart';
import 'package:cricket_scoring/store.dart';
import 'package:cricket_scoring/theme.dart';

/// The scorecard as a scorecard: both teams' scores on one line, two pills to
/// switch innings, one innings' players at a time, and the chase numbers on
/// demand instead of as permanent chrome.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  /// A tracked match, `overs` overs long, both squads in.
  MatchStore fixture({int overs = 2}) {
    final s = MatchStore(sync: FakeSync());
    s.hapticsOn = false;
    s.createClub(name: 'Gully Kings');
    final a = [for (var i = 1; i <= 5; i++) s.addPlayer(name: 'A$i')!.id];
    final b = [for (var i = 1; i <= 5; i++) s.addPlayer(name: 'B$i')!.id];
    s.draft = MatchConfig(
      teamA: 'BLUE',
      teamB: 'RED',
      totalOvers: overs,
      playersPerSide: 5,
      trackPlayers: true,
      squadA: a,
      squadB: b,
    );
    s.startMatch(s.draft);
    return s;
  }

  Future<void> phone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: UmpireTheme.light(), home: child),
    );
    await tester.pumpAndSettle();
  }

  group('the score tile', () {
    testWidgets('has no progress bar and no permanent target banner', (
      tester,
    ) async {
      final s = fixture();
      s.setOpeners(s.squadForTeam('BLUE')[0].id, s.squadForTeam('BLUE')[1].id);
      s.setBowler(s.squadForTeam('RED')[0].id);
      await phone(
        tester,
        Scoreboard(
          match: s.match!,
          innings: s.innings!,
          preset: StylePreset.of('umpire'),
          scoreFamily: null,
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('TARGET'), findsNothing);
      // The numbers that stay on the tile.
      expect(find.text('OVERS'), findsOneWidget);
      expect(find.text('CRR'), findsOneWidget);
      expect(find.text('EXTRAS'), findsOneWidget);
    });

    testWidgets('tapping it shows the chase numbers, then they go away', (
      tester,
    ) async {
      final s = fixture(overs: 2);
      final blue = s.squadForTeam('BLUE');
      final red = s.squadForTeam('RED');
      s.setOpeners(blue[0].id, blue[1].id);
      s.setBowler(red[0].id);
      // Hand-build the chase: a target, then the second innings under way.
      s.match!.target = 60;
      s.startSecondInnings();
      s.setOpeners(red[0].id, red[1].id);
      s.setBowler(blue[0].id);
      s.score(action: 'RUNS', runs: 1);

      await phone(
        tester,
        Scoreboard(
          match: s.match!,
          innings: s.innings!,
          preset: StylePreset.of('umpire'),
          scoreFamily: null,
        ),
      );
      expect(find.textContaining('TARGET'), findsNothing);

      // Tap the score box.
      await tester.tap(find.byKey(const ValueKey('hero-numerals')));
      await tester.pumpAndSettle();
      expect(find.textContaining('TARGET'), findsOneWidget);
      expect(find.textContaining('NEED'), findsOneWidget);
      expect(find.textContaining('RRR'), findsOneWidget);

      // It leaves again on its own.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('TARGET'), findsNothing);
    });
  });

  group('the scorecard screen', () {
    testWidgets('shows both scores and switches innings with the pills', (
      tester,
    ) async {
      final s = fixture(overs: 2);
      final blue = s.squadForTeam('BLUE');
      final red = s.squadForTeam('RED');
      s.setOpeners(blue[0].id, blue[1].id);
      s.setBowler(red[0].id);
      s.score(action: 'RUNS', runs: 4);
      // The second innings begins (hand-built, so the break countdown that
      // follows a completed innings does not leave a timer running).
      s.match!.target = 60;
      s.startSecondInnings();
      s.setOpeners(red[0].id, red[1].id);
      s.setBowler(blue[0].id);
      s.score(action: 'SIX');

      await phone(tester, ScorecardScreen(store: s, inningsNo: 1));
      // Both teams' scores are on the header.
      expect(find.textContaining('4/0'), findsWidgets);
      expect(find.textContaining('6/0'), findsWidgets);
      // The first innings' batters are on the card.
      expect(find.textContaining('A1'), findsWidgets);

      // Switch to the second innings.
      await tester.tap(find.textContaining('RED').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('B1'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the summary tab lists the top performers of each innings', (
      tester,
    ) async {
      final s = fixture(overs: 2);
      final blue = s.squadForTeam('BLUE');
      final red = s.squadForTeam('RED');
      s.setOpeners(blue[0].id, blue[1].id);
      s.setBowler(red[0].id);
      s.score(action: 'FOUR');
      s.match!.target = 60;
      s.startSecondInnings();
      s.setOpeners(red[0].id, red[1].id);
      s.setBowler(blue[0].id);
      s.score(action: 'SIX');

      await phone(tester, ScorecardScreen(store: s, inningsNo: 1));
      await tester.tap(find.text('SUMMARY'));
      await tester.pumpAndSettle();
      expect(find.text('TOP PERFORMERS'), findsOneWidget);
      expect(find.textContaining('1st Inns'), findsOneWidget);
      expect(find.textContaining('2nd Inns'), findsOneWidget);
      expect(find.textContaining('SR:'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('the scoring screen', () {
    testWidgets('offers the batter picker by itself', (tester) async {
      final s = fixture();
      await phone(tester, ScoringScreen(s));
      // No tap: the picker is already there.
      expect(find.textContaining('START INNINGS'), findsOneWidget);
      expect(find.text('STRIKER — FACING'), findsOneWidget);
      expect(find.text('OPENING BOWLER'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not ask again once the openers are in', (tester) async {
      final s = fixture();
      final blue = s.squadForTeam('BLUE');
      s.setOpeners(blue[0].id, blue[1].id);
      s.setBowler(s.squadForTeam('RED')[0].id);
      await phone(tester, ScoringScreen(s));
      expect(find.textContaining('START INNINGS'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('mid-over change', () {
    test('only the batting side is offered as a replacement', () {
      final s = fixture();
      final blue = s.squadForTeam('BLUE');
      final red = s.squadForTeam('RED');
      s.setOpeners(blue[0].id, blue[1].id);
      s.setBowler(red[0].id);
      final sheet = s.currentSheet!;
      final options = sheet.replacementOptions(blue[0].id, blue[1].id);
      for (final id in options) {
        expect(
          blue.any((p) => p.id == id),
          isTrue,
          reason: 'only the batting XI can come in',
        );
        expect(red.any((p) => p.id == id), isFalse);
      }
      // And the store refuses a fielder even if the UI is bypassed.
      expect(
        s.substituteBatter(atStrikerEnd: true, newcomerId: red[2].id),
        isNotNull,
      );
    });
  });
}
