import 'dart:convert';

import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/domain/room_snapshot.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/store.dart';
import 'package:cricket_scoring/theme.dart';
import 'package:cricket_scoring/screens/viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The viewer is a read-only screen. These tests pin that down: it renders a
/// score, it refuses to go backwards, and it exposes no way to score.
/// The runs numeral currently on the hero tile.
String? _runs(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.descendant(
          of: find.byKey(const ValueKey('hero-runs')),
          matching: find.byType(Text)))
      .map((t) => t.data)
      .toList();
  return texts.isEmpty ? null : texts.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MatchStore liveStore(FakeSync sync) {
    final s = MatchStore(sync: sync);
    s.startMatch(
        MatchConfig(teamA: 'A', teamB: 'B', totalOvers: 5, playersPerSide: 5));
    return s;
  }

  Map<String, dynamic> snapOf(MatchStore s) => s.match!.toJson();

  testWidgets('a viewer sees the score and no keypad',
      (WidgetTester tester) async {
    final fake = FakeSync();
    final store = liveStore(fake);
    store.score(action: 'RUNS', runs: 4);

    await tester.pumpWidget(MaterialApp(
      theme: UmpireTheme.light(),
      home: ViewerScreen(store: store, code: 'ABCDE'),
    ));
    fake.emit(
        RoomSnapshot(seq: 1, match: snapOf(store), updatedAt: DateTime.now()));
    await tester.pumpAndSettle();

    // The score is on screen (runs and wickets are separate widgets).
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('hero-runs')),
            matching: find.text('4')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('hero-wickets')),
            matching: find.text('0')),
        findsOneWidget);
    // And there is no way to change it from here.
    expect(find.byType(EditableText), findsNothing);
    expect(find.textContaining('WICKET'), findsNothing);
    expect(find.textContaining('UNDO'), findsNothing);
    expect(find.textContaining('Room ABCDE'), findsWidgets);
  });

  testWidgets('a viewer ignores a stale snapshot', (WidgetTester tester) async {
    final fake = FakeSync();
    final store = liveStore(fake);
    store.score(action: 'RUNS', runs: 4);

    await tester.pumpWidget(MaterialApp(
      theme: UmpireTheme.light(),
      home: ViewerScreen(store: store, code: 'ABCDE'),
    ));
    fake.emit(
        RoomSnapshot(seq: 5, match: snapOf(store), updatedAt: DateTime.now()));
    await tester.pumpAndSettle();
    expect(_runs(tester), '4');

    // A late duplicate from a reconnect must not walk the score backwards.
    store.score(action: 'RUNS', runs: 6);
    fake.emit(
        RoomSnapshot(seq: 2, match: snapOf(store), updatedAt: DateTime.now()));
    await tester.pumpAndSettle();
    // The late seq 2 was IGNORED, so the score must still read 4 - not 10.
    expect(_runs(tester), '4');
  });

  testWidgets('a viewer applies a newer snapshot', (WidgetTester tester) async {
    final fake = FakeSync();
    final store = liveStore(fake);
    store.score(action: 'RUNS', runs: 4);

    await tester.pumpWidget(MaterialApp(
      theme: UmpireTheme.light(),
      home: ViewerScreen(store: store, code: 'ABCDE'),
    ));
    fake.emit(
        RoomSnapshot(seq: 1, match: snapOf(store), updatedAt: DateTime.now()));
    await tester.pumpAndSettle();
    expect(_runs(tester), '4');

    store.score(action: 'SIX');
    fake.emit(
        RoomSnapshot(seq: 2, match: snapOf(store), updatedAt: DateTime.now()));
    await tester.pumpAndSettle();
    expect(_runs(tester), '10');
  });

  testWidgets('a viewer watches the room it was given',
      (WidgetTester tester) async {
    final fake = FakeSync();
    final store = liveStore(fake);
    await tester.pumpWidget(MaterialApp(
      theme: UmpireTheme.light(),
      home: ViewerScreen(store: store, code: 'K7M2P'),
    ));
    await tester.pumpAndSettle();
    expect(fake.watched, ['K7M2P']);
  });

  testWidgets('join screen normalises a lower-case code',
      (WidgetTester tester) async {
    final fake = FakeSync();
    final store = liveStore(fake);
    await tester.pumpWidget(MaterialApp(
      theme: UmpireTheme.light(),
      home: JoinRoomScreen(store: store),
    ));

    await tester.enterText(find.byType(TextField), 'k7m2p');
    await tester.tap(find.text('WATCH'));
    await tester.pumpAndSettle();

    // Upper-cased and normalised: the same room either way.
    expect(find.textContaining('K7M2P'), findsWidgets);
  });

  testWidgets('join screen refuses a malformed code',
      (WidgetTester tester) async {
    final fake = FakeSync();
    final store = liveStore(fake);
    await tester.pumpWidget(MaterialApp(
      theme: UmpireTheme.light(),
      home: JoinRoomScreen(store: store),
    ));

    await tester.enterText(find.byType(TextField), 'AB0DE');
    await tester.tap(find.text('WATCH'));
    await tester.pumpAndSettle();

    expect(fake.watched, isEmpty);
    expect(find.textContaining('Codes are 5 letters'), findsWidgets);
  });

  testWidgets('a viewer survives a payload it cannot parse',
      (WidgetTester tester) async {
    final fake = FakeSync();
    final store = liveStore(fake);
    await tester.pumpWidget(MaterialApp(
      theme: UmpireTheme.light(),
      home: ViewerScreen(store: store, code: 'ABCDE'),
    ));
    fake.emit(RoomSnapshot(
      seq: 1,
      match: <String, dynamic>{'not': 'a match'},
      updatedAt: DateTime.now(),
    ));
    await tester.pumpAndSettle();
    // Whatever it decided to render, the viewer survived: no crash, no throw.
    expect(find.byType(ViewerScreen), findsOneWidget);
  });

  test('a snapshot of a real match decodes to the same score', () {
    final fake = FakeSync();
    final store = liveStore(fake);
    store.score(action: 'FOUR');
    store.score(action: 'WICKET', wicketType: 'Bowled');
    final payload =
        fake.published.isEmpty ? store.match!.toJson() : store.match!.toJson();
    final round = Match.decode(jsonEncode(payload));
    expect(round.innings1.runs, 4);
    expect(round.innings1.wickets, 1);
    expect(round.innings1.currentOverBalls.length, 2);
  });
}
