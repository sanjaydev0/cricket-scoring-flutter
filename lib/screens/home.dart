import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backup.dart';
import '../math.dart';
import '../models.dart';
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
          appBar: RectAppBar(
            title: 'CRICSCORE',
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
                padding: EdgeInsets.all(context.spacing.md),
                children: [
                  if (store.needsRestorePrompt &&
                      store.roster.isEmpty &&
                      store.clubs.isEmpty &&
                      store.match == null) ...[
                    _RestorePrompt(
                      onRestore: () => _restoreFromFile(context),
                      onDismiss: store.dismissRestorePrompt,
                    ),
                    SizedBox(height: context.spacing.sm),
                  ],
                  if (store.restoredFromBackup) ...[
                    _RestoredBanner(onDismiss: store.acknowledgeRestore),
                    SizedBox(height: context.spacing.sm),
                  ],
                  _Masthead(store: store),
                  if (hasLive) ...[
                    SizedBox(height: context.spacing.sm),
                    _LiveCard(store: store),
                  ],
                  SizedBox(height: context.spacing.md),
                  SizedBox(
                    height: 60,
                    child: RectBtn(
                      onTap: () => Navigator.pushNamed(context, '/setup'),
                      child: const Text(
                        'START NEW MATCH',
                        style: TextStyle(fontSize: 15, letterSpacing: 0.8),
                      ),
                    ),
                  ),
                  _RematchButton(store: store, hasLive: hasLive),
                  SizedBox(height: context.spacing.lg),
                  RowSectionLabel('MANAGE', color: context.tokens.mutedInk),
                  Row(
                    children: [
                      Expanded(
                        child: RectBtn(
                          primary: false,
                          onTap: () => Navigator.pushNamed(context, '/club'),
                          child: const Text('CLUB + PLAYERS'),
                        ),
                      ),
                      SizedBox(width: context.spacing.sm),
                      Expanded(
                        child: RectBtn(
                          primary: false,
                          onTap: () => Navigator.pushNamed(context, '/history'),
                          child: const Text('ARCHIVES'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          RectBtn(
            primary: false,
            onTap: () => Navigator.pop(dctx, false),
            child: const Text('CANCEL'),
          ),
          RectBtn(
            onTap: () => Navigator.pop(dctx, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    return yes == true;
  }

  Future<BackupRestore> _restoreFromFile(BuildContext context) async {
    final raw = await BackupService.pick();
    if (raw == null || raw.isEmpty) {
      return const BackupRestore(false, 'No file selected');
    }
    final snap = BackupSnapshot.decode(raw);
    if (snap == null || !snap.hasAny(MatchStore.userDataKeys)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file is not a CricScore backup')),
        );
      }
      return const BackupRestore(false, 'That file is not a CricScore backup');
    }
    if (!context.mounted) {
      return const BackupRestore(false, 'Restore cancelled');
    }
    final yes = await _confirmRestore(
      context,
      title: 'Restore this backup?',
      body:
          'Backup from ${DateFormat('d MMM yyyy, HH:mm').format(snap.savedAt.toLocal())}. This replaces the current clubs, players, live match and archives.',
    );
    if (!yes || !context.mounted) {
      return const BackupRestore(false, 'Restore cancelled');
    }
    final result = await store.restorePickedBackup(raw);
    if (!context.mounted) return result;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    return result;
  }

  /// Settings is a bento list, not a form: four labelled groups of cards, one
  /// scroll, nothing collapsed. An `ExpansionTile` hid half the app behind a
  /// chevron and looked like stock Material doing it.
  void _settingsSheet(BuildContext context) {
    showAppSheet(
      context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: store,
        builder: (_, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(
                  title: 'Settings',
                  caption: 'Everything stays on this phone',
                  onClose: () => Navigator.of(ctx).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RowSectionLabel('LOOK', color: context.tokens.mutedInk),
                      RectCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FieldLabel('STYLE'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // The one place outside the scoreboard that
                                // reads a preset — a swatch has to show the
                                // preset it selects, not the chrome colour.
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
                                            border: Border.all(
                                              color: context.tokens.borderRow,
                                            ),
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
                            const SizedBox(height: 14),
                            _FieldLabel('SCORE FONT'),
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
                            const SizedBox(height: 14),
                            _FieldLabel('CELEBRATIONS'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final id in MatchStore.celebIds)
                                  ChoiceChip(
                                    label: Text(MatchStore.celebNames[id]!),
                                    selected: store.celebId == id,
                                    onSelected: (_) => store.setCeleb(id),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      RowSectionLabel(
                        'SCORING',
                        color: context.tokens.mutedInk,
                      ),
                      RectCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            const SettingsRow(
                              label: 'Wicket picker',
                              subtitle: 'Simple: Wicket + Run Out. Complex: full grid.',
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      label: Text('Simple'),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('Complex'),
                                    ),
                                  ],
                                  selected: {store.complexWickets},
                                  onSelectionChanged: (s) =>
                                      store.setComplexWickets(s.first),
                                ),
                              ),
                            ),
                            SettingsRow(
                              label: 'Advanced extras',
                              subtitle: 'Extra detail keys',
                              trailing: RectToggle(
                                value: store.advancedExtras,
                                semanticsLabel: 'Advanced extras',
                                onChanged: (v) => store.setAdvancedExtras(v),
                              ),
                            ),
                            SettingsRow(
                              label: 'Ask who took the catch',
                              subtitle:
                                  'Optional fielder on wickets. Off = fastest.',
                              last: true,
                              trailing: RectToggle(
                                value: store.askFielder,
                                semanticsLabel: 'Ask who took the catch',
                                onChanged: (v) => store.setAskFielder(v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RowSectionLabel('DEVICE', color: context.tokens.mutedInk),
                      RectCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SettingsRow(
                              label: 'Arcade sounds',
                              subtitle: 'Single quick bleeps',
                              trailing: RectToggle(
                                value: store.soundOn,
                                semanticsLabel: 'Arcade sounds',
                                onChanged: (v) => store.setSound(v),
                              ),
                            ),
                            SettingsRow(
                              label: 'Haptics',
                              subtitle: 'Vibration by impact',
                              trailing: RectToggle(
                                value: store.hapticsOn,
                                semanticsLabel: 'Haptics',
                                onChanged: (v) => store.setHaptics(v),
                              ),
                            ),
                            SettingsRow(
                              label: 'Battery saver',
                              subtitle: 'No celebration; silent backup only on pause/over end',
                              trailing: RectToggle(
                                value: store.batterySaver,
                                semanticsLabel: 'Battery saver',
                                onChanged: (v) => store.setBatterySaver(v),
                              ),
                            ),
                            SettingsRow(
                              label: 'Dark mode',
                              subtitle: 'Same instrument, night ink',
                              last: true,
                              trailing: RectToggle(
                                value: store.themeId == 'dark',
                                semanticsLabel: 'Dark mode',
                                onChanged: (v) =>
                                    store.setTheme(v ? 'dark' : 'light'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RowSectionLabel('DATA', color: context.tokens.mutedInk),
                      RectCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SettingsRow(
                              label: 'Automatic backup',
                              icon: Icons.save_alt,
                              subtitle: store.lastBackupAt == null
                                  ? 'Auto-saves to Downloads/CricScore'
                                  : 'Last ${DateFormat('d MMM, HH:mm').format(store.lastBackupAt!.toLocal())} • ${store.backupLocationLabel}',
                              last: true,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Every change is copied to Downloads/CricScore/cricscore-backup.json. Updates restore it automatically. After a reinstall, tap RESTORE FROM FILE… and pick it.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      color: context.tokens.mutedInk,
                                    ),
                                  ),
                                  SizedBox(height: context.spacing.sm),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: RectBtn(
                                          primary: false,
                                          onTap: () async {
                                            final ok = await store.backupNow();
                                            if (!ctx.mounted) return;
                                            ScaffoldMessenger.of(
                                              ctx,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  ok
                                                      ? 'Backup saved to Downloads/CricScore/'
                                                      : store.lastBackupError ==
                                                            null
                                                      ? 'Nothing to back up yet'
                                                      : 'Backup skipped — ${store.lastBackupError}',
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text('BACK UP NOW'),
                                        ),
                                      ),
                                      SizedBox(width: context.spacing.sm),
                                      Expanded(
                                        child: RectBtn(
                                          primary: false,
                                          onTap: () async {
                                            final yes = await _confirmRestore(
                                              ctx,
                                              title: 'Restore backup?',
                                              body: 'This replaces the current clubs, players, live match and archives with the latest backup on this device.',
                                            );
                                            if (!yes) return;
                                            final result = await store
                                                .restoreLatestBackup();
                                            if (!ctx.mounted) return;
                                            if (result.ok) {
                                              Navigator.of(ctx).pop();
                                            }
                                            ScaffoldMessenger.of(
                                              ctx,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(result.message),
                                              ),
                                            );
                                          },
                                          child: const Text('RESTORE'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: context.spacing.sm),
                                  RectBtn(
                                    primary: false,
                                    onTap: () async {
                                      final result = await _restoreFromFile(
                                        ctx,
                                      );
                                      if (!ctx.mounted) return;
                                      if (result.ok) Navigator.of(ctx).pop();
                                    },
                                    child: const Text('RESTORE FROM FILE…'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.spacing.md),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A micro-label above a control cluster inside a settings card.
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: context.tokens.mutedInk,
      ),
    ),
  );
}

/// The identity plate: what the app is, and how much is already in it.
///
/// Counts instead of a marketing line — a scorer opening the app wants to know
/// whether his club is there, not what the app promises.
class _Masthead extends StatelessWidget {
  final MatchStore store;
  const _Masthead({required this.store});

  @override
  Widget build(BuildContext context) {
    final players = store.roster.length;
    final clubs = store.clubs.length;
    final counts = [
      'OFFLINE',
      players == 1 ? '1 PLAYER' : '$players PLAYERS',
      clubs == 1 ? '1 CLUB' : '$clubs CLUBS',
    ].join('  ·  ');
    return RectCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.sports_cricket, size: 24, color: context.tokens.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'UMPIRE SCORER',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  counts,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: context.tokens.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The live match, inverted: the one card on Home that is a "go" surface.
class _LiveCard extends StatelessWidget {
  final MatchStore store;
  const _LiveCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final m = store.match!;
    final inn = store.innings;
    final ink = context.tokens.onPrimaryFill;
    final label = m.completed
        ? 'MATCH COMPLETE'
        : inn == null
        ? 'NOT STARTED'
        : 'LIVE  ·  INNINGS ${m.currentInnings}';
    final headline = inn == null
        ? '${m.config.teamA} vs ${m.config.teamB}'
        : inn.battingTeam;
    final meta = inn == null
        ? '${m.config.totalOvers} OVERS  ·  TAP TO SET UP'
        : '${CricketMath.ballsToOvers(inn.legalDeliveries)} OVERS  ·  CRR '
              '${CricketMath.calcCRR(inn.runs, inn.legalDeliveries)}';
    return RectCard(
      inverted: true,
      onTap: () {
        if (m.completed) {
          Navigator.pushNamed(context, '/result');
        } else if (m.currentInnings == 1 && m.innings1.completed) {
          Navigator.pushNamed(context, '/break');
        } else {
          Navigator.pushNamed(context, '/scoring');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              if (inn != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${inn.runs}/${inn.wickets}',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: ink,
                  ),
                ),
              ],
              Icon(Icons.chevron_right, size: 22, color: ink),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only when the phone has no data at all — the reinstall case.
class _RestorePrompt extends StatelessWidget {
  final VoidCallback onRestore;
  final VoidCallback onDismiss;
  const _RestorePrompt({required this.onRestore, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return RectCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_backup_restore,
                size: 20,
                color: context.tokens.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RESTORE A BACKUP?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              'If you reinstalled CricScore, pick cricscore-backup.json from Downloads/CricScore to bring back your clubs, players and matches.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: context.tokens.mutedInk,
              ),
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: RectBtn(
              primary: false,
              onTap: onRestore,
              child: const Text('RESTORE FROM FILE…'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation that a restore landed. Inverted, because it is a result.
class _RestoredBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _RestoredBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final ink = context.tokens.onPrimaryFill;
    return RectCard(
      inverted: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          Icon(Icons.restore, size: 20, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DATA RESTORED FROM BACKUP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 20, color: ink),
          ),
        ],
      ),
    );
  }
}

/// Home rematch: session-first (finished live match), archive-fallback
/// (newest archived match). Hidden while a match is mid-play — Resume is
/// the action then — and when there's nothing to redo.
class _RematchButton extends StatelessWidget {
  final MatchStore store;
  final bool hasLive;
  const _RematchButton({required this.store, required this.hasLive});

  @override
  Widget build(BuildContext context) {
    final m = store.match;
    final sessionCfg = (m != null && m.completed) ? m.config : null;
    if (hasLive && sessionCfg == null) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: sessionCfg != null ? null : store.historyRecords(),
      builder: (context, snap) {
        if (sessionCfg == null) {
          if (!snap.hasData || snap.data!.isEmpty) {
            return const SizedBox.shrink();
          }
        }
        final cfg = sessionCfg ?? Match.fromJson(snap.data!.first).config;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: context.spacing.sm),
            RectBtn(
              primary: false,
              onTap: () {
                store.prepareRematch(cfg);
                store.newMatch();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/setup',
                  (r) => r.isFirst,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('REMATCH'),
                  Text(
                    '${cfg.teamA} vs ${cfg.teamB} • ${cfg.totalOvers} OVERS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
