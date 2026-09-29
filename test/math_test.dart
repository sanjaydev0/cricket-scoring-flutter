import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scoring/math.dart';

void main() {
  test('ballsToOvers', () {
    expect(CricketMath.ballsToOvers(0), '0.0');
    expect(CricketMath.ballsToOvers(6), '1.0');
    expect(CricketMath.ballsToOvers(17), '2.5');
  });
  test('CRR/RRR', () {
    expect(CricketMath.calcCRR(0, 0), '0.00');
    expect(CricketMath.calcCRR(60, 60), '6.00');
    expect(CricketMath.calcRRR(30, 12), '15.00');
  });
  test('max wickets', () {
    expect(CricketMath.getMaxWickets(11, false), 10);
    expect(CricketMath.getMaxWickets(8, false), 7);
    expect(CricketMath.getMaxWickets(8, true), 8);
  });
}
