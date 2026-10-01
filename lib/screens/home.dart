import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../store.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  final MatchStore store;
  const HomeScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final hasLive = store.match != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('GULLY CRICKET SCORER',
                style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                icon: Icon(store.themeId == 'dark'
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                tooltip: 'Light / dark',
                onPressed: () => store.toggleTheme(),
              ),
            ],
          ),
          body: ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ShadCard(
                  title: const Text('🏏 Gully Scorer',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  description: const Text(
                      'Sports utility for umpires. 100% offline.'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShadButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/setup'),
                          child: Text(hasLive
                              ? 'START NEW MATCH'
                              : 'START NEW MATCH'),
                        ),
                        if (hasLive) ...[
                          const SizedBox(height: 10),
                          ShadButton.secondary(
                            onPressed: () {
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
                                'RESUME • ${store.innings!.battingTeam} ${store.innings!.runs}/${store.innings!.wickets}'),
                          ),
                        ],
                        const SizedBox(height: 10),
                        ShadButton.outline(
                          onPressed: () =>
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
        );
      },
    );
  }
}
