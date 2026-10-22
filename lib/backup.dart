import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One point-in-time copy of every `cricket_*` preference: club, roster,
/// profiles, live match, sheets, archives, appearances and settings.
///
/// The format is deliberately plain JSON and versioned. A future release must
/// keep reading older snapshots; that is the whole point of a backup.
class BackupSnapshot {
  static const appTag = 'cricscore';
  static const format = 1;

  final DateTime savedAt;
  final Map<String, Object?> values;

  const BackupSnapshot({required this.savedAt, required this.values});

  Map<String, Object?> toJson() => {
    'app': appTag,
    'format': format,
    'savedAt': savedAt.toIso8601String(),
    'values': values,
  };

  String encode() => jsonEncode(toJson());

  /// Returns null for anything that is not one of our snapshots. A corrupt
  /// file must never be able to crash or half-apply during boot.
  static BackupSnapshot? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['app'] != appTag) return null;
      final version = decoded['format'];
      if (version is! int || version < 1 || version > format) return null;
      final rawValues = decoded['values'];
      if (rawValues is! Map) return null;
      final values = <String, Object?>{};
      for (final entry in rawValues.entries) {
        final key = entry.key.toString();
        // Only our own keys. Never import a setting from a foreign app or a
        // future format we do not understand.
        if (!key.startsWith('cricket_')) continue;
        final value = entry.value;
        if (value is String ||
            value is bool ||
            value is int ||
            value is double) {
          values[key] = value;
        } else if (value is List && value.every((e) => e is String)) {
          values[key] = value.cast<String>();
        }
      }
      if (values.isEmpty) return null;
      final at =
          DateTime.tryParse((decoded['savedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return BackupSnapshot(savedAt: at, values: values);
    } catch (_) {
      return null;
    }
  }

  /// True when the snapshot carries something the scorer would miss: a club,
  /// player, profile, archive or live match. Settings alone are not worth
  /// restoring over a newer backup.
  bool hasAny(Iterable<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value is String) {
        if (value.isNotEmpty && value != '[]' && value != '{}') return true;
      } else if (value != null) {
        return true;
      }
    }
    return false;
  }
}

class BackupWriteResult {
  final bool ok;
  final String? path;
  final String? downloadsPath;
  final String? error;

  const BackupWriteResult({
    required this.ok,
    this.path,
    this.downloadsPath,
    this.error,
  });

  static const unsupported = BackupWriteResult(
    ok: false,
    error: 'backup is not supported on this platform',
  );
}

class BackupRestore {
  final bool ok;
  final String message;
  final DateTime? savedAt;

  const BackupRestore(this.ok, this.message, {this.savedAt});
}

/// Thin bridge to the Android side. Both paths are tried there:
///   1. app-specific external files — guaranteed, survives updates, pullable
///      with adb (`/sdcard/Android/data/<pkg>/files/backups/...`);
///   2. public Downloads/CricScore — survives an uninstall, used for the
///      fresh-install auto-restore.
///
/// Every call is best-effort. A missing plugin (tests/desktop) or a storage
/// failure must never stop scoring or booting.
class BackupService {
  static const channelName = 'com.gully.cricket/backup';
  static const fileName = 'cricscore-backup.json';
  static const _timeout = Duration(seconds: 6);

  static const MethodChannel _channel = MethodChannel(channelName);

  static Future<BackupWriteResult> write(BackupSnapshot snapshot) async {
    try {
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('writeBackup', {
            'name': fileName,
            'content': snapshot.encode(),
          })
          .timeout(_timeout);
      if (result == null) {
        return const BackupWriteResult(ok: false, error: 'no response');
      }
      return BackupWriteResult(
        ok: result['ok'] == true,
        path: result['path']?.toString(),
        downloadsPath: result['downloadsPath']?.toString(),
        error: result['error']?.toString(),
      );
    } on MissingPluginException {
      return BackupWriteResult.unsupported;
    } catch (e) {
      debugPrint('BACKUP: write failed: $e');
      return BackupWriteResult(ok: false, error: e.toString());
    }
  }

  /// Latest snapshot, preferring the app copy then public Downloads.
  static Future<String?> read() async {
    try {
      return await _channel
          .invokeMethod<String>('readBackup')
          .timeout(_timeout);
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('BACKUP: read failed: $e');
      return null;
    }
  }

  /// System file picker fallback, for a backup copied off the phone.
  static Future<String?> pick() async {
    try {
      return await _channel.invokeMethod<String>('pickBackup');
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('BACKUP: pick failed: $e');
      return null;
    }
  }
}
