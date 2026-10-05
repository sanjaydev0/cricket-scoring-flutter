import 'dart:convert';

// --- Models: JSON-serializable, no codegen for speed + offline ---

class Rules {
  int widePenalty;
  int noBallPenalty;
  bool lastManStanding;
  bool freeHit;
  Rules({
    this.widePenalty = 1,
    this.noBallPenalty = 0,
    this.lastManStanding = false,
    this.freeHit = false,
  });
  factory Rules.fromJson(Map<String, dynamic> j) => Rules(
        widePenalty: (j['widePenalty'] ?? 1) as int,
        noBallPenalty: (j['noBallPenalty'] ?? 1) as int,
        lastManStanding: (j['lastManStanding'] ?? false) as bool,
        freeHit: (j['freeHit'] ?? false) as bool,
      );
  Map<String, dynamic> toJson() => {
        'widePenalty': widePenalty,
        'noBallPenalty': noBallPenalty,
        'lastManStanding': lastManStanding,
        'freeHit': freeHit,
      };
}

class MatchConfig {
  String teamA;
  String teamB;
  String battingFirst; // 'A' | 'B'
  int totalOvers;
  int playersPerSide;
  int commonPlayers; // odd-man: plays for both sides
  Rules rules;
  bool trackPlayers; // per-match player stats + scorecard
  List<String> squadA; // player ids for team A (when tracking)
  List<String> squadB; // player ids for team B (when tracking)
  MatchConfig({
    this.teamA = 'EAGLES XI',
    this.teamB = 'TITANS',
    this.battingFirst = 'A',
    this.totalOvers = 6,
    this.playersPerSide = 8,
    this.commonPlayers = 0,
    Rules? rules,
    this.trackPlayers = false,
    List<String>? squadA,
    List<String>? squadB,
  })  : rules = rules ?? Rules(),
        squadA = squadA ?? [],
        squadB = squadB ?? [];
  factory MatchConfig.fromJson(Map<String, dynamic> j) => MatchConfig(
        teamA: (j['teamA'] ?? 'EAGLES XI').toString(),
        teamB: (j['teamB'] ?? 'TITANS').toString(),
        battingFirst: (j['battingFirst'] ?? 'A').toString(),
        totalOvers: (j['totalOvers'] ?? 6) as int,
        playersPerSide: (j['playersPerSide'] ?? 8) as int,
        commonPlayers: (j['commonPlayers'] ?? 0) as int,
        rules: Rules.fromJson((j['rules'] ?? {}) as Map<String, dynamic>),
        trackPlayers: (j['trackPlayers'] ?? false) as bool,
        squadA: ((j['squadA'] ?? []) as List).map((e) => e.toString()).toList(),
        squadB: ((j['squadB'] ?? []) as List).map((e) => e.toString()).toList(),
      );
  Map<String, dynamic> toJson() => {
        'teamA': teamA,
        'teamB': teamB,
        'battingFirst': battingFirst,
        'totalOvers': totalOvers,
        'playersPerSide': playersPerSide,
        'commonPlayers': commonPlayers,
        'rules': rules.toJson(),
        'trackPlayers': trackPlayers,
        'squadA': squadA,
        'squadB': squadB,
      };

  /// e.g. "6 + 6 + 1" or "8 v 8"
  String get sidesLabel => commonPlayers > 0
      ? '$playersPerSide + $playersPerSide + $commonPlayers'
      : '$playersPerSide v $playersPerSide';
}

class Ball {
  int runs; // bat runs
  String extra; // none, WD, NB, B, LB
  int extraRuns;
  bool isLegal;
  bool isWicket;
  String wicketType;
  String badge;
  String? strikerId; // who faced (player tracking only, null for old saves)
  String? nonStrikerId;
  String? bowlerId;
  String? fielderName; // optional catcher / run-out fielder
  Ball({
    this.runs = 0,
    this.extra = 'none',
    this.extraRuns = 0,
    this.isLegal = true,
    this.isWicket = false,
    this.wicketType = '',
    this.badge = '0',
    this.strikerId,
    this.nonStrikerId,
    this.bowlerId,
    this.fielderName,
  });
  factory Ball.fromJson(Map<String, dynamic> j) => Ball(
        runs: (j['runs'] ?? 0) as int,
        extra: (j['extra'] ?? 'none').toString(),
        extraRuns: (j['extraRuns'] ?? 0) as int,
        isLegal: (j['isLegal'] ?? true) as bool,
        isWicket: (j['isWicket'] ?? false) as bool,
        wicketType: (j['wicketType'] ?? '').toString(),
        badge: (j['badge'] ?? '0').toString(),
        strikerId: j['strikerId']?.toString(),
        nonStrikerId: j['nonStrikerId']?.toString(),
        bowlerId: j['bowlerId']?.toString(),
        fielderName: j['fielderName']?.toString(),
      );
  Map<String, dynamic> toJson() => {
        'runs': runs,
        'extra': extra,
        'extraRuns': extraRuns,
        'isLegal': isLegal,
        'isWicket': isWicket,
        'wicketType': wicketType,
        'badge': badge,
        'strikerId': strikerId,
        'nonStrikerId': nonStrikerId,
        'bowlerId': bowlerId,
        'fielderName': fielderName,
      };
  int get totalRuns => runs + extraRuns;
}

