import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/debug/android_frame_wrapper.dart';
import 'store.dart';
import 'theme.dart';
import 'screens/home.dart';
import 'screens/setup.dart';
import 'screens/club.dart';
import 'screens/scoring.dart';
import 'screens/break_result.dart';
import 'screens/history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 100% offline: no network layer, no sign-in, no sockets.
  debugPrint('MAIN: starting');
  final store = MatchStore();
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
  // there); this call covers the Linux desktop preview and keeps it agreed.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  debugPrint('MAIN: orientations set');
  debugPrint('MAIN: calling runApp');
  runApp(CricketApp(store: store));
  // Flush a final snapshot when the phone locks or goes home. Force-stop
  // still leaves the prefs safe; this just keeps the backup equally fresh.
  AppLifecycleListener(
    onPause: () {
      store.suspendAudio();
      unawaited(store.backupNow());
    },
  );
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
        // Debug-only phone frame on desktop; bypassed on device/release.
        builder: (context, child) =>
            AndroidFrameWrapper(child: child ?? const SizedBox.shrink()),
        initialRoute: '/',
        routes: {
          '/': (_) => HomeScreen(store),
          '/setup': (_) => SetupScreen(store),
          '/scoring': (_) => ScoringScreen(store),
          '/break': (_) => BreakScreen(store),
          '/result': (_) => ResultScreen(store),
          '/history': (_) => HistoryScreen(store),
          '/club': (_) => ClubScreen(store),
        },
      ),
    );
  }
}
