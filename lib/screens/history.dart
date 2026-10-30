import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../math.dart';
import '../domain/players.dart';
import '../models.dart';
import '../store.dart';
import 'match_detail.dart';
import 'summary.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  final MatchStore store;
  const HistoryScreen(this.store, {super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> fut;
  @override
  void initState() {
    super.initState();
    fut = widget.store.historyRecords();
  }

  /// Archives are the only copy of a finished match on this phone, so every
  /// destructive control asks first. One mis-tap on a list row used to delete
  /// a match permanently with no way back.
  Future<bool> _confirm({required String title, required String body}) async {
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    return yes == true;
  }

  String _dateLine(Match m) {
    final raw = (m.toJson()['savedAt'] ?? m.createdAt).toString();
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('EEE, d MMM • h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ARCHIVES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Delete all archives',
            onPressed: () async {
              final yes = await _confirm(
                title: 'Delete all archives?',
                body: 'Every saved match on this phone is removed. Clubs, players and any live match stay as they are. This cannot be undone.',
              );
              if (!yes || !mounted) return;
              await widget.store.clearHistory();
              setState(() => fut = widget.store.historyRecords());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 640,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: fut,
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final h = snap.data!;
              if (h.isEmpty) {
                return const _EmptyArchives();
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: h.length,
                itemBuilder: (_, i) {
                  final m = Match.fromJson(h[i]);
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArchiveDetail(
                            match: m,
                            sheets: MatchStore.sheetsFromRecord(h[i]),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          const TeamDot(MatchStore.teamAColor, size: 9),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${m.config.teamA} vs ${m.config.teamB}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const TeamDot(MatchStore.teamBColor, size: 9),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateLine(m),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${m.winner} WON • ${m.innings1.battingTeam}: ${m.innings1.runs}/${m.innings1.wickets} (${CricketMath.ballsToOvers(m.innings1.legalDeliveries)})${m.innings2 == null ? '' : ' • ${m.innings2!.battingTeam}: ${m.innings2!.runs}/${m.innings2!.wickets}'}',
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete this match',
                        onPressed: () async {
                          final yes = await _confirm(
                            title:
                                'Delete ${m.config.teamA} vs ${m.config.teamB}?',
                            body: 'The full scorecard for this match is removed from the archives. This cannot be undone.',
                          );
                          if (!yes || !mounted) return;
                          await widget.store.deleteHistoryAt(i);
                          setState(() => fut = widget.store.historyRecords());
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// An empty archive is a normal state, not an error: it says what will appear
/// here and how matches get there, instead of one grey line in dead centre.
class _EmptyArchives extends StatelessWidget {
  const _EmptyArchives();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 44,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'NO SAVED MATCHES',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            Text(
              'Every match you finish lands here, with its full scorecard and player figures.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full archived-match view.
///
/// It renders the same [MatchDetail] as the live scorecard — header with both
/// scores, team pills that switch innings, flat tables, and a SUMMARY tab with
/// the top performers. The old layout stacked both innings' card AND a wall of
/// coloured ball badges; one innings at a time is what a phone can carry, and
/// the ball-by-ball is one link away.
///
/// Sheets ride in the archive record (new matches). Records that predate
/// player tracking render totals only, never empty tables. A throwaway store
/// carries the archived match so every summary widget reuses verbatim;
/// awards render read-only so nothing can write prefs through it.
class ArchiveDetail extends StatelessWidget {
  final Match match;
  final Map<String, InningsSheet> sheets;
  const ArchiveDetail({required this.match, this.sheets = const {}, super.key});

  MatchStore _ghost() {
    final g = MatchStore();
    g.match = match;
    g.sheets = sheets;
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final g = _ghost();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${m.config.teamA} vs ${m.config.teamB}',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MatchDetail(store: g, initialInnings: 1, showBallsLink: true),
                if (sheets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AwardsView(store: g, readOnly: true),
                  const SizedBox(height: 12),
                  RectBtn(
                    primary: false,
                    onTap: () => shareScorecard(context, g),
                    child: const Text('COPY SCORECARD (WHATSAPP)'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
