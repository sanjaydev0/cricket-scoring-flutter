import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/room_code.dart';
import '../domain/room_snapshot.dart';
import '../models.dart';
import '../ports/sync_port.dart';
import '../store.dart' show MatchStore;
import '../theme.dart';
import 'scoreboard.dart';
import 'widgets.dart';

/// Read-only live view.
///
/// This screen cannot score. There is no keypad, no undo, no wicket dialog and
/// no settings: the only action is leaving. That is enforced structurally —
/// nothing here calls a mutating method on [MatchStore] — rather than by
/// hiding buttons, so a future edit cannot accidentally grant a viewer control
/// of a live match.
class ViewerScreen extends StatefulWidget {
  final MatchStore store;
  final String code;
  const ViewerScreen({required this.store, required this.code, super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  StreamSubscription<RoomSnapshot>? _sub;
  Match? _match;
  int _seq = 0;
  DateTime? _updatedAt;
  String? _problem;
  Timer? _ageTimer;

  @override
  void initState() {
    super.initState();
    _sub = widget.store.sync.roomUpdates.listen(_onSnapshot);
    unawaited(widget.store.sync.watchRoom(widget.code));
    // Drives the "scorer offline" chip without rebuilding the scoreboard.
    _ageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onSnapshot(RoomSnapshot snap) {
    // Ignore anything stale: realtime can deliver out of order after a
    // reconnect, and a viewer must never walk the score backwards.
    if (snap.seq <= _seq) return;
    setState(() {
      try {
        _match = Match.decode(jsonEncode(snap.match));
      } catch (_) {
        _problem = 'Received a score this version cannot read';
        return;
      }
      _seq = snap.seq;
      _updatedAt = snap.updatedAt;
      _problem = null;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ageTimer?.cancel();
    super.dispose();
  }

  /// "just now" / "2m ago" — a viewer must be able to tell a frozen score from
  /// a live one without guessing.
  String get _staleness {
    final at = _updatedAt;
    if (at == null) return '';
    final s = DateTime.now().difference(at).inSeconds;
    if (s < 10) return 'LIVE';
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    return '${m}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final preset = StylePreset.of(widget.store.styleId);
    final m = _match;
    final inn =
        m == null ? null : (m.currentInnings == 1 ? m.innings1 : m.innings2);
    final stale = _updatedAt == null ||
        DateTime.now().difference(_updatedAt!).inSeconds > 45;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      stale ? const Color(0xFF64748B) : const Color(0xFFDC143C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_staleness.isEmpty ? 'CONNECTING' : _staleness,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 640,
          child: m == null || inn == null
              ? _waiting(context)
              : ListenableBuilder(
                  listenable: widget.store,
                  builder: (_, __) => ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Scoreboard(
                        match: m,
                        innings: inn,
                        preset: preset,
                        scoreFamily: ScoreFonts.family(widget.store.fontId),
                        // A remote ball advances the numerals exactly once.
                        animationGen: _seq,
                        live: true,
                      ),
                      const SizedBox(height: 10),
                      Text('Room ${widget.code} • read-only',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7))),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _waiting(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cell_tower, size: 44),
              const SizedBox(height: 12),
              Text(
                _problem ?? 'Waiting for the scorer…',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('Room ${widget.code}',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
            ],
          ),
        ),
      );
}

/// Entry point: type the code someone read you.
class JoinRoomScreen extends StatefulWidget {
  final MatchStore store;
  const JoinRoomScreen({required this.store, super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _join() {
    final code = RoomCode.normalize(_controller.text);
    if (code == null) {
      setState(() => _error = 'Codes are 5 letters/digits (no 0, 1, O or I)');
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(store: widget.store, code: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.store.sync.state != SyncState.unconfigured;
    return Scaffold(
      appBar: AppBar(
          title: const Text('WATCH LIVE',
              style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Enter the 5-character code',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: RoomCode.length,
                textCapitalization: TextCapitalization.characters,
                // Large, spaced, unambiguous: this gets typed one-handed while
                // someone reads the code aloud.
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10),
                decoration: InputDecoration(
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 22),
                    tooltip: 'Clear code',
                    onPressed: () => setState(() {
                      _controller.clear();
                      _error = null;
                    }),
                  ),
                  hintText: 'ABCDE',
                  hintStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                      color: Color(0xFF94A3B8)),
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z2-9]')),
                  _UpperCaseFormatter(),
                ],
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 16),
              RectBtn(onTap: _join, child: const Text('WATCH')),
              const SizedBox(height: 12),
              if (!online)
                const Text(
                  'Live rooms need a backend in this build, so watching is unavailable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
