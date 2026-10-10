import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:flutter_test/flutter_test.dart';

InningsSheet trackedSheet() {
  final s = InningsSheet(battingTeam: 'A', bowlingTeam: 'B');
  final a = Player(id: 'a', clubId: 'c', name: 'Rohit Sharma');
  final b = Player(id: 'b', clubId: 'c', name: 'Vikram Singh');
  final c = Player(id: 'c', clubId: 'c', name: 'Deepak Kumar');
  final r =
      Player(id: 'r', clubId: 'c', name: 'Ravi Patel', role: PlayerRole.bowler);
  s.registerSquad([a, b, c, r]);
  s.setOpeners('a', 'b');
  s.setBowler('r');
  return s;
}

Ball legal(int runs) => Ball(runs: runs, badge: '$runs');

void main() {
  test('openers are in and nobody is dismissed', () {
    final s = trackedSheet();
    expect(s.waitingBatters, ['c', 'r']);
    expect(s.striker?.isNotOut, isTrue);
    expect(s.nonStriker?.isNotOut, isTrue);
  });

  test('odd runs rotate strike, even do not', () {
    final s = trackedSheet();
    s.applyDelivery(legal(1));
    expect(s.strikerId, 'b');
    s.applyDelivery(legal(2));
    expect(s.strikerId, 'b');
  });

  test('a four is runs, balls, boundary and strike stays', () {
    final s = trackedSheet();
    s.applyDelivery(Ball(runs: 4, badge: '4'));
    final bat = s.batting['a']!;
    expect(bat.runs, 4);
    expect(bat.balls, 1);
    expect(bat.fours, 1);
    expect(bat.strikeRate, 400.0);
    expect(s.bowling['r']!.runsConceded, 4);
    expect(s.strikerId, 'a');
  });

  test('a wide is never faced and never a batter ball', () {
    final s = trackedSheet();
    s.applyDelivery(
        Ball(runs: 0, extra: 'WD', extraRuns: 1, isLegal: false, badge: 'WD'));
    expect(s.batting['a']!.balls, 0);
    final bowl = s.bowling['r']!;
    expect(bowl.balls, 1);
    expect(bowl.wides, 1);
    expect(bowl.runsConceded, 1);
  });

  test('a no-ball is faced but the penalty is not bat runs', () {
    final s = trackedSheet();
    s.applyDelivery(
        Ball(runs: 2, extra: 'NB', extraRuns: 1, isLegal: false, badge: 'N2'));
    final bat = s.batting['a']!;
    expect(bat.balls, 1);
    expect(bat.runs, 2);
    expect(s.bowling['r']!.runsConceded, 1);
  });

  test('byes are faced but charged to nobody', () {
    final s = trackedSheet();
    s.applyDelivery(
        Ball(runs: 0, extra: 'B', extraRuns: 2, isLegal: true, badge: 'B2'));
    expect(s.batting['a']!.balls, 1);
    expect(s.batting['a']!.runs, 0);
    expect(s.bowling['r']!.runsConceded, 0);
    expect(s.bowling['r']!.balls, 1);
  });

  test('a bowled wicket credits the bowler and brings in the next batter', () {
    final s = trackedSheet();
    s.applyDelivery(Ball(isWicket: true, wicketType: 'Bowled', badge: 'W'),
        dismissalType: DismissalType.bowled);
    expect(s.batting['a']!.isNotOut, isFalse);
    expect(s.bowling['r']!.wickets, 1);
    expect(s.bringIn('c'), isTrue);
    expect(s.strikerId, 'c');
    expect(s.batting['c']!.position, 3);
  });

  test('a run-out credits nobody', () {
    final s = trackedSheet();
    s.applyDelivery(
        Ball(runs: 1, isWicket: true, wicketType: 'Run Out', badge: 'W+1'),
        dismissalType: DismissalType.runOut,
        fielderName: 'Ravi Patel');
    expect(s.bowling['r']!.wickets, 0);
    expect(s.batting['a']!.dismissal, DismissalType.runOut);
    expect(s.fielding['r']!.runOuts, 1);
  });

  test('a catch without a named fielder still renders', () {
    const t = DismissalType.caught;
    expect(t.text(bowler: 'Ravi'), 'c b Ravi');
    expect(DismissalType.runOut.text(), 'run out');
    expect(DismissalType.bowled.text(bowler: 'Ravi'), 'b Ravi');
  });

  test('overs display is cricket notation, never decimal', () {
    final c = BowlingCard(playerId: 'r', name: 'Ravi');
    c.balls = 27;
    expect(c.oversDisplay, '4.3');
  });

  test('undefined stats are null, never zero', () {
    final b = BattingCard(playerId: 'x', name: 'X');
    expect(b.strikeRate, isNull);
    final w = BowlingCard(playerId: 'y', name: 'Y');
    expect(w.average, isNull);
    expect(w.economy, isNull);
    expect(w.strikeRate, isNull);
  });

  test('a bowler cannot bowl two overs in a row', () {
    final s = trackedSheet();
    expect(s.canBowl('r'), isFalse);
    final other = Player(id: 'z', clubId: 'c', name: 'Amit');
    s.register(other);
    expect(s.canBowl('z'), isTrue);
  });

  test('sheets round-trip through JSON', () {
    final s = trackedSheet();
    s.applyDelivery(Ball(runs: 4, badge: '4'));
    final back = InningsSheet.fromJson(s.toJson());
    expect(back.batting['a']!.runs, 4);
    expect(back.strikerId, 'a');
    expect(back.waitingBatters, ['c', 'r']);
  });

  test('career aggregates from cards', () {
    final c = CareerBatting();
    final i1 = BattingCard(playerId: 'a', name: 'A')
      ..position = 1
      ..runs = 30
      ..balls = 20
      ..isNotOut = false;
    final i2 = BattingCard(playerId: 'a', name: 'A')
      ..position = 1
      ..runs = 10
      ..balls = 10
      ..isNotOut = true;
    c.add(i1);
    c.add(i2);
    expect(c.innings, 2);
    expect(c.average,
        40.0); // 40 runs, one dismissal; the not-out innings is excluded
    expect(c.strikeRate, closeTo(133.3, 0.1));
  });

  test('pins hash differently per profile', () {
    expect(hashPin('1234', 'A'), isNot(hashPin('1234', 'B')));
    expect(hashPin('1234', 'A'), hashPin('1234', 'A'));
  });
}