class Over {
  int overNumber;
  List<Ball> balls;
  Over({this.overNumber = 1, List<Ball>? balls}) : balls = balls ?? [];
  factory Over.fromJson(Map<String, dynamic> j) => Over(
        overNumber: (j['overNumber'] ?? 1) as int,
        balls: ((j['balls'] ?? []) as List)
            .map((e) => Ball.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
        'overNumber': overNumber,
        'balls': balls.map((b) => b.toJson()).toList()
      };
}

class Innings {
  String battingTeam;
  String bowlingTeam;
  int runs;
  int wickets;
  int legalDeliveries;
  int? target;
  int wides;
  int noBalls;
  int byes;
  int legByes;
  List<Over> overs;
  int currentOverNumber;
  bool isFreeHitActive;
  bool completed;
  Innings({
    required this.battingTeam,
    required this.bowlingTeam,
    this.runs = 0,
    this.wickets = 0,
    this.legalDeliveries = 0,
    this.target,
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    List<Over>? overs,
    this.currentOverNumber = 1,
    this.isFreeHitActive = false,
    this.completed = false,
  }) : overs = overs ?? [Over(overNumber: 1)];
  int get extrasTotal => wides + noBalls + byes + legByes;
  List<Ball> get currentOverBalls {
    if (overs.isEmpty) return const [];
    return overs.last.balls;
  }

  factory Innings.create(String bat, String bowl, [int? target]) =>
      Innings(battingTeam: bat, bowlingTeam: bowl, target: target);

  factory Innings.fromJson(Map<String, dynamic> j) => Innings(
        battingTeam: (j['battingTeam'] ?? '').toString(),
        bowlingTeam: (j['bowlingTeam'] ?? '').toString(),
        runs: (j['runs'] ?? 0) as int,
        wickets: (j['wickets'] ?? 0) as int,
        legalDeliveries: (j['legalDeliveries'] ?? 0) as int,
        target: j['target'] as int?,
        wides: (j['wides'] ?? 0) as int,
        noBalls: (j['noBalls'] ?? 0) as int,
        byes: (j['byes'] ?? 0) as int,
        legByes: (j['legByes'] ?? 0) as int,
        overs: ((j['overs'] ?? []) as List)
            .map((e) => Over.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentOverNumber: (j['currentOverNumber'] ?? 1) as int,
        isFreeHitActive: (j['isFreeHitActive'] ?? false) as bool,
        completed: (j['completed'] ?? false) as bool,
      );
  Map<String, dynamic> toJson() => {
        'battingTeam': battingTeam,
        'bowlingTeam': bowlingTeam,
        'runs': runs,
        'wickets': wickets,
        'legalDeliveries': legalDeliveries,
        'target': target,
        'wides': wides,
        'noBalls': noBalls,
        'byes': byes,
        'legByes': legByes,
        'overs': overs.map((o) => o.toJson()).toList(),
        'currentOverNumber': currentOverNumber,
        'isFreeHitActive': isFreeHitActive,
        'completed': completed,
      };
}

class Match {
  MatchConfig config;
  Innings innings1;
  Innings? innings2;
  int currentInnings;
  int? target;
  bool completed;
  String? winner;
  String? winMargin;
  String? potmId;
  String createdAt;
  Match({
    required this.config,
    required this.innings1,
    this.innings2,
    this.currentInnings = 1,
    this.target,
    this.completed = false,
    this.winner,
    this.winMargin,
    this.potmId,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory Match.fromJson(Map<String, dynamic> j) => Match(
        config:
            MatchConfig.fromJson((j['config'] ?? {}) as Map<String, dynamic>),
        innings1:
            Innings.fromJson((j['innings1'] ?? {}) as Map<String, dynamic>),
        innings2: j['innings2'] == null
            ? null
            : Innings.fromJson(j['innings2'] as Map<String, dynamic>),
        currentInnings: (j['currentInnings'] ?? 1) as int,
        target: j['target'] as int?,
        completed: (j['completed'] ?? false) as bool,
        winner: j['winner']?.toString(),
        winMargin: j['winMargin']?.toString(),
        potmId: j['potmId']?.toString(),
        createdAt: (j['createdAt'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'innings1': innings1.toJson(),
        'innings2': innings2?.toJson(),
        'currentInnings': currentInnings,
        'target': target,
        'completed': completed,
        'winner': winner,
        'winMargin': winMargin,
        'potmId': potmId,
        'createdAt': createdAt,
      };
  String encode() => jsonEncode(toJson());
  static Match decode(String s) =>
      Match.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
