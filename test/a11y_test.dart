import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/history.dart';
import 'package:cricket_scoring/screens/scoreboard.dart';
import 'package:cricket_scoring/screens/widgets.dart';
import 'package:cricket_scoring/store.dart';
import 'package:cricket_scoring/theme.dart';

/// The accessibility contract, pinned so a refactor cannot quietly drop it:
/// the score is ONE sentence, icon-only controls are labelled and thumb-sized,
/// and an empty screen explains itself.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  MatchStore fixture() {
    final s = MatchStore(sync: FakeSync());
    s.hapticsOn = false;
    s.createClub(name: 'Gully Kings');
    final a = [for (var i = 1; i <= 3; i++) s.addPlayer(name: 'Player $i')!.id];
    final b = [for (var i = 1; i <= 3; i++) s.addPlayer(name: 'Batter $i')!.id];
    s.draft = MatchConfig(
      teamA: 'BLUE',
      teamB: 'RED',
      totalOvers: 3,
      playersPerSide: 3,
      trackPlayers: true,
      squadA: a,
      squadB: b,
    );
    s.startMatch(s.draft);
    s.setOpeners(a[0], a[1]);
    s.setBowler(b[0]);
    return s;
  }

  testWidgets('the scoreboard speaks one sentence, not three loose numerals', (
    tester,
  ) async {
    final s = fixture();
    s.score(action: 'FOUR');
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Scoreboard(
            match: s.match!,
            innings: s.innings!,
            preset: StylePreset.of('umpire'),
            scoreFamily: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Team, score, overs and rate arrive together, in the order a person
    // would say them.
    final hero = find.bySemanticsLabel(RegExp(r'^BLUE 4 for 0, '));
    expect(hero, findsOneWidget);
    final label = tester.getSemantics(hero).label;
    expect(label, contains('overs of 3'));
    expect(label, contains('run rate'));

    // The bare numerals are gone as standalone announcements.
    expect(find.bySemanticsLabel('4'), findsNothing);
    expect(find.bySemanticsLabel('0'), findsNothing);

    // The over strip is spoken as an over, not as unlabelled badges.
    expect(find.bySemanticsLabel(RegExp(r'^Over \d: 4$')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('stepper buttons are labelled and thumb-sized', (tester) async {
    var value = 6;
    await tester.pumpWidget(
      MaterialApp(
        // The real theme: the 48dp icon floor lives in UmpireTheme, not in the
        // widget, so a bare MaterialApp would not prove anything.
        theme: UmpireTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StepperRow(
              label: 'Overs',
              value: value,
              min: 1,
              max: 50,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Increase Overs'), findsOneWidget);
    expect(find.byTooltip('Decrease Overs'), findsOneWidget);
    for (final tip in ['Increase Overs', 'Decrease Overs']) {
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.width, greaterThanOrEqualTo(44), reason: '$tip width');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$tip height');
    }
  });

  testWidgets('an empty archive explains itself', (tester) async {
    final s = MatchStore(sync: FakeSync());
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(s)));
    await tester.pumpAndSettle();

    expect(find.text('NO SAVED MATCHES'), findsOneWidget);
    expect(find.textContaining('full scorecard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
