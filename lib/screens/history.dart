import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../math.dart';
import '../models.dart';
import '../store.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  final MatchStore store;
  const HistoryScreen(this.store, {super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Match>> fut;
  @override
  void initState() {
    super.initState();
    fut = widget.store.history();
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
                setState(() => fut = widget.store.history());
              }),
        ],
      ),
      body: ResponsiveCenter(
        child: FutureBuilder<List<Match>>(
          future: fut,
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator());
            }
            final h = snap.data!;
            if (h.isEmpty) {
              return const Center(
                  child: Text(
                      'No saved matches.\nCompleted matches save offline.',
                      textAlign: TextAlign.center));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: h.length,
              itemBuilder: (_, i) {
                final m = h[i];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4),
                  child: ShadCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              ShadBadge(
                                  child: Text(
                                      '${m.winner} WON',
                                      style: const TextStyle(
                                          fontSize: 10))),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const TeamDot(
                                      MatchStore.teamAColor,
                                      size: 9),
                                  const SizedBox(width: 5),
                                  Flexible(
                                      child: Text(
                                          '${m.config.teamA} vs ${m.config.teamB}',
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w800))),
                                  const SizedBox(width: 5),
                                  const TeamDot(
                                      MatchStore.teamBColor,
                                      size: 9),
                                ],
                              ),
                              Text(
                                  '${m.innings1.battingTeam}: ${m.innings1.runs}/${m.innings1.wickets} (${CricketMath.ballsToOvers(m.innings1.legalDeliveries)})${m.innings2 == null ? '' : ' • ${m.innings2!.battingTeam}: ${m.innings2!.runs}/${m.innings2!.wickets}'}',
                                  style: const TextStyle(
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                            icon: const Icon(
                                Icons.delete_outline,
                                size: 20),
                            onPressed: () async {
                              await widget.store
                                  .deleteHistoryAt(i);
                              setState(() =>
                                  fut = widget.store.history());
                            }),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
