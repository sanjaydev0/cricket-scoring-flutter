import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../math.dart';
import '../domain/players.dart';
import '../models.dart';
import '../store.dart';
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
              onPressed: () async {
                await widget.store.clearHistory();
                setState(() => fut = widget.store.historyRecords());
              }),
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
                    return const Center(child: Text('No saved matches.'));
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
                                    sheets: MatchStore.sheetsFromRecord(h[i]))),
                          ),
                          title: Row(
                            children: [
                              const TeamDot(MatchStore.teamAColor, size: 9),
                              const SizedBox(width: 5),
                              Flexible(
                                  child: Text(
                                      '${m.config.teamA} vs ${m.config.teamB}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              const SizedBox(width: 5),
                              const TeamDot(MatchStore.teamBColor, size: 9),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_dateLine(m),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${m.winner} WON • ${m.innings1.battingTeam}: ${m.innings1.runs}/${m.innings1.wickets} (${CricketMath.ballsToOvers(m.innings1.legalDeliveries)})${m.innings2 == null ? '' : ' • ${m.innings2!.battingTeam}: ${m.innings2!.runs}/${m.innings2!.wickets}'}'),
                            ],
                          ),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await widget.store.deleteHistoryAt(i);
                                setState(
                                    () => fut = widget.store.historyRecords());
                              }),
                        ),
                      );
                    },
                  );
                },
              ))),
    );
  }
}

/// Full archived-match view: hero, innings pills, scorecard, balls,
/// performers, awards — the same sections as the live result page.
///
/// Sheets ride in the archive record (new matches). Records that predate
/// player tracking render totals + balls only, never empty tables. A throwaway
/// store carries the archived match so every summary widget reuses verbatim;
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
    final tracked = sheets.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
          title: Text('${m.config.teamA} vs ${m.config.teamB}',
              style: const TextStyle(fontSize: 15))),
      body: SafeArea(
          child: ResponsiveCenter(
              maxWidth: 640,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                              m.winner == null
                                  ? 'MATCH SAVED'
                                  : m.winner == 'TIE'
                                      ? 'MATCH TIED'
                                      : '${m.winner} WON',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          Text(m.winMargin ?? ''),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _inningsCard(m.innings1, 1, m.config.totalOvers),
                  if (m.innings2 != null) ...[
                    const SizedBox(height: 8),
                    _inningsCard(m.innings2!, 2, m.config.totalOvers),
                  ],
                  if (tracked) ...[
                    const SizedBox(height: 8),
                    ResultScorecard(store: g),
                    const SizedBox(height: 12),
                    TopPerformersView(store: g),
                    const SizedBox(height: 12),
                    AwardsView(store: g, readOnly: true),
                    const SizedBox(height: 12),
                    RectBtn(
                      primary: false,
                      onTap: () => shareScorecard(context, g),
                      child: const Text('COPY SCORECARD (WHATSAPP)'),
                    ),
                  ],
                ],
              ))),
    );
  }

  Widget _inningsCard(Innings inn, int idx, int totalOvers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'INNINGS $idx // ${inn.battingTeam} ${inn.runs}/${inn.wickets} (${CricketMath.ballsToOvers(inn.legalDeliveries)} ov)',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 8),
            for (final o in inn.overs)
              if (o.balls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 36,
                          child: Text('O${o.overNumber}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [for (final b in o.balls) BallBadge(b)],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
