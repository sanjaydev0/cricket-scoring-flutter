import '../models.dart';

/// Club roster + innings attribution. Pure Dart, no Flutter.
///
/// Design rules that matter:
/// - Player ids are stable for life; career figures key on id, never name.
/// - Overs are stored as balls; display converts to cricket notation.
/// - Undefined stats are null (rendered as "—"), never 0.
/// - Everything here serializes, so undo, persistence, rooms and history carry it.

enum PlayerRole { batter, bowler, allRounder, keeper }

PlayerRole roleFromId(String v) => PlayerRole.values.firstWhere(
      (r) => r.name == v,
      orElse: () => PlayerRole.allRounder,
    );

/// Right-hand / left-hand bat.
enum BattingStyle { rightHand, leftHand }

/// Bowling arm + pace. `none` for pure batters.
enum BowlingStyle {
  none,
  rightFast,
  rightMedium,
  leftFast,
  leftMedium,
  rightSpin,
  leftSpin,
}

String battingStyleLabel(BattingStyle s) =>
    s == BattingStyle.rightHand ? 'RHB' : 'LHB';

String bowlingStyleLabel(BowlingStyle s) => switch (s) {
      BowlingStyle.none => '\u2014',
      BowlingStyle.rightFast => 'RAF',
      BowlingStyle.rightMedium => 'RAM',
      BowlingStyle.leftFast => 'LAF',
      BowlingStyle.leftMedium => 'LAM',
      BowlingStyle.rightSpin => 'RAS',
      BowlingStyle.leftSpin => 'LAS',
    };

String bowlingStyleName(BowlingStyle s) => switch (s) {
      BowlingStyle.none => 'Does not bowl',
      BowlingStyle.rightFast => 'Right-arm fast',
      BowlingStyle.rightMedium => 'Right-arm medium',
      BowlingStyle.leftFast => 'Left-arm fast',
      BowlingStyle.leftMedium => 'Left-arm medium',
      BowlingStyle.rightSpin => 'Right-arm spin',
      BowlingStyle.leftSpin => 'Left-arm spin',
    };

BattingStyle battingStyleFromId(String? v) =>
    v == 'leftHand' ? BattingStyle.leftHand : BattingStyle.rightHand;

BowlingStyle bowlingStyleFromId(String? v) => BowlingStyle.values.firstWhere(
      (b) => b.name == v,
      orElse: () => BowlingStyle.none,
    );

class Player {
  final String id;
  final String clubId;
  String name;
  PlayerRole role;
  BattingStyle battingStyle;
  BowlingStyle bowlingStyle;
  String? phone;
  bool active;

  Player({
    required this.id,
    required this.clubId,
    required this.name,
    this.role = PlayerRole.allRounder,
    this.battingStyle = BattingStyle.rightHand,
    this.bowlingStyle = BowlingStyle.none,
    this.phone,
    this.active = true,
  });

