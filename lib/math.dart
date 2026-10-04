// Pure cricket math - zero dependencies, 100% offline.
class CricketMath {
  static String ballsToOvers(int legalBalls) {
    final o = legalBalls ~/ 6;
    final b = legalBalls % 6;
    return '$o.$b';
  }

  static String calcCRR(int runs, int legalBalls) {
    if (legalBalls == 0) return '0.00';
    return (runs / (legalBalls / 6)).toStringAsFixed(2);
  }

  static String calcRRR(int runsNeeded, int ballsRemaining) {
    if (runsNeeded <= 0) return '0.00';
    if (ballsRemaining <= 0) return '∞';
    return (runsNeeded / (ballsRemaining / 6)).toStringAsFixed(2);
  }

  static int getMaxWickets(int playersPerSide, bool lastManStanding) {
    final p = playersPerSide <= 0 ? 11 : playersPerSide;
    return lastManStanding ? p : (p - 1 < 1 ? 1 : p - 1);
  }

  static int totalBalls(int totalOvers) =>
      (totalOvers <= 0 ? 6 : totalOvers) * 6;
}
