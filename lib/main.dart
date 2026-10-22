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
  debugPrint('MAIN: starting');
  final sync = AppConfig.onlineRoomsEnabled
      ? SupabaseSync(url: AppConfig.supabaseUrl, publishableKey: AppConfig.key)
      : LocalOnlySync();
  final store = MatchStore(sync: sync);
  debugPrint('MAIN: calling store.load()');
  try {
    await store.load().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint('MAIN: store.load() TIMED OUT');
      },
    );
    debugPrint('MAIN: store.load() done, loaded=${store.loaded}');
  } catch (e, st) {
    debugPrint('MAIN: store.load() THREW: $e');
    debugPrintStack(stackTrace: st);
  }
  // Portrait only: the keypad grid, strip and hero are laid out for a narrow
  // portrait column; landscape would crush them and cause fat-finger errors.
  //
  // Set BEFORE runApp so the very first frame is already portrait - Android
  // reads the orientation when the activity is created, and calling this
  // after runApp raced the first frame. The AndroidManifest
  // `screenOrientation="portrait"` is the authoritative lock (see the note
  // there); this call covers web/desktop and keeps the two platforms agreed.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  debugPrint('MAIN: orientations set');
  // Signing in is deliberately not awaited: a slow or unreachable backend
  // must not delay the first ball. Sharing enables itself when it arrives.
  unawaited(sync.init().catchError((Object _) {}));
  debugPrint('MAIN: calling runApp');
  runApp(CricketApp(store: store));
  debugPrint('MAIN: runApp returned (never expected to block)');
}

class CricketApp extends StatelessWidget {
  final MatchStore store;
  const CricketApp({required this.store, super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, _) => MaterialApp(
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