  factory Player.create(
      {required String clubId,
      required String name,
      PlayerRole? role,
      BattingStyle? battingStyle,
      BowlingStyle? bowlingStyle}) {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return Player(
        id: 'p_$stamp',
        clubId: clubId,
        name: name,
        role: role ?? PlayerRole.allRounder,
        battingStyle: battingStyle ?? BattingStyle.rightHand,
        bowlingStyle: bowlingStyle ?? BowlingStyle.none);
  }

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: (j['id'] ?? '').toString(),
        clubId: (j['clubId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        role: roleFromId((j['role'] ?? 'allRounder').toString()),
        battingStyle: battingStyleFromId(j['battingStyle']?.toString()),
        bowlingStyle: bowlingStyleFromId(j['bowlingStyle']?.toString()),
        phone: j['phone']?.toString(),
        active: (j['active'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clubId': clubId,
        'name': name,
        'role': role.name,
        'battingStyle': battingStyle.name,
        'bowlingStyle': bowlingStyle.name,
        'phone': phone,
        'active': active,
      };

  String get searchKey =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class Club {
  final String id;
  String name;
  String handle;
  Club({required this.id, required this.name, required this.handle});

  factory Club.create({required String name}) {
    final h = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return Club(id: 'c_$stamp', name: name, handle: h.isEmpty ? 'club' : h);
  }

  factory Club.fromJson(Map<String, dynamic> j) => Club(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        handle: (j['handle'] ?? '').toString(),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'handle': handle};
}

/// Local profile (device-only unlock, not server auth).
class ClubProfile {
  final String id;
  String name;
  String pinHash;
  String? clubId;
  ClubProfile(
      {required this.id,
      required this.name,
      required this.pinHash,
      this.clubId});

  factory ClubProfile.create({required String name, required String pinHash}) {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return ClubProfile(id: 'u_$stamp', name: name, pinHash: pinHash);
  }

  factory ClubProfile.fromJson(Map<String, dynamic> j) => ClubProfile(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        pinHash: (j['pinHash'] ?? '').toString(),
        clubId: j['clubId']?.toString(),
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'pinHash': pinHash, 'clubId': clubId};
}

/// Simple salted hash for a local PIN (obfuscation, not server security).
String hashPin(String pin, String salt) {
  var h = 0x811c9dc5;
  final s = '$salt::$pin';
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

enum DismissalType {
  bowled('Bowled', 'b', creditsBowler: true, hasFielder: false),
  caught('Caught', 'c', creditsBowler: true, hasFielder: true),
  lbw('LBW', 'lbw', creditsBowler: true, hasFielder: false),
  stumped('Stumped', 'st', creditsBowler: true, hasFielder: true),
  hitWicket('Hit wicket', 'hw', creditsBowler: true, hasFielder: false),
  runOut('Run out', '', creditsBowler: false, hasFielder: true),
  obstructing('Obstructing the field', '',
      creditsBowler: false, hasFielder: false),
  retiredHurt('Retired hurt', 'ret hurt',
      creditsBowler: false, hasFielder: false),
  retiredOut('Retired out', 'ret out', creditsBowler: false, hasFielder: false);

  const DismissalType(this.label, this.abbr,
      {required this.creditsBowler, required this.hasFielder});
  final String abbr;
  final String label;
  final bool creditsBowler;
  final bool hasFielder;

  static DismissalType fromId(String v) {
    for (final d in DismissalType.values) {
      if (d.name == v || d.label == v) return d;
    }
    return DismissalType.bowled;
  }

  /// Scorecard dismissal text, e.g. "c Pandey b Ravi", "b Ravi", "run out".
  String text({String? fielder, String? bowler}) {
    switch (this) {
      case DismissalType.bowled:
        return bowler == null ? 'b' : 'b $bowler';
      case DismissalType.caught:
        if (fielder != null && bowler != null) return 'c $fielder b $bowler';
        if (bowler != null) return 'c b $bowler';
        return 'caught';
      case DismissalType.lbw:
        return bowler == null ? 'lbw' : 'lbw b $bowler';
      case DismissalType.stumped:
        if (fielder != null && bowler != null) return 'st $fielder b $bowler';
        if (bowler != null) return 'st b $bowler';
        return 'stumped';
      case DismissalType.hitWicket:
        return bowler == null ? 'hit wicket' : 'hw b $bowler';
      case DismissalType.runOut:
        return fielder == null ? 'run out' : 'run out ($fielder)';
      case DismissalType.obstructing:
        return 'obstructing the field';
      case DismissalType.retiredHurt:
        return 'retired hurt';
      case DismissalType.retiredOut:
        return 'retired out';
    }
  }
}

class BattingCard {
  final String playerId;
  String name;
  bool isNotOut = true;
  DismissalType? dismissal;
  String? dismissedByName;
  String? bowlerName;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int dots = 0;
  int position = 0;
  int wicketNumber = 0;

  BattingCard({required this.playerId, required this.name});

  factory BattingCard.fromJson(Map<String, dynamic> j) {
    final c = BattingCard(
        playerId: (j['playerId'] ?? '').toString(),
        name: (j['name'] ?? '').toString());
    c.isNotOut = (j['isNotOut'] ?? true) as bool;
    final d = j['dismissal']?.toString();
    c.dismissal = d == null ? null : DismissalType.fromId(d);
    c.dismissedByName = j['dismissedByName']?.toString();
    c.bowlerName = j['bowlerName']?.toString();
    c.runs = (j['runs'] ?? 0) as int;
    c.balls = (j['balls'] ?? 0) as int;
    c.fours = (j['fours'] ?? 0) as int;
    c.sixes = (j['sixes'] ?? 0) as int;
    c.dots = (j['dots'] ?? 0) as int;
    c.position = (j['position'] ?? 0) as int;
    c.wicketNumber = (j['wicketNumber'] ?? 0) as int;
    return c;
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'isNotOut': isNotOut,
        'dismissal': dismissal?.name,
        'dismissedByName': dismissedByName,
        'bowlerName': bowlerName,
        'runs': runs,
        'balls': balls,
        'fours': fours,
        'sixes': sixes,
        'dots': dots,
        'position': position,
        'wicketNumber': wicketNumber,
      };

  double? get strikeRate => balls == 0 ? null : runs * 100 / balls;
}

class BowlingCard {
  final String playerId;
  String name;
  int balls = 0;
  int maidens = 0;
  int runsConceded = 0;
  int wickets = 0;
  int wides = 0;
  int noBalls = 0;
  int overRuns = 0; // bowler-charged runs in the current over
  int overBalls = 0; // bowler balls (incl wides/nb) in the current over
  int overLegal = 0; // legal balls in the current over

  /// Legal deliveries bowled. Distinct from [balls], which counts EVERY
  /// delivery including wides and no-balls.
  ///
  /// Cricket: an over is six legal deliveries. A wide or no-ball does not
  /// consume one, so neither advances the bowler's overs, and economy is
  /// conventionally runs per SIX LEGAL BALLS. Deriving either from [balls]
  /// inflated a bowler's overs and economy by every penalty they conceded -
  /// a bowler who sent 6 legal + 2 wides read "8.2 ov" instead of "6.0 ov".
  ///
  /// Saves written before this field existed fall back to [balls], which is
  /// the old (slightly high) figure rather than a wrong-looking blank.
  int legalBalls = 0;

  BowlingCard({required this.playerId, required this.name});

  factory BowlingCard.fromJson(Map<String, dynamic> j) {
    final c = BowlingCard(
        playerId: (j['playerId'] ?? '').toString(),
        name: (j['name'] ?? '').toString());
    c.balls = (j['balls'] ?? 0) as int;
    c.maidens = (j['maidens'] ?? 0) as int;
    c.runsConceded = (j['runsConceded'] ?? 0) as int;
    c.wickets = (j['wickets'] ?? 0) as int;
    c.wides = (j['wides'] ?? 0) as int;
    c.noBalls = (j['noBalls'] ?? 0) as int;
    c.overRuns = (j['overRuns'] ?? 0) as int;
    c.overBalls = (j['overBalls'] ?? 0) as int;
    c.overLegal = (j['overLegal'] ?? 0) as int;
    // Legacy saves have no legalBalls: fall back to the total they recorded
    // rather than showing 0.0 ov for a bowler who actually bowled.
    c.legalBalls = (j['legalBalls'] ?? j['balls'] ?? 0) as int;
    return c;
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'balls': balls,
        'maidens': maidens,
        'runsConceded': runsConceded,
        'wickets': wickets,
        'wides': wides,
        'noBalls': noBalls,
        'overRuns': overRuns,
        'overBalls': overBalls,
        'overLegal': overLegal,
        'legalBalls': legalBalls,
      };

  /// Overs from LEGAL balls only - `2.4` is two overs and four legal balls,
  /// never a decimal fraction.
  String get oversDisplay => '${legalBalls ~/ 6}.${legalBalls % 6}';

  /// Penalty runs charged to this bowler, for the "incl" sub-line. Wides and
  /// no-ball penalties are ALREADY inside [runsConceded] (Law 41.14) - this
  /// only breaks them out for display so the total is never read twice.
  int get penaltyRuns => wides + noBalls;

  bool get bowledAny => legalBalls > 0 || balls > 0;

  double? get average => wickets == 0 ? null : runsConceded / wickets;
  double? get economy => legalBalls == 0 ? null : runsConceded * 6 / legalBalls;
  double? get strikeRate => wickets == 0 ? null : legalBalls / wickets;
}

class FieldingCard {
  final String playerId;
  String name;
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;
  FieldingCard({required this.playerId, required this.name});
  factory FieldingCard.fromJson(Map<String, dynamic> j) {
    final c = FieldingCard(
        playerId: (j['playerId'] ?? '').toString(),
        name: (j['name'] ?? '').toString());
    c.catches = (j['catches'] ?? 0) as int;
    c.runOuts = (j['runOuts'] ?? 0) as int;
    c.stumpings = (j['stumpings'] ?? 0) as int;
    return c;
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'name': name,
        'catches': catches,
        'runOuts': runOuts,
        'stumpings': stumpings,
      };
  int get total => catches + runOuts + stumpings;
}

/// Per-innings attribution sheet. One method owns the Laws: applyDelivery.
class InningsSheet {
  final String battingTeam;
  final String bowlingTeam;
  String? strikerId;
  String? nonStrikerId;
  String? bowlerId;
  final Map<String, String> names = {};

  /// The BATTING side's XI. `names` holds both squads (the sheet registers
  /// both so figures can be attributed), which meant `nextBatterOptions`
  /// offered the entire fielding side as batters - a Tigers player could be
  /// brought on to bat for the Lions. Only this set is eligible to come in.
  final Set<String> battingXI = {};
  final Map<String, BattingCard> batting = {};
  final Map<String, BowlingCard> bowling = {};
  final Map<String, FieldingCard> fielding = {};
  int partnershipRuns = 0;
  int partnershipBalls = 0;
  final List<Map<String, int>> partnerships = [];
  int nextPosition = 3;
  int wicketNumber = 0;

  /// Completed over already credited to the bowlers' figures. Counts overs
  /// that have reached six legal balls, so it is idempotent: re-deriving it
  /// on every delivery closes each over exactly once (a second close would
  /// hand the same bowler a second maiden).
  int closedOvers = 0;

  /// Who bowled the last completed over. Shown on the picker ("Prev: Ravi")
  /// so the choice is informed, not just greyed-out.
  String? lastBowlerId;

  /// Set the instant an over ends, cleared by picking the next bowler.
  ///
  /// This is the ONLY bowler latch. It previously shared the job with
  /// `promptedOver`/`promptedBowler` and `latchedOver`, and the three
  /// disagreed: the store armed its latch on the *seventh* tap (the tap after
  /// the over ended) while the screen prompted on the sixth, so the same over
  /// asked twice, the first ball of the new over was refused, and picking a
  /// bowler for it went unrecorded. One field, armed by the delivery that
  /// completes the over, disarmed by the pick.
  bool needsNewBowler = false;

  /// Number of completed overs this bowler may not bowl: Law 17.4 forbids two
  /// consecutive overs. -1 when there is no previous over.
  int get consecutiveBlocked => lastBowlerId == null ? -1 : 0;

  InningsSheet({required this.battingTeam, required this.bowlingTeam});

  factory InningsSheet.fromJson(Map<String, dynamic> j) {
    final s = InningsSheet(
      battingTeam: (j['battingTeam'] ?? '').toString(),
      bowlingTeam: (j['bowlingTeam'] ?? '').toString(),
    );
    s.strikerId = j['strikerId']?.toString();
    s.nonStrikerId = j['nonStrikerId']?.toString();
    s.bowlerId = j['bowlerId']?.toString();
    final names = (j['names'] ?? {}) as Map;
    for (final e in names.entries) {
      s.names[e.key.toString()] = e.value.toString();
    }
    for (final e in ((j['battingXI'] ?? []) as List)) {
      s.battingXI.add(e.toString());
    }
    for (final e in ((j['batting'] ?? {}) as Map).entries) {
      s.batting[e.key.toString()] =
          BattingCard.fromJson(Map<String, dynamic>.from(e.value as Map));
    }
    for (final e in ((j['bowling'] ?? {}) as Map).entries) {
      s.bowling[e.key.toString()] =
          BowlingCard.fromJson(Map<String, dynamic>.from(e.value as Map));
    }
    for (final e in ((j['fielding'] ?? {}) as Map).entries) {
      s.fielding[e.key.toString()] =
          FieldingCard.fromJson(Map<String, dynamic>.from(e.value as Map));
    }
    s.partnershipRuns = (j['partnershipRuns'] ?? 0) as int;
    s.partnershipBalls = (j['partnershipBalls'] ?? 0) as int;
    for (final p in ((j['partnerships'] ?? []) as List)) {
      final m = Map<String, dynamic>.from(p as Map);
      s.partnerships.add(
          {'runs': (m['runs'] ?? 0) as int, 'balls': (m['balls'] ?? 0) as int});
    }
    s.nextPosition = (j['nextPosition'] ?? 3) as int;
    s.wicketNumber = (j['wicketNumber'] ?? 0) as int;
    s.closedOvers = (j['closedOvers'] ?? 0) as int;
    s.lastBowlerId = j['lastBowlerId']?.toString();
    s.needsNewBowler = (j['needsNewBowler'] ?? false) as bool;
    return s;
  }

  Map<String, dynamic> toJson() => {
        'battingTeam': battingTeam,
        'bowlingTeam': bowlingTeam,
        'strikerId': strikerId,
        'nonStrikerId': nonStrikerId,
        'bowlerId': bowlerId,
        'names': names,
        'battingXI': battingXI.toList(),
        'batting': batting.map((k, v) => MapEntry(k, v.toJson())),
        'bowling': bowling.map((k, v) => MapEntry(k, v.toJson())),
        'fielding': fielding.map((k, v) => MapEntry(k, v.toJson())),
        'partnershipRuns': partnershipRuns,
        'partnershipBalls': partnershipBalls,
        'partnerships': partnerships,
        'nextPosition': nextPosition,
        'wicketNumber': wicketNumber,
        'closedOvers': closedOvers,
        'lastBowlerId': lastBowlerId,
        'needsNewBowler': needsNewBowler,
      };

  String nameOf(String id) => names[id] ?? '?';

  /// Registers the batting side's XI. Fielders are registered too (figures
  /// need them) but must never be offered as batters.
  void setBattingXI(List<Player> players) {
    battingXI
      ..clear()
      ..addAll(players.map((p) => p.id));
  }

  /// Adds one id to the batting XI (a mid-match addition to that side).
  void addToBattingXI(String id) => battingXI.add(id);

  void register(Player p) {
    names[p.id] = p.name;
    batting.putIfAbsent(p.id, () => BattingCard(playerId: p.id, name: p.name));
    bowling.putIfAbsent(p.id, () => BowlingCard(playerId: p.id, name: p.name));
    fielding.putIfAbsent(
        p.id, () => FieldingCard(playerId: p.id, name: p.name));
  }

  void registerSquad(List<Player> squad) {
    for (final p in squad) {
      register(p);
    }
  }

  BattingCard? get striker => strikerId == null ? null : batting[strikerId];
  BattingCard? get nonStriker =>
      nonStrikerId == null ? null : batting[nonStrikerId];
  BowlingCard? get currentBowler => bowlerId == null ? null : bowling[bowlerId];

  /// Players who have not batted yet (position == 0), in registration order.
  List<String> get waitingBatters => names.keys
      .where((id) =>
          (batting[id]?.position ?? 0) == 0 &&
          id != strikerId &&
          id != nonStrikerId)
      .toList();

  /// Who may come in after [outId] goes. Explicit by id, never by position
  /// alone: the out batter, the non-striker, the dismissed and the retired-out
  /// are all excluded, so the non-striker can never appear as their own
  /// replacement. Retired-hurt IS included: they may resume.
  List<String> nextBatterOptions(String outId) {
    final opts = <String>[];
    for (final id in names.keys) {
      if (id == outId || id == nonStrikerId) continue;
      // A batter must come from the side that is batting. [battingXI] is
      // empty on sheets saved before it existed, so those fall back to the
      // old behaviour rather than offering nobody.
      if (battingXI.isNotEmpty && !battingXI.contains(id)) continue;
      final c = batting[id];
      if (c == null) continue;
      if (c.position == 0) {
        opts.add(id);
        continue;
      }
      // Batted before: only a retired-hurt returnee may come again, and they
      // are recorded not-out=false, so this check must come first.
      if (c.dismissal == DismissalType.retiredHurt) {
        opts.add(id);
        continue;
      }
      if (!c.isNotOut) continue;
    }
    return opts;
  }

  /// A retired-hurt player resumes: same batting position, back not-out.
  /// Retired-out never returns.
  bool reEnter(String id) {
    final c = batting[id];
    if (c == null) return false;
    if (c.dismissal != DismissalType.retiredHurt) return false;
    c.isNotOut = true;
    c.dismissal = null;
    c.wicketNumber = 0;
    return true;
  }

  /// Dismissed this innings, in fall order.
  List<BattingCard> get fallOfWickets {
    final gone = batting.values
        .where((c) => c.position > 0 && !c.isNotOut && c.wicketNumber > 0)
        .toList()
      ..sort((a, b) => a.wicketNumber.compareTo(b.wicketNumber));
    return gone;
  }

  List<BattingCard> get battingCards {
    final list = batting.values.where((c) => c.position > 0).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  List<BowlingCard> get bowlingCards {
    final list =
        bowling.values.where((c) => c.balls > 0 || c.wickets > 0).toList()
          ..sort((a, b) {
            final w = b.wickets.compareTo(a.wickets);
            return w != 0 ? w : a.runsConceded.compareTo(b.runsConceded);
          });
    return list;
  }

  void setOpeners(String a, String b) {
    strikerId = a;
    nonStrikerId = b;
    _enter(a, 1);
    _enter(b, 2);
    nextPosition = 3;
    partnershipRuns = 0;
    partnershipBalls = 0;
  }

  void _enter(String id, int pos) {
    final c = batting[id];
    if (c == null) return;
    c.position = pos;
    c.isNotOut = true;
  }

  /// Bring in [nextId] at the striker's end. Returns false when nobody is left.
  /// Scores a new arrival onto the card: takes the next batting position, or
  /// restores the original one for a retired-hurt returnee.
  void _seat(String nextId) {
    final c = batting[nextId];
    if (c != null && c.position == 0) {
      _enter(nextId, nextPosition);
      nextPosition++;
    } else {
      // A resumed innings (retired-hurt return): original position stands.
      reEnter(nextId);
    }
  }

  bool bringIn(String nextId) {
    if (!names.containsKey(nextId)) return false;
    _bankPartnership();
    strikerId = nextId;
    _seat(nextId);
    partnershipRuns = 0;
    partnershipBalls = 0;
    return true;
  }

  /// Crossed run-out correction: new batter goes to the other end.
  /// Seats the incoming batter after a dismissal on which the ends changed.
  ///
  /// Order matters and was previously wrong: it swapped and then overwrote the
  /// striker, which left the DISMISSED batter on the non-striker's end - a
  /// wicket that never happened as far as the scorecard was concerned.
  ///
  /// Cricket: the batters crossed, so the striker is dismissed at the FAR end.
  /// The incoming batter goes to that far end, which becomes the non-striker's
  /// end; the man who crossed keeps the strike.
  void crossedRunOutFix(String incomingId) {
    // Only correct when the STRIKER was dismissed after crossing: he is out at
    // the far end, the man who crossed is now striker, and the newcomer takes
    // the striker's vacated end (the non-striker's end after the swap).
    //
    // This must never run for a NON-STRIKER dismissal. He was out at his own
    // end, so nothing moved: the safe batter keeps the striker's end and the
    // newcomer simply fills the vacated non-striker's end. Swapping here left
    // the struck-off man sitting in the striker slot - dismissed but still
    // listed on strike.
    swapEnds();
    nonStrikerId = incomingId;
  }

  /// Seats [incomingId] at the NON-STRIKER's end, leaving the striker alone.
  ///
  /// Used when the batter at that end was dismissed and the man on strike
  /// completed his run and stayed where he was: nobody moved ends, so the
  /// newcomer just fills the gap opposite him.
  void bringInAtNonStrikerEnd(String incomingId) {
    if (!names.containsKey(incomingId)) return;
    _bankPartnership();
    _seat(incomingId);
    nonStrikerId = incomingId;
    partnershipRuns = 0;
    partnershipBalls = 0;
  }

  void swapEnds() {
    final t = strikerId;
    strikerId = nonStrikerId;
    nonStrikerId = t;
  }

  void _bankPartnership() {
    if (partnershipBalls > 0 || partnershipRuns > 0) {
      partnerships.add({'runs': partnershipRuns, 'balls': partnershipBalls});
    }
  }

  /// The law forbids consecutive overs.
  /// Law 17.4: a bowler may not bowl two overs in succession.
  ///
  /// `bowlerId` alone was not enough — it only blocked whoever is bowling
  /// *right now*. A mid-over change (legal only for injury, and offered by
  /// the app) could hand the over to the player who bowled the previous one,
  /// letting them bowl consecutive overs. `lastBowlerId` is set whenever an
  /// over closes, so both are now refused.
  bool canBowl(String id) => id != bowlerId && id != lastBowlerId;

  /// Why a player cannot bowl right now, for the picker's disabled reason.
  String? bowlBlockReason(String id) {
    if (id == bowlerId) return 'already bowling';
    if (id == lastBowlerId) return 'bowled the last over';
    return null;
  }

  void setBowler(String id) {
    // No reset here: whoever ends an over must close it first, so the maiden
    // credit and the counter reset always travel together (see closeOver).
    bowlerId = id;
  }

  /// Overs that have reached six legal balls, counted from the delivery list.
  ///
  /// Derived rather than assumed so it is idempotent: calling it on every
  /// delivery closes each over exactly once, and a second close would hand the
  /// same bowler a duplicate maiden.
  int completedOverCount(Innings inn) {
    var n = 0;
    for (final o in inn.overs) {
      if (o.balls.where((x) => x.isLegal).length >= 6) n++;
    }
    return n;
  }

  /// Closes the current bowler's over: maiden credit plus counter reset, in one
  /// place. A maiden needs a full 6 legal balls with zero bowler-charged runs.
  /// Mid-over changes pass 0 legal balls: counters reset, no maiden.
  void closeOver({required int legalBalls}) {
    final b = currentBowler;
    if (b == null) return;
    if (legalBalls >= 6) lastBowlerId = b.playerId;
    if (legalBalls >= 6 && b.overRuns == 0) b.maidens++;
    b.overRuns = 0;
    b.overBalls = 0;
    b.overLegal = 0;
  }

  /// One place where the Laws decide who is charged with what.
  void applyDelivery(Ball ball,
      {DismissalType? dismissalType, String? fielderName}) {
    final bat = striker;
    final bowl = currentBowler;
    if (bat == null || bowl == null) return;

    if (ball.extra == 'WD') {
      // A wide is charged to the bowler (Law 41.14) but is NOT a legal
      // delivery: no legalBalls, so the bowler's overs do not advance.
      bowl.balls++;
      bowl.overBalls++;
      bowl.wides++;
      bowl.runsConceded += ball.extraRuns;
      bowl.overRuns += ball.extraRuns;
      partnershipRuns += ball.extraRuns;
      return;
    }

    if (ball.extra == 'NB') {
      bat.balls++;
      bowl.balls++;
      bowl.overBalls++;
      bowl.noBalls++;
      // Only the PENALTY is charged to the bowler; runs off the bat belong to
      // the batter and are never the bowler's figures.
      bowl.runsConceded += ball.extraRuns;
      bowl.overRuns += ball.extraRuns;
      if (ball.runs > 0) {
        bat.runs += ball.runs;
        partnershipRuns += ball.runs;
        partnershipBalls++;
        if (ball.runs == 4) bat.fours++;
        if (ball.runs == 6) bat.sixes++;
      } else {
        partnershipRuns += ball.extraRuns;
      }
      return;
    }

    if (ball.extra == 'B' || ball.extra == 'LB') {
      // Byes and leg-byes ARE legal deliveries (they consume one of the six)
      // but are NOT charged to the bowler - they were not his fault.
      bat.balls++;
      bowl.balls++;
      bowl.overBalls++;
      bowl.overLegal++;
      bowl.legalBalls++;
      partnershipRuns += ball.extraRuns;
      partnershipBalls++;
      return;
    }

    // Legal delivery.
    bat.balls++;
    bowl.balls++;
    bowl.overBalls++;
    bowl.overLegal++;
    bowl.legalBalls++;
    bat.runs += ball.runs;
    bowl.runsConceded += ball.runs;
    bowl.overRuns += ball.runs;
    partnershipRuns += ball.runs;
    partnershipBalls++;
    if (ball.runs == 0) bat.dots++;
    if (ball.runs == 4) bat.fours++;
    if (ball.runs == 6) bat.sixes++;

    if (ball.isWicket) {
      final type = dismissalType ?? DismissalType.fromId(ball.wicketType);
      bat.dismissal = type;
      bat.isNotOut = false;
      // Retirements are not wickets: no number, no fall-of-wickets entry.
      if (type != DismissalType.retiredHurt &&
          type != DismissalType.retiredOut) {
        wicketNumber++;
        bat.wicketNumber = wicketNumber;
      }
      if (type.creditsBowler) {
        bowl.wickets++;
        bat.bowlerName = bowl.name;
      }
      if (type.hasFielder && fielderName != null && fielderName.isNotEmpty) {
        bat.dismissedByName = fielderName;
        // Attribute to a same-named fielder when the squad has one.
        for (final f in fielding.values) {
          if (f.name == fielderName) {
            if (type == DismissalType.stumped) {
              f.stumpings++;
            } else if (type == DismissalType.runOut) {
              f.runOuts++;
            } else {
              f.catches++;
            }
            break;
          }
        }
      }
      _bankPartnership();
      partnershipRuns = 0;
      partnershipBalls = 0;
      return;
    }

    if (ball.runs % 2 == 1) swapEnds();
  }

  /// This-over balls for the strip header, e.g. [1,4,W,0].
  List<String> thisOverBadges(List<Ball> balls) =>
      balls.map((b) => b.badge).toList();
}

/// Outcome of a bulk roster add: created players plus the duplicate count
/// the UI reports ("3 added, 2 already existed").
class BulkResult {
  final List<Player> added;
  final int skipped;
  const BulkResult(this.added, this.skipped);
}

/// Career aggregates across matches. Computed at read time from per-match
/// figures — never a second totals table that can drift.
class CareerBatting {
  int innings = 0;
  int notOuts = 0;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int dots = 0;
  int hs = 0;
  int fifties = 0;
  int thirties = 0;
  void add(BattingCard c) {
    if (c.position == 0) return;
    innings++;
    if (c.isNotOut) notOuts++;
    runs += c.runs;
    balls += c.balls;
    fours += c.fours;
    sixes += c.sixes;
    dots += c.dots;
    if (c.runs > hs) hs = c.runs;
    if (c.runs >= 50) fifties++;
    if (c.runs >= 30) thirties++;
  }

  int get outs => innings - notOuts;
  double? get average => outs == 0 ? (runs == 0 ? 0.0 : null) : runs / outs;
  double? get strikeRate => balls == 0 ? null : runs * 100 / balls;
}

class CareerBowling {
  int innings = 0;
  int balls = 0;
  int maidens = 0;
  int runs = 0;
  int wickets = 0;
  int wides = 0;
  int noBalls = 0;
  int bestW = 0;
  int bestR = 0;
  int fiveHauls = 0;
  int threeHauls = 0;
  void add(BowlingCard c) {
    if (c.balls == 0 && c.wickets == 0) return;
    innings++;
    balls += c.balls;
    maidens += c.maidens;
    runs += c.runsConceded;
    wickets += c.wickets;
    wides += c.wides;
    noBalls += c.noBalls;
    if (c.wickets > bestW || (c.wickets == bestW && runs < bestR)) {
      bestW = c.wickets;
      bestR = c.runsConceded;
    }
    if (c.wickets >= 5) fiveHauls++;
    if (c.wickets >= 3) threeHauls++;
  }

  String get overs => '${balls ~/ 6}.${balls % 6}';
  double? get average => wickets == 0 ? null : runs / wickets;
  double? get economy => balls == 0 ? null : runs * 6 / balls;
  double? get strikeRate => wickets == 0 ? null : balls / wickets;
}
