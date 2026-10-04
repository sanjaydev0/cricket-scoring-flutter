import 'package:flutter/material.dart';
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
      builder: (_, __) {
        final hasLive = store.match != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('CRICSCORE',
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
          body: SafeArea(
              child: ResponsiveCenter(
                  child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.sports_cricket,
                          size: 44,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 4),
                      const Text('Umpire scorer • 100% offline',
                          textAlign: TextAlign.center),
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
                              'RESUME • ${store.innings!.battingTeam} ${store.innings!.runs}/${store.innings!.wickets}'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      RectBtn(
                        primary: false,
                        onTap: () => Navigator.pushNamed(context, '/history'),
                        child: const Text('ARCHIVES'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ))),
        );
      },
    );
  }

  void _settingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ListenableBuilder(
        listenable: store,
        builder: (_, __) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SETTINGS',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Styles • ${StylePreset.of(store.styleId).name}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  title: Text('Score font • ${ScoreFonts.names[store.fontId]}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in ScoreFonts.ids)
                          ChoiceChip(
                            label: Text('142/7',
                                style: TextStyle(
                                    fontFamily: ScoreFonts.family(id),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
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
                      style: const TextStyle(fontWeight: FontWeight.w700)),
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
                      style: const TextStyle(fontWeight: FontWeight.w700)),
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
                    const Text('Simple: Wicket + Run Out. Complex: full grid.',
                        style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 8),
                  ],
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Sounds & extras',
                      style: TextStyle(fontWeight: FontWeight.w700)),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
