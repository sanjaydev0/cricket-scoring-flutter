import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'themes.dart';
import 'screens/home.dart';
import 'screens/setup.dart';
import 'screens/scoring.dart';
import 'screens/break_result.dart';
import 'screens/history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = MatchStore();
  // Don't block splash on storage - load async, show UI instantly.
  runApp(CricketApp(store: store));
  await store.load();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
}

class CricketApp extends StatelessWidget {
  final MatchStore store;
  const CricketApp({required this.store, super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) => MaterialApp(
        title: 'Gully Cricket Scorer',
        debugShowCheckedModeBanner: false,
        theme: AppThemes.byId(store.themeId),
        initialRoute: '/',
        routes: {
          '/': (_) => HomeScreen(store),
          '/setup': (_) => SetupScreen(store),
          '/scoring': (_) => ScoringScreen(store),
          '/break': (_) => BreakScreen(store),
          '/result': (_) => ResultScreen(store),
          '/history': (_) => HistoryScreen(store),
        },
      ),
    );
  }
}
