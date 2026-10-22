import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backup.dart';
import '../ports/sync_port.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  final MatchStore store;
  const HomeScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, _) {
        final hasLive = store.match != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'CRICSCORE',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  store.themeId == 'dark' ? Icons.light_mode : Icons.dark_mode,
                ),
                tooltip: 'Light / dark',
                onPressed: () => store.toggleTheme(),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => _settingsSheet(context),
              ),
            ],
          ),
          body: SafeArea(
            child: ResponsiveCenter(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (store.needsRestorePrompt &&
                      store.roster.isEmpty &&
                      store.clubs.isEmpty &&
                      store.match == null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.settings_backup_restore),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'RESTORE A BACKUP?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'If you reinstalled CricScore, pick the backup JSON from Downloads to bring back your clubs, players and matches.',
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _restoreFromFile(context),
                                    icon: const Icon(
                                      Icons.folder_open,
                                      size: 18,
                                    ),
                                    label: const Text('RESTORE FROM FILE…'),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              onPressed: store.dismissRestorePrompt,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (store.restoredFromBackup) ...[
                    Card(
                      color: Theme.of(context).colorScheme.primary,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.restore,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'DATA RESTORED FROM BACKUP',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              onPressed: store.acknowledgeRestore,
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.sports_cricket,
                            size: 44,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Umpire scorer • 100% offline',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          RectBtn(
                            onTap: () => Navigator.pushNamed(context, '/setup'),
                            child: const Text('START NEW MATCH'),
                          ),
                          if (hasLive) ...[
                            const SizedBox(height: 10),
                            RectBtn(
                              primary: false,
                              onTap: () {
                                final m = store.match!;
                                if (m.completed) {
                                  Navigator.pushNamed(context, '/result');
                                } else if (m.currentInnings == 1 &&
                                    m.innings1.completed) {
                                  Navigator.pushNamed(context, '/break');
                                } else {
                                  Navigator.pushNamed(context, '/scoring');
                                }
                              },
                              child: Text(
                                'RESUME • ${store.innings!.battingTeam} ${store.innings!.runs}/${store.innings!.wickets}',
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          RectBtn(
                            primary: false,
                            onTap: () => Navigator.pushNamed(context, '/join'),
                            child: const Text('WATCH LIVE SCORE'),
                          ),
                          const SizedBox(height: 10),
                          RectBtn(
                            primary: false,
                            onTap: () => Navigator.pushNamed(context, '/club'),
                            child: const Text('CLUB + PLAYERS'),
                          ),
                          const SizedBox(height: 10),
                          RectBtn(
                            primary: false,
                            onTap: () =>
                                Navigator.pushNamed(context, '/history'),
                            child: const Text('ARCHIVES'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// One line that names the state and, when there is one, the real error.
  String _syncStatus() {
    final err = store.onlineError;
    final label = switch (store.onlineState) {
      SyncState.unconfigured => 'Not configured in this build',
      SyncState.offline => 'Offline',
      SyncState.connecting => 'Connecting…',
      SyncState.ready => 'Connected',
      SyncState.error => 'Error',
    };
    return err == null || err.isEmpty ? label : '$label — $err';
  }

  Future<bool> _confirmRestore(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<BackupRestore> _restoreFromFile(BuildContext context) async {
    final result = await store.restoreFromPickedBackup();
    if (!context.mounted) return result;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    return result;
  }

  void _settingsSheet(BuildContext context) {
    showAppSheet(
      context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ListenableBuilder(
        listenable: store,
        builder: (_, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SETTINGS',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Styles • ${StylePreset.of(store.styleId).name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in StylePreset.ids)
                          ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: StylePreset.of(id).heroBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black26),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(StylePreset.of(id).name),
                              ],
                            ),
                            selected: store.styleId == id,
                            onSelected: (_) => store.setStyle(id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Score font • ${ScoreFonts.names[store.fontId]}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in ScoreFonts.ids)
                          ChoiceChip(
                            label: Text(
                              '142/7',
                              style: TextStyle(
                                fontFamily: ScoreFonts.family(id),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            selected: store.fontId == id,
                            onSelected: (_) => store.setFont(id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Celebrations • ${MatchStore.celebNames[store.celebId]}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final id in MatchStore.celebIds)
                          ChoiceChip(
                            label: Text(MatchStore.celebNames[id]!),
                            selected: store.celebId == id,
                            onSelected: (_) => store.setCeleb(id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: true,
                  title: Text(
                    'Wickets • ${store.complexWickets ? 'Complex' : 'Simple'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Simple')),
                        ButtonSegment(value: true, label: Text('Complex')),
                      ],
                      selected: {store.complexWickets},
                      onSelectionChanged: (s) =>
                          store.setComplexWickets(s.first),
                    ),
                    const Text(
                      'Simple: Wicket + Run Out. Complex: full grid.',
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Sounds & extras',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Arcade sounds'),
                      subtitle: const Text('Single quick bleeps'),
                      value: store.soundOn,
                      onChanged: (v) => store.setSound(v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Haptics'),
                      subtitle: const Text('Vibration by impact'),
                      value: store.hapticsOn,
                      onChanged: (v) => store.setHaptics(v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Advanced extras'),
                      subtitle: const Text('Extra detail keys'),
                      value: store.advancedExtras,
                      onChanged: (v) => store.setAdvancedExtras(v),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dark mode'),
                  value: store.themeId == 'dark',
                  onChanged: (v) => store.setTheme(v ? 'dark' : 'light'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ask who took the catch'),
                  subtitle: const Text(
                    'Optional fielder on wickets. Off = fastest.',
                  ),
                  value: store.askFielder,
                  onChanged: (v) => store.setAskFielder(v),
                ),
                // Live-backend status, verbatim. A sharing failure on a gully
                // ground must be diagnosable without a laptop, and the first
                // cut of this feature reported every error as "no backend
                // configured", which pointed at the wrong thing entirely.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Live sharing (backend)'),
                  subtitle: Text(
                    _syncStatus(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: store.onlineState == SyncState.ready,
                  onChanged: store.onlineState == SyncState.unconfigured
                      ? null
                      : (_) => store.sync.init(),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Data backup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    store.lastBackupAt == null
                        ? 'Auto-saves to Downloads/CricScore'
                        : 'Last ${DateFormat('d MMM, HH:mm').format(store.lastBackupAt!.toLocal())} • ${store.backupLocationLabel}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Every change is copied to Downloads/CricScore/cricscore-backup.json. A fresh install restores it automatically.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await store.backupNow();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Backup saved to Downloads/CricScore/'
                                        : store.lastBackupError == null
                                        ? 'Nothing to back up yet'
                                        : 'Backup skipped — ${store.lastBackupError}',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.save_alt, size: 18),
                            label: const Text('BACK UP NOW'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final yes = await _confirmRestore(
                                context,
                                title: 'Restore backup?',
                                body: 'This replaces the current clubs, players, live match and archives with the latest backup on this device.',
                              );
                              if (!yes) return;
                              final result = await store.restoreLatestBackup();
                              if (!context.mounted) return;
                              if (result.ok) Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            },
                            icon: const Icon(Icons.restore, size: 18),
                            label: const Text('RESTORE'),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final yes = await _confirmRestore(
                            context,
                            title: 'Restore from file?',
                            body: 'Pick a CricScore backup JSON. This replaces the current clubs, players, live match and archives.',
                          );
                          if (!yes || !context.mounted) return;
                          final result = await _restoreFromFile(context);
                          if (!context.mounted) return;
                          if (result.ok) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('RESTORE FROM FILE…'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
