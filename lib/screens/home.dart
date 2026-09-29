import 'package:flutter/material.dart';
import '../store.dart';

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
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            actions: [
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                onPressed: () => _themeSheet(context),
                tooltip: 'Theme',
              ),
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () =>
                    Navigator.pushNamed(context, '/history'),
                tooltip: 'Archives',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('🏏',
                          style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      Text('SUNLIGHT-READY SCORING',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      const Text('100% offline • big keys • undo',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/setup'),
                          child: Text(hasLive
                              ? 'NEW MATCH (ends current)'
                              : 'START NEW MATCH'),
                        ),
                      ),
                      if (hasLive) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/scoring'),
                            child: const Text('RESUME LIVE MATCH'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasLive && store.innings != null)
                Card(
                  child: ListTile(
                    title: Text(
                        '${store.innings!.battingTeam}: ${store.innings!.runs}/${store.innings!.wickets}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 20)),
                    subtitle: Text(
                        'Live • Tap resume to continue scoring'),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () =>
                        Navigator.pushNamed(context, '/scoring'),
                  ),
                ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.sports_cricket),
                      title: const Text('How it scores'),
                      subtitle: const Text(
                          '0 1 2 3 4 6 • WD NB B LB • W + run-out runs • Undo 60 steps • Auto overs, CRR, target'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.wb_sunny_outlined),
                      title: const Text('3 outdoor themes'),
                      subtitle: const Text(
                          'Sunlight high-contrast • Pavilion night • Solar yellow high-vis'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _themeSheet(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _themeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
                title: const Text('☀️ Sunlight (outdoor)'),
                value: 'sunlight',
                groupValue: store.themeId,
                onChanged: (v) {
                  store.setTheme(v!);
                  Navigator.pop(context);
                }),
            RadioListTile(
                title: const Text('🌙 Pavilion Night'),
                value: 'night',
                groupValue: store.themeId,
                onChanged: (v) {
                  store.setTheme(v!);
                  Navigator.pop(context);
                }),
            RadioListTile(
                title: const Text('🟡 Solar High-Vis'),
                value: 'solar',
                groupValue: store.themeId,
                onChanged: (v) {
                  store.setTheme(v!);
                  Navigator.pop(context);
                }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
