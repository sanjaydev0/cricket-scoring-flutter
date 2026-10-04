import 'dart:convert';

import 'package:cricket_scoring/adapters/local_only_sync.dart';
import 'package:cricket_scoring/domain/room_code.dart';
import 'package:cricket_scoring/domain/room_snapshot.dart';
import 'package:cricket_scoring/ports/sync_port.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _match({int runs = 0}) => {
      'innings1': {'runs': runs, 'wickets': 0}
    };

void main() {
  group('room codes', () {
    test('alphabet excludes symbols people mishear', () {
      // 0/O and 1/I are the classic misreads when a code is shouted aloud.
      expect(RoomCode.alphabet, isNot(contains('0')));
      expect(RoomCode.alphabet, isNot(contains('O')));
      expect(RoomCode.alphabet, isNot(contains('1')));
      expect(RoomCode.alphabet, isNot(contains('I')));
      // 32 symbols => 33,554,432 codes, not 100,000.
      expect(RoomCode.alphabet.length, 32);
    });

    test('generated codes are well formed', () {
      for (var i = 0; i < 500; i++) {
        final c = RoomCode.generate();
        expect(c.length, RoomCode.length);
        expect(RoomCode.isValid(c), isTrue, reason: 'bad code: $c');
      }
    });

    test('generated codes do not repeat in a small batch', () {
      final codes = <String>{};
      for (var i = 0; i < 200; i++) {
        codes.add(RoomCode.generate());
      }
      // Birthday collision rate over 200 draws from 33.5M is negligible.
      expect(codes.length, 200);
    });

    test('normalize upper-cases and trims what a person types', () {
      expect(RoomCode.normalize('  ab3k9 '), 'AB3K9');
      expect(RoomCode.isValid('ab3k9'), isTrue);
    });

    test('normalize rejects wrong length and foreign symbols', () {
      expect(RoomCode.normalize('ABC'), isNull); // too short
      expect(RoomCode.normalize('ABCDEF'), isNull); // too long
      expect(RoomCode.normalize('ABC0E'), isNull); // contains 0
      expect(RoomCode.normalize('ABCOE'), isNull); // contains O
      expect(RoomCode.normalize('ABI2E'), isNull); // contains I
      expect(RoomCode.normalize('AB1DE'), isNull); // contains 1
      expect(RoomCode.normalize(''), isNull);
    });
  });

  group('share attempt messages', () {
    test('each failure names its own cause', () {
      // The whole point: a single "unavailable" string for four failures is
      // what made a network error look like a missing build flag.
      expect(const ShareAttempt.failed(ShareFailure.noBackend, 'x').message,
          contains('off in this build'));
      expect(const ShareAttempt.failed(ShareFailure.noMatch).message,
          contains('Start a match'));
      expect(const ShareAttempt.failed(ShareFailure.offline, 'timeout').message,
          contains('timeout'));
      expect(const ShareAttempt.failed(ShareFailure.failed, 'rpc 400').message,
          contains('rpc 400'));
      expect(const ShareAttempt.ok('ABCDE').message, contains('ABCDE'));
    });
  });

  group('room snapshot', () {
    test('round-trips a match payload', () {
      final s = RoomSnapshot(
        seq: 7,
        match: _match(runs: 42),
        updatedAt: DateTime.utc(2026, 10, 4, 12, 30),
      );
      final back = RoomSnapshot.fromPayload(s.toPayload());
      expect(back, isNotNull);
      expect(back!.seq, 7);
      expect(back.match['innings1']['runs'], 42);
    });

    test('decodes a payload that was stored as a JSON string', () {
      // An early build sent the payload pre-encoded, so Postgres stored it as a
      // jsonb *string* scalar (jsonb_typeof = 'string'). Those rooms must still
      // decode: otherwise a viewer that joins mid-match shows nothing at all.
      final s = RoomSnapshot(
        seq: 4,
        match: _match(runs: 54),
        updatedAt: DateTime.utc(2026, 10, 4),
      );
      final doubleEncoded = jsonEncode(s.toPayload());
      final back = RoomSnapshot.fromPayload(doubleEncoded);
      expect(back, isNotNull);
      expect(back!.seq, 4);
      expect(back.match['innings1']['runs'], 54);
    });

    test('a row whose payload is a string still decodes', () {
      final s = RoomSnapshot(
          seq: 2, match: _match(runs: 7), updatedAt: DateTime.now());
      final row = {'payload': jsonEncode(s.toPayload()), 'seq': 9};
      final back = RoomSnapshot.fromRow(row);
      expect(back, isNotNull);
      // The payload's own seq wins over the column, so ordering stays honest.
      expect(back!.seq, 2);
    });

    test('refuses a payload that is not JSON at all', () {
      expect(RoomSnapshot.fromPayload('not json'), isNull);
      expect(RoomSnapshot.fromPayload(42), isNull);
    });

    test('refuses a payload from a different wire version', () {
      final stale = {
        'v': RoomSnapshot.version + 1,
        'seq': 1,
        'match': _match(),
        'at': DateTime.now().toIso8601String(),
      };
      // A viewer must say "update me" rather than render a shape it can't read.
      expect(RoomSnapshot.fromPayload(stale), isNull);
    });

    test('refuses malformed payloads instead of throwing', () {
      expect(RoomSnapshot.fromPayload(null), isNull);
      expect(RoomSnapshot.fromPayload({}), isNull);
      expect(RoomSnapshot.fromPayload({'v': 1}), isNull);
      expect(
          RoomSnapshot.fromPayload({'v': 1, 'seq': 'x', 'match': {}}), isNull);
    });

    test('reads a database row, falling back to row columns', () {
      final row = {
        'seq': 3,
        'payload': <String, dynamic>{}, // empty payload: use the row columns
        'match': _match(runs: 9),
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      };
      final snap = RoomSnapshot.fromRow(row);
      expect(snap, isNotNull);
      expect(snap!.seq, 3);
      expect(snap.match['innings1']['runs'], 9);
    });

    test('newer sequence supersedes older', () {
      final a =
          RoomSnapshot(seq: 1, match: _match(), updatedAt: DateTime.now());
      final b =
          RoomSnapshot(seq: 2, match: _match(), updatedAt: DateTime.now());
      expect(b.supersedes(a), isTrue);
      expect(a.supersedes(b), isFalse);
      expect(a.supersedes(a), isFalse);
    });
  });

  group('local-only adapter', () {
    test('is unavailable but never fails', () async {
      final s = LocalOnlySync();
      expect(s.state, SyncState.unconfigured);
      await s.init();
      final opened = await s.createRoom();
      expect(opened.ok, isFalse);
      // It must say WHY, not return a bare null.
      expect(opened.failure, ShareFailure.noBackend);
      await s.publish('ABCDE',
          RoomSnapshot(seq: 1, match: _match(), updatedAt: DateTime.now()));
      await s.watchRoom('ABCDE');
      await s.endRoom('ABCDE');
      expect(s.viewerCount, 0);
      await s.shutdown();
    });
  });
}
