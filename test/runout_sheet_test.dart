import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/screens/player_sheets.dart';
import 'package:cricket_scoring/store.dart';

/// The run-out record: what the umpire is asked, and what gets written down.
///
/// Two faults lived here and both are pinned below. The wicket grid passed the
/// literal `'Run Out'`, which matched neither the enum `runOut` nor its label
/// `Run out`, so `DismissalType.fromId` answered `bowled` and an untracked
/// run-out was printed on the card as `b <bowler>`. And the untracked sheet was
/// a plain Column in a modal capped at 9/16 of the screen, which measured
/// 329 px of overflow on a 1080x1920 phone — question 3 and the confirm button
/// sat below the bottom edge with no way to scroll to them.

MatchStore _fixture({bool tracked = true, bool askFielder = false}) {
  final s = MatchStore(sync: FakeSync());
  s.hapticsOn = false;
  s.createClub(name: 'Gully Kings');
  final a = [for (var i = 1; i <= 5; i++) s.addPlayer(name: 'A$i')!.id];
  final b = [for (var i = 1; i <= 5; i++) s.addPlayer(name: 'B$i')!.id];
  s.draft = MatchConfig(
      teamA: 'Lions',
      teamB: 'Tigers',
      totalOvers: 2,
      playersPerSide: 5,
      trackPlayers: tracked,
      squadA: tracked ? a : const [],
      squadB: tracked ? b : const []);
  s.startMatch(s.draft);
  if (tracked) {
    s.setOpeners(a[0], a[1]);
    s.setBowler(b[0]);
  }
  s.askFielder = askFielder;
  return s;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('dismissal ids', () {
    test('every literal the UI has ever passed resolves to the right type', () {
      // These two are the ones that were silently becoming bowled.
      expect(DismissalType.tryFromId('Run Out'), DismissalType.runOut);
      expect(DismissalType.tryFromId('Hit Wicket'), DismissalType.hitWicket);
      // The canonical forms keep working, as do the sloppy ones.
      expect(DismissalType.tryFromId('runOut'), DismissalType.runOut);
      expect(DismissalType.tryFromId('Run out'), DismissalType.runOut);
      expect(DismissalType.tryFromId('run  out'), DismissalType.runOut);
      expect(DismissalType.tryFromId('Hit wicket'), DismissalType.hitWicket);
      expect(DismissalType.tryFromId('BOWLED'), DismissalType.bowled);
      expect(DismissalType.tryFromId('LBW'), DismissalType.lbw);
      expect(DismissalType.tryFromId('Stumped'), DismissalType.stumped);
      expect(DismissalType.tryFromId('Caught'), DismissalType.caught);
      // Anything unknown is reported as unknown rather than guessed at.
      expect(DismissalType.tryFromId('wibble'), isNull);
      expect(DismissalType.tryFromId(''), isNull);
    });

    test('badges are the W+n the strip shows', () {
      expect(wicketBadge(0), 'W');
      expect(wicketBadge(1), 'W+1');
      expect(wicketBadge(2), 'W+2');
      expect(wicketBadge(3), 'W+3');
    });

    test('a run-out is stored as a run-out in either spelling', () {
      for (final spelling in ['Run out', 'Run Out']) {
        final s = _fixture(tracked: false);
        expect(s.score(action: 'WICKET', runs: 2, wicketType: spelling), isNull,
            reason: spelling);
        final ball = s.innings!.overs.last.balls.last;
        expect(ball.badge, 'W+2', reason: spelling);
        // Stored canonically, so a re-read resolves without the fallback.
        expect(ball.wicketType, DismissalType.runOut.label, reason: spelling);
        final type = DismissalType.tryFromId(ball.wicketType);
        expect(type, DismissalType.runOut, reason: spelling);
        // A run-out is nobody's wicket, and the card must not say `b`.
        expect(type!.creditsBowler, isFalse, reason: spelling);
        expect(type.text(fielder: 'B1'), 'run out (B1)', reason: spelling);
        expect(type.text(), 'run out', reason: spelling);
      }
    });

    test('a hit wicket is stored as a hit wicket', () {
      final s = _fixture(tracked: false);
      expect(s.score(action: 'WICKET', wicketType: 'Hit Wicket'), isNull);
      final ball = s.innings!.overs.last.balls.last;
      expect(DismissalType.tryFromId(ball.wicketType), DismissalType.hitWicket);
      expect(ball.badge, 'W');
    });

    test('the card tells a run-out from a bowled', () {
      // The reported fault: both read the same. A run-out that lands as bowled
      // prints `b <bowler>` on the card, which is indistinguishable from a
      // genuine bowled dismissal.
      final s = _fixture();
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);

      s.score(
          action: 'WICKET',
          wicketType: DismissalType.bowled.label,
          dismissal: DismissalType.bowled.name);
      final bowled = s.currentSheet!.batting[a[0]]!;
      expect(bowled.dismissal, DismissalType.bowled);
      final bowledText = bowled.dismissal!.text(bowler: bowled.bowlerName);
      expect(bowledText, startsWith('b'));

      // Two runs, then the non-striker is short at the bowler's end.
      s.score(
          action: 'WICKET',
          runs: 2,
          wicketType: DismissalType.runOut.label,
          dismissal: DismissalType.runOut.name,
          outAtNonStrikerEnd: true,
          outAtStrikerEnd: false);
      final runOut = s.currentSheet!.batting[a[1]]!;
      expect(runOut.dismissal, DismissalType.runOut);
      final runOutText = runOut.dismissal!
          .text(fielder: runOut.dismissedByName, bowler: runOut.bowlerName);
      expect(runOutText, 'run out');
      expect(runOutText, isNot(bowledText),
          reason: 'a run-out must not read like a bowled');
      expect(s.innings!.runs, 2, reason: 'the two runs still count');
      expect(s.innings!.wickets, 2);
    });

    test('with nobody left to bat the vacated end is emptied', () {
      final s = _fixture();
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(s.squadForTeam('Tigers').first.id);
      final sheet = s.currentSheet!;

      // The striker is out at the striker's end and there is no newcomer. The
      // end must be vacated, not left pointing at a man who is already out.
      sheet.seatAfterDismissal(
          dismissedId: a[0], atStrikerEnd: true, newcomerId: null);
      expect(sheet.strikerId, isNull);
      expect(sheet.nonStrikerId, a[1]);

      // And the same at the bowler's end.
      sheet.seatAfterDismissal(
          dismissedId: a[1], atStrikerEnd: false, newcomerId: null);
      expect(sheet.nonStrikerId, isNull);
    });
  });

  testWidgets('every question is on screen and the confirm button is reachable',
      (tester) async {
    // The phone's real surface: 1080x1920 at 2.625 → 411 x 731 logical.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final s = _fixture();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => showRunOutSheet(ctx, s),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The old capped, non-scrollable sheet threw a RenderFlex overflow here.
    expect(tester.takeException(), isNull,
        reason: 'the sheet must not overflow the modal');

    expect(find.text('1. RUNS COMPLETED'), findsOneWidget);
    expect(find.text('2. WHO WAS DISMISSED?'), findsOneWidget);
    expect(find.text('3. WHICH END WAS HE OUT AT?'), findsOneWidget);

    // The four run options are labelled with the badge, not a bare number.
    for (final badge in ['W', 'W+1', 'W+2', 'W+3']) {
      expect(find.text(badge), findsOneWidget, reason: '$badge is an option');
    }

    // Reachable means inside the screen: the old button measured 1007..1021
    // against a 731-tall screen.
    final confirm = find.text('W · A1 OUT');
    expect(confirm, findsOneWidget);
    final rect = tester.getRect(confirm);
    expect(rect.bottom, lessThanOrEqualTo(731.0),
        reason: 'the confirm button must be on screen without scrolling');
  });

  testWidgets('the answers reach the store as the ball that was described',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final s = _fixture();
    final a = s.squadForTeam('Lions').map((p) => p.id).toList();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => showRunOutSheet(ctx, s),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // W+2 · the non-striker · dismissed at the bowler's end. The striker ran
    // two, so he stays on strike and the newcomer fills the far end.
    await tester.tap(find.text('W+2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Bowler's end"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('W+2 · A2 OUT'));
    await tester.pumpAndSettle();

    final ball = s.innings!.overs.last.balls.last;
    expect(ball.badge, 'W+2');
    expect(ball.runs, 2);
    expect(DismissalType.tryFromId(ball.wicketType), DismissalType.runOut);
    expect(s.innings!.wickets, 1);

    final sheet = s.currentSheet!;
    expect(sheet.batting[a[1]]!.isNotOut, isFalse, reason: 'A2 is out');
    expect(sheet.strikerId, a[0], reason: 'A1 stays on strike');
    expect(sheet.nonStrikerId, isNot(a[1]),
        reason: 'the dismissed man is on neither end');
    expect(sheet.nonStrikerId, isNot(a[0]));
  });

  testWidgets('an untracked match is asked the same three questions',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final s = _fixture(tracked: false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => showRunOutSheet(ctx, s),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1. RUNS COMPLETED'), findsOneWidget);
    expect(find.text('2. WHO WAS DISMISSED?'), findsOneWidget);
    expect(find.text('3. WHICH END WAS HE OUT AT?'), findsOneWidget);
    // No XI to name, so the rows describe the ends rather than guess names.
    expect(find.text('Striker — facing the bowler'), findsOneWidget);
    expect(find.text('Non-striker — the other end'), findsOneWidget);

    await tester.tap(find.text('W+1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non-striker — the other end'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Bowler's end"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('W+1 · Non-striker OUT'));
    await tester.pumpAndSettle();

    final ball = s.innings!.overs.last.balls.last;
    expect(ball.badge, 'W+1');
    expect(ball.runs, 1);
    // The bug this pins: it used to land as bowled.
    expect(DismissalType.tryFromId(ball.wicketType), DismissalType.runOut);
    expect(s.innings!.runs, 1);
  });
}
