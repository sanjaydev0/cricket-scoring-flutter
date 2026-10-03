import 'package:flutter/material.dart';
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
                    ? Icons.light_mode
                    : Icons.dark_mode),
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
          body: ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('🏏',
                            style: TextStyle(fontSize: 44),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        const Text('Umpire scorer • 100% offline',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/setup'),
                          child: const Text('START NEW MATCH'),
                        ),
                        if (hasLive) ...[
                          const SizedBox(height: 10),
                          FilledButton.tonal(
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
                        OutlinedButton(
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

  void _settingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('SETTINGS',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                SwitchListTile(
                  title: const Text('Arcade sounds'),
                  subtitle: const Text('Bleeps for keys & wickets'),
                  value: store.soundOn,
                  onChanged: (v) => store.setSound(v),
                ),
                SwitchListTile(
                  title: const Text('Advanced extras'),
                  subtitle: const Text('WD+overthrows, byes, NB+runs keys'),
                  value: store.advancedExtras,
                  onChanged: (v) => store.setAdvancedExtras(v),
                ),
                SwitchListTile(
                  title: const Text('Dark mode'),
                  value: store.themeId == 'dark',
                  onChanged: (v) =>
                      store.setTheme(v ? 'dark' : 'light'),
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
