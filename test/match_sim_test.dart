import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/models.dart';
import 'package:cricket_scoring/store.dart';

/// A tracked match with [perSide] players each, ready for openers.
/// [xiA]/[xiB] is how many players start in each XI; [cap] is playersPerSide,
/// so a test can leave room for a mid-match add.
MatchStore trackedFixture(
    {int xiA = 5, int xiB = 5, int cap = 5, int overs = 2}) {
  final s = MatchStore(sync: FakeSync());
  // Scoring fires haptics through a platform channel; these are pure logic
  // tests with no widget binding, so keep the master toggle off.
  s.hapticsOn = false;
  s.createClub(name: 'Gully Kings');
  final a = <String>[];
  final b = <String>[];
  for (var i = 1; i <= xiA; i++) {
    a.add(s.addPlayer(name: 'A$i', role: PlayerRole.allRounder)!.id);
  }
  for (var i = 1; i <= xiB; i++) {
    b.add(s.addPlayer(name: 'B$i', role: PlayerRole.allRounder)!.id);
  }
  s.draft = MatchConfig(
      teamA: 'Lions',
      teamB: 'Tigers',
      totalOvers: overs,
      playersPerSide: cap,
      trackPlayers: true,
      squadA: a,
      squadB: b,
      rules: Rules(widePenalty: 1, noBallPenalty: 1));
  s.startMatch(s.draft);
  return s;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('over-end bowler change (the stuck loop)', () {
    test('6th ball prompts; the 7th ball is never refused', () {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);

      // Six legal balls: the over completes ON the sixth.
      for (var i = 0; i < 6; i++) {
        expect(s.score(action: 'DOT'), isNull, reason: 'ball ${i + 1}');
      }
      final sheet = s.currentSheet!;
      expect(sheet.needsNewBowler, isTrue,
          reason: 'the over ended, so a change is owed');
      expect(sheet.lastBowlerId, b[0]);
      expect(s.innings!.legalDeliveries, 6);

      // The same bowler may not bowl two consecutive overs (Law 17.4).
      expect(s.setBowler(b[0]), isNotNull);

      s.setBowler(b[1]);
      expect(sheet.needsNewBowler, isFalse);

      // THE REGRESSION: this delivery used to be refused, stranding the umpire
      // in a loop of "pick a bowler" prompts.
      expect(s.score(action: 'RUNS', runs: 1), isNull);
      expect(s.innings!.legalDeliveries, 7);
      expect(sheet.needsNewBowler, isFalse,
          reason: 'the new over must not immediately ask again');
    });

    test('a maiden is credited exactly once', () {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);
      for (var i = 0; i < 6; i++) {
        s.score(action: 'DOT');
      }
      expect(s.currentSheet!.bowling[b[0]]!.maidens, 1);
      // More taps while the latch is on must not re-close the over.
      for (var i = 0; i < 3; i++) {
        expect(s.score(action: 'DOT'), MatchStore.needBowlerMsg);
      }
      expect(s.currentSheet!.bowling[b[0]]!.maidens, 1,
          reason: 'a repeated close would hand out a second maiden');
      s.setBowler(b[1]);
      s.score(action: 'DOT');
      expect(s.currentSheet!.bowling[b[0]]!.maidens, 1);
    });

    test('a non-empty over is not a maiden', () {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);
      for (var i = 0; i < 5; i++) {
        s.score(action: 'DOT');
      }
      s.score(action: 'RUNS', runs: 4);
      expect(s.currentSheet!.bowling[b[0]]!.maidens, 0);
    });

    test('over ends do not stack across a whole innings', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 3);
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);

      var changes = 0;
      var balls = 0;
      var bi = 0;
      while (s.innings!.legalDeliveries < 18 && balls < 200) {
        final err = s.score(action: 'DOT');
        if (err == MatchStore.needBowlerMsg) {
          changes++;
          bi = (bi + 1) % b.length;
          s.setBowler(b[bi]);
        }
        balls++;
      }
      expect(s.innings!.legalDeliveries, 18);
      // Overs 1 and 2 each owe a change; over 3 is the innings' last, and
      // nothing is owed once the innings is over.
      expect(changes, 2,
          reason: 'one change per completed over that is followed by another');
    });

    test('undo restores the latch', () async {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);
      for (var i = 0; i < 6; i++) {
        s.score(action: 'DOT');
      }
      expect(s.currentSheet!.needsNewBowler, isTrue);
      await s.undo(); // take back the 6th ball
      expect(s.innings!.legalDeliveries, 5);
      expect(s.currentSheet!.needsNewBowler, isFalse,
          reason: 'undoing the last ball un-ends the over');
    });
  });

  group('Law 17.4: no two consecutive overs', () {
    test('the previous over bowler is blocked even mid-over', () {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);
      for (var i = 0; i < 6; i++) {
        s.score(action: 'DOT');
      }
      s.setBowler(b[1]);
      // A mid-over change to the bowler who just bowled the previous over
      // used to be allowed: canBowl only compared against the CURRENT bowler.
      expect(s.setBowler(b[0]), isNotNull);
      expect(s.currentSheet!.canBowl(b[0]), isFalse);
      expect(s.currentSheet!.canBowl(b[2]), isTrue);
    });
  });

  group('bowling figures count legal balls', () {
    test('wides and no-balls do not advance overs or economy', () {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);
      for (var i = 0; i < 5; i++) {
        s.score(action: 'DOT');
      }
      s.score(action: 'WIDE');
      s.score(action: 'NB_DIRECT');

      final c = s.currentSheet!.bowling[b[0]]!;
      expect(c.balls, 7, reason: 'seven deliveries sent down');
      expect(c.wides, 1);
      expect(c.noBalls, 1);
      // 5 legal + 2 extras = 7 balls, but only FIVE overs balls.
      expect(c.legalBalls, 5);
      expect(c.oversDisplay, '0.5',
          reason: 'a wide is not a legal ball (Law 17.3)');
      expect(c.economy, closeTo(c.runsConceded * 6 / 5, 1e-9),
          reason: 'economy is runs per six LEGAL balls');
    });

    test('runs conceded include wide and no-ball penalties', () {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);
      s.score(action: 'RUNS', runs: 4);
      s.score(action: 'WIDE');
      s.score(action: 'NB_DIRECT');
      final c = s.currentSheet!.bowling[b[0]]!;
      // Law 41.14: the penalties are charged to the bowler.
      expect(c.runsConceded, 4 + 1 + 1);
      expect(c.penaltyRuns, 2);
    });

    test('byes and leg-byes are legal but not charged to the bowler', () {
      final s = trackedFixture();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(b[0]);
      s.score(action: 'BYE', runs: 1);
      s.score(action: 'LEGBYE', runs: 1);
      final c = s.currentSheet!.bowling[b[0]]!;
      expect(c.legalBalls, 2, reason: 'they consume a legal delivery');
      expect(c.runsConceded, 0, reason: 'not the bowler fault');
    });

    test('a legacy save without legalBalls still shows overs', () {
      final c = BowlingCard.fromJson({
        'playerId': 'p1',
        'name': 'Ravi',
        'balls': 8,
        'runsConceded': 20,
      });
      expect(c.legalBalls, 8, reason: 'falls back to the old total');
      expect(c.oversDisplay, '1.2');
    });
  });

  group('ghost players', () {
    test('an inactive player stays visible so their name can be cleared', () {
      final s = MatchStore();
      s.createClub(name: 'Gully Kings');
      final id = s.addPlayer(name: 'Sanjay')!.id;
      s.setPlayerActive(id, false);

      // The bug: the name was blocked by a player no list could show.
      expect(s.duplicateName('Sanjay'), isTrue);
      final found = s.searchRoster('sanjay').map((p) => p.id).toList();
      expect(found, contains(id),
          reason: 'a name that blocks must be findable and editable');
      expect(s.playerByName('Sanjay')!.id, id);
    });

    test('active players sort above inactive ones', () {
      final s = MatchStore();
      s.createClub(name: 'Gully Kings');
      final off = s.addPlayer(name: 'Zed')!.id;
      s.addPlayer(name: 'Abe');
      s.setPlayerActive(off, false);
      final list = s.searchRoster('');
      expect(list.first.name, 'Abe');
    });
  });

  group('club rename and delete', () {
    test('rename updates the name and the derived handle', () {
      final s = MatchStore();
      final c = s.createClub(name: 'Old Name');
      expect(s.renameClub(c.id, 'New Name'), isNull);
      expect(s.activeClub!.name, 'New Name');
      expect(s.activeClub!.handle, 'new-name');
      expect(s.renameClub(c.id, '   '), isNotNull);
    });

    test('delete removes the club and its players', () {
      final s = MatchStore();
      final c = s.createClub(name: 'Eagles');
      s.addPlayer(name: 'Ravi');
      s.addPlayer(name: 'Suresh');
      expect(s.clubRoster.length, 2);
      expect(s.deleteClub(c.id), isNull);
      expect(s.clubs, isEmpty);
      expect(s.roster, isEmpty);
      expect(s.activeClubId, isNull);
    });

    test('delete is refused while a live XI uses a player', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5);
      final club = s.clubs.first;
      final err = s.deleteClub(club.id);
      expect(err, isNotNull);
      expect(s.clubs, isNotEmpty);
    });
  });

  group('mid-match adds', () {
    test('an unknown name is created and added when the XI has room', () {
      final s = trackedFixture(xiB: 5, cap: 6);
      final before = s.clubRoster.length;
      expect(s.addSquadByName('Tigers', 'Mukesh'), isNull);
      expect(s.clubRoster.length, before + 1);
      expect(
          s.match!.config.squadB
              .any((id) => s.playerById(id)!.name == 'Mukesh'),
          isTrue);
    });

    test('a typed name that matches an INACTIVE player adds them', () {
      final s = trackedFixture(xiB: 5, cap: 6);
      final off = s.addPlayer(name: 'Dinesh')!.id;
      s.setPlayerActive(off, false);
      // Previously the loop found the inactive player and then addPlayer's
      // duplicate guard rejected the create, leaving the squad unchanged.
      expect(s.addSquadByName('Tigers', 'Dinesh'), isNull);
      expect(s.match!.config.squadB, contains(off));
    });

    test('a player added mid-innings is registered on live sheets', () {
      final s = trackedFixture(xiA: 5, cap: 6);
      s.setOpeners(
          s.squadForTeam('Lions')[0].id, s.squadForTeam('Lions')[1].id);
      s.setBowler(s.squadForTeam('Tigers')[0].id);
      expect(s.addSquadByName('Lions', 'Latecomer'), isNull);
      // Registered, so they can actually bat: they are a valid next batter.
      final sheet = s.currentSheet!;
      final latecomer = s.match!.config.squadA.last;
      expect(sheet.names.containsKey(latecomer), isTrue);
      expect(sheet.nextBatterOptions(sheet.strikerId!).contains(latecomer),
          isTrue);
    });

    test('the XI cap still holds mid-match', () {
      final s = trackedFixture(xiB: 5); // cap 5, already full
      expect(s.addSquadByName('Tigers', 'Sixth'), isNotNull);
    });
  });

  group('Law 41.6: the ends change at the end of every over', () {
    // The regression: an over of six dots left the SAME batter on strike for
    // ball 7, because the swap only ever fired on an odd number of runs and a
    // maiden has none. Found by simulating, not by reading.
    test('six dots changes the ends', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;
      final opener = a[0];
      final partner = a[1];

      for (var i = 0; i < 6; i++) {
        expect(s.score(action: 'DOT'), isNull);
      }
      expect(sheet.bowling[b[0]]!.maidens, 1, reason: 'a maiden');
      expect(sheet.strikerId, partner,
          reason: 'Law 41.6: ends switch after a completed over');
      expect(sheet.nonStrikerId, opener);

      s.setBowler(b[1]);
      expect(s.score(action: 'DOT'), isNull);
      expect(sheet.batting[partner]!.balls, 1,
          reason: 'the non-opener faces the first ball of the next over');
      expect(sheet.batting[opener]!.balls, 6);
    });

    test('six boundaries also change the ends', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;
      for (var i = 0; i < 6; i++) {
        expect(s.score(action: 'FOUR'), isNull);
      }
      expect(sheet.strikerId, a[1], reason: 'even runs never swap mid-over');
    });

    test('an over containing an odd run changes ends exactly once', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;
      // Three singles: ends change on ball 1 and again on ball 3.
      s.score(action: 'RUNS', runs: 1);
      s.score(action: 'RUNS', runs: 1);
      s.score(action: 'RUNS', runs: 1);
      for (var i = 0; i < 3; i++) {
        s.score(action: 'DOT');
      }
      // Odd total (3): the batters are back where they started, so the
      // over-boundary change must put the other one on strike once.
      expect(sheet.strikerId, a[1]);
    });

    test('no manual swap is ever needed', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 3);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);

      // Track the expected striker by hand, straight from the Laws, and assert
      // the store agrees on every single delivery.
      var expectStriker = a[0];
      var expectNon = a[1];
      var bi = 1;
      final seq = [
        'DOT',
        'RUNS',
        'DOT',
        'FOUR',
        'DOT',
        'SIX',
        'RUNS',
        'DOT',
        'DOT',
        'DOT',
        'RUNS',
        'WIDE'
      ];
      var li = 0;
      while (s.innings!.legalDeliveries < 12 && li < 200) {
        final err = s.score(action: seq[li % seq.length]);
        if (err == MatchStore.needBowlerMsg) {
          s.setBowler(b[bi % b.length]);
          bi++;
        }
        li++;
        final sheet = s.currentSheet!;
        if (err != null) continue;
        final last = s.innings!.overs.last.balls.last;
        if (last.isLegal) {
          // The ball itself records WHO faced it, which is the only
          // ground truth that is not re-derived by this test. Assert against
          // that, then apply the Laws to the expectation for the next ball.
          expect(last.strikerId, expectStriker,
              reason: 'ball $li: wrong striker faced it');
          expect(last.nonStrikerId, expectNon,
              reason: 'ball $li: wrong non-striker');
        }
        if (last.runs % 2 == 1) {
          final t = expectStriker;
          expectStriker = expectNon;
          expectNon = t;
        }
        // Over boundary: ends switch whatever the over scored.
        if (s.innings!.overs.last.balls.where((x) => x.isLegal).length >= 6) {
          final hadOdd =
              s.innings!.overs.last.balls.any((x) => x.runs % 2 == 1);
          if (!hadOdd) {
            final t = expectStriker;
            expectStriker = expectNon;
            expectNon = t;
          }
          // After the boundary the store must already agree with the model.
          expect(sheet.strikerId, expectStriker,
              reason: 'ball $li: wrong striker after the over ended');
        }
      }
      expect(s.innings!.legalDeliveries, 12);
    });
  });

  group('innings completion owes nothing', () {
    test('the last ball of an innings does not prompt for a bowler', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 1);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      for (var i = 0; i < 5; i++) {
        s.score(action: 'DOT');
      }
      expect(s.currentSheet!.needsNewBowler, isFalse, reason: 'still playing');
      s.score(action: 'DOT'); // sixth legal ball: innings over
      expect(s.innings!.completed, isTrue);
      expect(s.currentSheet!.needsNewBowler, isFalse,
          reason: 'no next over to bowl, so no bowler prompt');
    });

    test('8 players, 7 wickets: all out with no batter prompt', () {
      final s = MatchStore(sync: FakeSync());
      s.hapticsOn = false;
      s.createClub(name: 'Gully Kings');
      final a = [for (var i = 1; i <= 8; i++) s.addPlayer(name: 'A$i')!.id];
      final b = [for (var i = 1; i <= 8; i++) s.addPlayer(name: 'B$i')!.id];
      s.draft = MatchConfig(
          teamA: 'Lions',
          teamB: 'Tigers',
          totalOvers: 20,
          playersPerSide: 8,
          trackPlayers: true,
          squadA: a,
          squadB: b);
      s.startMatch(s.draft);
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);

      // Seven wickets: with 8 players and no last-man-standing the innings is
      // all out at 7, and there is no 8th batter to seat.
      //
      // Dots are mixed in so the wickets do not all land in one over: six
      // wicket-balls would legitimately complete an over and owe a bowler
      // change, which is correct cricket and not what this test is about.
      var seated = 0;
      var bi = 1;
      for (var w = 0; w < 7; w++) {
        s.score(action: 'DOT');
        if (s.innings!.completed) break;
        if (s.currentSheet!.needsNewBowler) {
          s.setBowler(b[bi % b.length]);
          bi++;
          s.score(action: 'DOT');
        }
        if (s.innings!.completed) break;
        final err = s.score(action: 'WICKET', wicketType: 'Bowled');
        expect(err, isNull, reason: 'wicket ${w + 1} should be recordable');
        if (!s.innings!.completed) {
          final opts = s.currentSheet!
              .nextBatterOptions(s.currentSheet!.strikerId ?? '');
          if (opts.isNotEmpty) {
            s.currentSheet!.bringIn(opts.first);
            seated++;
          }
        }
      }
      expect(s.innings!.wickets, 7);
      expect(s.innings!.completed, isTrue, reason: 'all out at 7 of 8 players');
      expect(seated, 6, reason: 'six replacements for seven wickets');
      expect(s.currentSheet!.needsNewBowler, isFalse);
    });

    test('last-man-standing makes 8 wickets available', () {
      final s = MatchStore(sync: FakeSync());
      s.hapticsOn = false;
      s.createClub(name: 'Gully Kings');
      final a = [for (var i = 1; i <= 8; i++) s.addPlayer(name: 'A$i')!.id];
      final b = [for (var i = 1; i <= 8; i++) s.addPlayer(name: 'B$i')!.id];
      s.draft = MatchConfig(
          teamA: 'Lions',
          teamB: 'Tigers',
          totalOvers: 20,
          playersPerSide: 8,
          trackPlayers: true,
          squadA: a,
          squadB: b,
          rules: Rules(lastManStanding: true));
      s.startMatch(s.draft);
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      for (var w = 0; w < 7; w++) {
        s.score(action: 'WICKET', wicketType: 'Bowled');
        if (!s.innings!.completed) {
          final opts = s.currentSheet!
              .nextBatterOptions(s.currentSheet!.strikerId ?? '');
          if (opts.isNotEmpty) s.currentSheet!.bringIn(opts.first);
        }
      }
      expect(s.innings!.completed, isFalse, reason: 'the last man is still in');
    });
  });

  group('run-out at either end', () {
    test('the non-striker can be dismissed, and the ends change', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;

      expect(
          s.score(
              action: 'WICKET',
              wicketType: 'Run Out',
              dismissal: DismissalType.runOut.name,
              fielderName: 'Keeper',
              outAtNonStrikerEnd: true),
          isNull);

      expect(sheet.batting[a[1]]!.isNotOut, isFalse,
          reason: 'the NON-striker is out');
      expect(sheet.batting[a[1]]!.dismissal, DismissalType.runOut);
      expect(sheet.batting[a[0]]!.isNotOut, isTrue,
          reason: 'the striker survives');
      expect(s.innings!.wickets, 1);
    });

    test('a striker run-out on an odd run changes the ends', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;
      s.score(
          action: 'WICKET',
          runs: 1,
          wicketType: 'Run Out',
          dismissal: DismissalType.runOut.name);
      expect(sheet.batting[a[0]]!.isNotOut, isFalse);
      // Odd runs changed the ends, so the incoming batter is at the striker's
      // end and the partner (a[1]) is now the non-striker.
      expect(sheet.strikerId == a[0], isFalse);
      expect(sheet.nonStrikerId == a[0], isFalse,
          reason: 'the dismissed striker is not left on either end');
    });

    test('a run-out never credits the bowler', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      s.score(
          action: 'WICKET',
          wicketType: 'Run Out',
          dismissal: DismissalType.runOut.name);
      expect(s.currentSheet!.bowling[b[0]]!.wickets, 0);
    });
  });

  group('crossing on a non-run-out dismissal', () {
    test('a caught ball with the batters crossed swaps the ends', () {
      // A catch carries ZERO runs, so run parity cannot reveal the crossing -
      // this is the case that silently seated the new batter at the wrong
      // end before the explicit `crossed` flag existed.
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;

      s.score(
          action: 'WICKET',
          wicketType: 'Caught',
          dismissal: DismissalType.caught.name,
          fielderName: 'Ravi',
          crossed: true);

      expect(sheet.batting[a[0]]!.isNotOut, isFalse, reason: 'striker out');
      // Dismissed at the far end, so the crosser keeps the strike and the new
      // batter is at the non-striker's end.
      expect(sheet.strikerId, a[1], reason: 'the crosser is now on strike');
      expect(sheet.nonStrikerId != a[0], isTrue,
          reason: 'the dismissed batter is not left on the sheet');
      expect(sheet.batting[a[1]]!.position, 2,
          reason:
              'the crosser is the non-striker opener and has not batted yet');
      expect(sheet.batting[a[1]]!.balls, 0,
          reason: 'no runs were scored before the catch');
    });

    test('a caught ball with no crossing leaves the ends alone', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;

      s.score(
          action: 'WICKET',
          wicketType: 'Caught',
          dismissal: DismissalType.caught.name,
          crossed: false);

      expect(sheet.strikerId != a[0], isTrue,
          reason: 'the new batter took the striker\'s end');
      expect(sheet.nonStrikerId, a[1],
          reason: 'the partner stays at the bowler\'s end');
    });

    test('bowled while crossing follows the same rule (Option A)', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;

      s.score(
          action: 'WICKET',
          wicketType: 'Bowled',
          dismissal: DismissalType.bowled.name,
          crossed: true);

      expect(sheet.strikerId, a[1],
          reason: 'crossing applies to every dismissal, not just a catch');
    });

    test('the dismissed batter leaves the sheet in every crossing case', () {
      for (final kind in ['Bowled', 'Caught', 'LBW', 'Stumped']) {
        final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
        final a = s.squadForTeam('Lions').map((p) => p.id).toList();
        final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
        s.setOpeners(a[0], a[1]);
        s.setBowler(b[0]);
        final sheet = s.currentSheet!;

        s.score(
            action: 'WICKET',
            wicketType: kind,
            dismissal: DismissalType.fromId(kind).name,
            crossed: true);

        expect(sheet.strikerId, isNot(a[0]), reason: '$kind: not on strike');
        expect(sheet.nonStrikerId, isNot(a[0]),
            reason: '$kind: dismissed batter must leave the sheet');
      }
    });

    test('retirements are unaffected by crossing', () {
      final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 2);
      final a = s.squadForTeam('Lions').map((p) => p.id).toList();
      final b = s.squadForTeam('Tigers').map((p) => p.id).toList();
      s.setOpeners(a[0], a[1]);
      s.setBowler(b[0]);
      final sheet = s.currentSheet!;
      s.score(
          action: 'WICKET',
          wicketType: 'Retired Hurt',
          dismissal: DismissalType.retiredHurt.name,
          crossed: true);
      expect(sheet.strikerId, a[1],
          reason: 'a retirement is not a delivery, so no crossing applies');
    });
  });

  test('a full 5-a-side, 3-over match stays consistent end to end', () {
    final s = trackedFixture(xiA: 5, xiB: 5, cap: 5, overs: 3);
    final lions = s.squadForTeam('Lions').map((p) => p.id).toList();
    final tigers = s.squadForTeam('Tigers').map((p) => p.id).toList();
    s.setOpeners(lions[0], lions[1]);
    s.setBowler(tigers[0]);

    var bi = 1;
    var guard = 0;
    while (!s.innings!.completed && guard < 500) {
      final err = s.score(action: 'DOT');
      if (err != null) {
        // Clear whatever the store refuses, exactly as the UI does.
        if (err == MatchStore.needBowlerMsg) {
          bi = (bi + 1) % tigers.length;
          expect(s.setBowler(tigers[bi]), isNull);
        } else if (err == MatchStore.needSetupMsg) {
          final opts = s.currentSheet!
              .nextBatterOptions(s.currentSheet!.strikerId ?? '');
          if (opts.isEmpty) break;
          s.retireStriker(DismissalType.retiredHurt);
        } else {
          fail('unexpected refusal: $err');
        }
      }
      guard++;
    }

    final sheet = s.currentSheet!;
    final inn = s.innings!;
    expect(inn.legalDeliveries, 18, reason: '3 overs of 6');

    // Team score must equal the sum of every batter's runs plus extras.
    final batRuns = sheet.batting.values.fold<int>(0, (t, c) => t + c.runs);
    expect(inn.runs, batRuns + inn.wides + inn.noBalls + inn.byes + inn.legByes,
        reason: 'score is derived from the ball sequence, never set directly');

    // Overs in the strip must equal the innings legal count.
    final legalInStrip = inn.overs
        .fold<int>(0, (t, o) => t + o.balls.where((x) => x.isLegal).length);
    expect(legalInStrip, inn.legalDeliveries);

    // Every bowler's overs must be legal-ball based and add up.
    final bowlerLegal = sheet.bowling.values
        .where((c) => c.bowledAny)
        .fold<int>(0, (t, c) => t + c.legalBalls);
    expect(bowlerLegal, inn.legalDeliveries,
        reason: 'every legal ball belongs to exactly one bowler');

    // No bowler bowled two consecutive overs.
    var last = '';
    var previous = '';
    for (final o in inn.overs) {
      if (o.balls.isEmpty) continue;
      final who = o.balls.first.bowlerId ?? '';
      if (who.isNotEmpty) {
        expect(who == previous, isFalse,
            reason: 'Law 17.4: $who bowled consecutive overs');
        previous = last;
        last = who;
      }
    }

    // Maidens can never exceed the overs a bowler completed.
    for (final c in sheet.bowling.values) {
      expect(c.maidens * 6, lessThanOrEqualTo(c.legalBalls));
    }
  });
}
