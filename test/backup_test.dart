import 'dart:convert';

import 'package:cricket_scoring/backup.dart';
import 'package:cricket_scoring/domain/players.dart';
import 'package:cricket_scoring/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String clubsJson() => jsonEncode([
  Club(id: 'c_test', name: 'Gully CC', handle: 'gully-cc').toJson(),
]);

String rosterJson(String name) =>
    jsonEncode([Player(id: 'p_test', clubId: 'c_test', name: name).toJson()]);

BackupSnapshot playerBackup(String name, {String theme = 'light'}) {
  return BackupSnapshot(
    savedAt: DateTime.utc(2026, 10, 2, 18, 30),
    values: {
      MatchStore.kClubs: clubsJson(),
      MatchStore.kRoster: rosterJson(name),
      MatchStore.kTheme: theme,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(BackupService.channelName);
  String? storedBackup;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storedBackup = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'writeBackup':
              storedBackup =
                  (call.arguments as Map<Object?, Object?>)['content']
                      as String;
              return <String, Object?>{
                'ok': true,
                'path': '/data/app/backups/cricscore-backup.json',
                'downloadsPath':
                    '/sdcard/Download/CricScore/cricscore-backup.json',
              };
            case 'readBackup':
              return storedBackup;
            case 'pickBackup':
              return storedBackup;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('snapshot round-trips values and drops foreign keys', () {
    final snapshot = BackupSnapshot(
      savedAt: DateTime.utc(2026, 10, 2, 18, 30),
      values: {
        MatchStore.kTheme: 'dark',
        MatchStore.kSound: false,
        MatchStore.kAppearanceKeys: <String>['a', 'b'],
        'someone_else_key': 'nope',
      },
    );
    final decoded = BackupSnapshot.decode(snapshot.encode());
    expect(decoded, isNotNull);
    expect(decoded!.values[MatchStore.kTheme], 'dark');
    expect(decoded.values[MatchStore.kSound], isFalse);
    expect(decoded.values[MatchStore.kAppearanceKeys], ['a', 'b']);
    expect(decoded.values.containsKey('someone_else_key'), isFalse);
    expect(decoded.savedAt, DateTime.utc(2026, 10, 2, 18, 30));
  });

  test('bad payloads are rejected, never half-applied', () {
    expect(BackupSnapshot.decode('not json'), isNull);
    expect(
      BackupSnapshot.decode(
        jsonEncode({
          'app': 'other',
          'format': 1,
          'values': {'a': 'b'},
        }),
      ),
      isNull,
    );
    expect(
      BackupSnapshot.decode(
        jsonEncode({
          'app': 'cricscore',
          'format': 99,
          'values': {'cricket_theme': 'dark'},
        }),
      ),
      isNull,
    );
    expect(
      BackupSnapshot.decode(
        jsonEncode({'app': 'cricscore', 'format': 1, 'values': {}}),
      ),
      isNull,
    );
  });

  test('first boot restores the saved club and roster', () async {
    storedBackup = playerBackup('Asha').encode();
    final store = MatchStore();
    await store.load();

    expect(store.clubs, hasLength(1));
    expect(store.clubs.single.name, 'Gully CC');
    expect(store.roster, hasLength(1));
    expect(store.roster.single.name, 'Asha');
    expect(store.restoredFromBackup, isTrue);
    expect(store.lastBackupAt, isNotNull);
  });

  test('a settings-only snapshot never populates a fresh install', () async {
    storedBackup = BackupSnapshot(
      savedAt: DateTime.utc(2026, 10, 2),
      values: {MatchStore.kTheme: 'dark'},
    ).encode();
    final store = MatchStore();
    await store.load();

    expect(store.restoredFromBackup, isFalse);
    expect(store.themeId, 'light');
    expect(store.roster, isEmpty);
  });

  test('existing data is never overwritten by first-boot restore', () async {
    SharedPreferences.setMockInitialValues({
      MatchStore.kTheme: 'dark',
      MatchStore.kRoster: rosterJson('Existing'),
    });
    storedBackup = playerBackup('From backup').encode();
    final store = MatchStore();
    await store.load();

    expect(store.restoredFromBackup, isFalse);
    expect(store.roster.single.name, 'Existing');
  });

  test('backupNow writes the live store to both destinations', () async {
    SharedPreferences.setMockInitialValues({
      MatchStore.kClubs: clubsJson(),
      MatchStore.kRoster: rosterJson('Asha'),
    });
    final store = MatchStore();
    final ok = await store.backupNow();

    expect(ok, isTrue);
    expect(store.lastBackupAt, isNotNull);
    expect(store.lastBackupDownloadsPath, contains('/Download/CricScore/'));
    final saved = BackupSnapshot.decode(storedBackup!);
    expect(saved, isNotNull);
    expect(saved!.values[MatchStore.kRoster], contains('Asha'));
  });

  test('an empty store never writes or clobbers a backup', () async {
    storedBackup = playerBackup('Keep me').encode();
    final before = storedBackup;
    final store = MatchStore();
    final ok = await store.backupNow();

    expect(ok, isFalse);
    expect(store.lastBackupError, isNull);
    expect(storedBackup, before);
    final saved = BackupSnapshot.decode(storedBackup!);
    expect(saved!.values[MatchStore.kRoster], contains('Keep me'));
  });

  test('manual restore replaces old players and settings', () async {
    SharedPreferences.setMockInitialValues({
      MatchStore.kClubs: clubsJson(),
      MatchStore.kRoster: rosterJson('Old name'),
      MatchStore.kTheme: 'dark',
    });
    storedBackup = playerBackup('New name', theme: 'light').encode();
    final store = MatchStore();
    await store.load();
    expect(store.roster.single.name, 'Old name');

    final result = await store.restoreLatestBackup();

    expect(result.ok, isTrue);
    expect(store.roster.single.name, 'New name');
    expect(store.themeId, 'light');
    expect(store.restoredFromBackup, isFalse);
  });

  test('restore refuses a file that is not ours', () async {
    storedBackup = '{"hello":"world"}';
    final store = MatchStore();
    final result = await store.restoreLatestBackup();

    expect(result.ok, isFalse);
    expect(result.message, contains('not a CricScore backup'));
  });
}
