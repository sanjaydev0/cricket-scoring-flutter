import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adapters/local_only_sync.dart';
import 'adapters/supabase_sync.dart';
import 'app_config.dart';
import 'store.dart';
import 'theme.dart';
import 'screens/home.dart';
import 'screens/setup.dart';
import 'screens/club.dart';
import 'screens/scoring.dart';
import 'screens/viewer.dart';
import 'screens/break_result.dart';
import 'screens/history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Online rooms are opt-in at build time. Without credentials the app is
  // exactly the offline app it has always been.
  final sync = AppConfig.onlineRoomsEnabled
      ? SupabaseSync(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.key,
        )
      : LocalOnlySync();
  final store = MatchStore(sync: sync);
  // Load before the first frame: this also preloads every SFX clip, so the
  // very first boundary/wicket of the match is never swallowed by an
  // audio pool that is still warming up.
  await store.load();
  // Signing in is deliberately not awaited: a slow or unreachable backend
  // must not delay the first ball. Sharing enables itself when it arrives.
  unawaited(sync.init().catchError((Object _) {}));
  runApp(CricketApp(store: store));
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight
  ]);
}

class CricketApp extends StatelessWidget {
  final MatchStore store;
  const CricketApp({required this.store, super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) => MaterialApp(
        title: 'CricScore',
        debugShowCheckedModeBanner: false,
        theme: UmpireTheme.light(),
        darkTheme: UmpireTheme.dark(),
        themeMode: store.themeId == 'dark' ? ThemeMode.dark : ThemeMode.light,
        initialRoute: '/',
        routes: {
          '/': (_) => HomeScreen(store),
          '/setup': (_) => SetupScreen(store),
          '/scoring': (_) => ScoringScreen(store),
          '/break': (_) => BreakScreen(store),
          '/result': (_) => ResultScreen(store),
          '/history': (_) => HistoryScreen(store),
          '/join': (_) => JoinRoomScreen(store: store),
          '/club': (_) => ClubScreen(store),
        },
      ),
    );
  }
}
