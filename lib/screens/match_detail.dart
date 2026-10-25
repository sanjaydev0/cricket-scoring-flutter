import 'package:flutter/material.dart';

import '../domain/players.dart';
import '../math.dart';
import '../models.dart';
import '../store.dart';
import 'summary.dart';
import 'widgets.dart';

/// The one match-detail view.
///
/// The live scorecard, the archive detail and the result page all render this,
/// so a figure can never differ between them.
///
/// Layout follows the newspaper scorecard, not a stack of cards:
///
///   - a header with BOTH teams' scores and the result line;
///   - two team pills that switch which innings is on screen;
///   - flat tables (hairline dividers, no cards) for batting and bowling;
///   - a SUMMARY tab with the top performers of each innings.
///
/// Only one innings' players are ever on screen. Two innings of names on one
/// page is a wall, and the umpire wants one card at a time.
class MatchDetail extends StatefulWidget {
  final MatchStore store;

  /// Which innings opens the card. The live view opens on the innings being
  /// played; an archive opens on the first innings.
  final int initialInnings;

  /// Shows the small BALLS link that opens the over-by-over sheet. On by
  /// default for archives, where the ball history used to sit inline.
  final bool showBallsLink;

  const MatchDetail({
    super.key,
    required this.store,
    this.initialInnings = 1,
    this.showBallsLink = true,
  });

  @override
  State<MatchDetail> createState() => _MatchDetailState();
}

class _MatchDetailState extends State<MatchDetail> {
  int _tab = 0; // 0 = scorecard, 1 = summary
  late int _innings = widget.initialInnings;

  @override
  void initState() {
    super.initState();
    // Never open on an innings that does not exist.
    final m = widget.store.match;
    if (m != null && m.innings2 == null && _innings != 1) _innings = 1;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final m = store.match;
    if (m == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: store,
      builder: (_, _) {
        final match = store.match!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(match),
            const SizedBox(height: 6),
            UnderlineTabs(
              labels: const ['SCORECARD', 'SUMMARY'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 6),
            // No Expanded: the parent owns the scrolling, so the same widget
            // works as a whole screen and as a block inside a longer list.
            if (_tab == 0) _scorecardTab(store, match) else _summaryTab(store),
          ],
        );
      },
    );
  }

  // --- header ---------------------------------------------------------------

  Widget _header(Match m) {
    final inn1 = m.innings1;
    final inn2 = m.innings2;
    final first = inn1;
    final second = inn2;
    final secondTeam =
        second?.battingTeam ??
        (inn1.battingTeam == m.config.teamA ? m.config.teamB : m.config.teamA);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _teamScore(
                first.battingTeam,
                first.runs,
                first.wickets,
                first.legalDeliveries,
                alignEnd: false,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.bolt, size: 20, color: Color(0xFFF59E0B)),
            ),
            Expanded(
              child: second == null
                  ? _teamScore(secondTeam, null, null, null, alignEnd: true)
                  : _teamScore(
                      second.battingTeam,
                      second.runs,
                      second.wickets,
                      second.legalDeliveries,
                      alignEnd: true,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _resultLine(m),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              // Amber on dark, deep amber on light: the result line has to
              // read in sunlight AND at night.
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFB45309),
            ),
          ),
        ),
      ],
    );
  }

  Widget _teamScore(
    String team,
    int? runs,
    int? wickets,
    int? balls, {
    required bool alignEnd,
  }) {
    final cs = Theme.of(context).colorScheme;
    final dot = _teamColor(team);
    final score = runs == null ? '—' : '$runs/$wickets';
    final overs = balls == null ? null : '(${CricketMath.ballsToOvers(balls)})';
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!alignEnd) ...[
              TeamDot(dot, size: 10),
              const SizedBox(width: 6),
            ],
            Text(
              team,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            if (alignEnd) ...[const SizedBox(width: 6), TeamDot(dot, size: 10)],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (alignEnd && overs != null) ...[
              Text(
                overs,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              score,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (!alignEnd && overs != null) ...[
              const SizedBox(width: 6),
              Text(
                overs,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The result line: how it ended, or what is still needed.
  String _resultLine(Match m) {
    if (m.completed) {
      if (m.winner == 'TIE') return 'MATCH TIED';
      final margin = m.winMargin ?? '';
      return margin.isEmpty ? '${m.winner} WON' : '${m.winner} WON BY $margin';
    }
    if (m.currentInnings == 2 && m.target != null) {
      final inn = m.innings2!;
      final need = m.target! - inn.runs;
      if (need <= 0) return 'WON';
      final ballsLeft =
          CricketMath.totalBalls(m.config.totalOvers) - inn.legalDeliveries;
      if (ballsLeft <= 0) return 'OUT OF OVERS';
      return 'NEED $need OFF $ballsLeft • RRR '
          '${CricketMath.calcRRR(need, ballsLeft)}';
    }
    return '${m.innings1.battingTeam} BATTING FIRST';
  }

  int _teamColor(String team) {
    final m = widget.store.match!;
    return team == m.config.teamA
        ? MatchStore.teamAColor
        : MatchStore.teamBColor;
  }

  // --- scorecard tab --------------------------------------------------------

  Widget _scorecardTab(MatchStore store, Match m) {
    final sheet = store.sheetFor(_innings);
    final inn = _innings == 1 ? m.innings1 : m.innings2;
    if (inn == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pills(m, inn),
          const SizedBox(height: 10),
          if (sheet != null && _innings == m.currentInnings && !m.completed)
            _nowLine(sheet),
          if (sheet == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Player tracking was off for this innings — no card to show.',
                style: TextStyle(fontSize: 12),
              ),
            )
          else ...[
            _battingTable(store, sheet),
            _extrasRow(inn),
            const SizedBox(height: 14),
            _bowlingTable(store, sheet),
          ],
          if (widget.showBallsLink && _hasBalls(inn))
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.sports_cricket, size: 16),
                  label: const Text('BALLS'),
                  onPressed: () => _showBalls(store, inn, sheet),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasBalls(Innings inn) => inn.overs.any((o) => o.balls.isNotEmpty);

  /// The two innings switcher. Selected = solid team colour, other = outline.
  Widget _pills(Match m, Innings inn) {
    final hasTwo = m.innings2 != null;
    final inn1 = m.innings1;
    final inn2 = m.innings2;
    return Row(
      children: [
        Expanded(
          child: TeamPill(
            label: inn1.battingTeam,
            figure:
                '${inn1.runs}/${inn1.wickets} '
                '(${CricketMath.ballsToOvers(inn1.legalDeliveries)})',
            selected: _innings == 1,
            colorValue: _teamColor(inn1.battingTeam),
            onTap: () => setState(() => _innings = 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TeamPill(
            label:
                inn2?.battingTeam ??
                (inn1.battingTeam == m.config.teamA
                    ? m.config.teamB
                    : m.config.teamA),
            figure: inn2 == null
                ? 'yet to bat'
                : '${inn2.runs}/${inn2.wickets} '
                      '(${CricketMath.ballsToOvers(inn2.legalDeliveries)})',
            selected: _innings == 2,
            colorValue: _teamColor(
              inn2?.battingTeam ??
                  (inn1.battingTeam == m.config.teamA
                      ? m.config.teamB
                      : m.config.teamA),
            ),
            enabled: hasTwo,
            onTap: () => setState(() => _innings = 2),
          ),
        ),
      ],
    );
  }

  /// One line: who is at the crease and who is bowling.
  ///
  /// The old three stacked rows were 160dp of screen for three names. One line
  /// says the same thing in 24dp.
  Widget _nowLine(InningsSheet sheet) {
    final striker = sheet.striker;
    final nonStriker = sheet.nonStriker;
    final bowler = sheet.currentBowler;
    final parts = <String>[];
    if (striker != null) {
      parts.add('${striker.name} ${striker.runs}*');
    }
    if (nonStriker != null) {
      parts.add('${nonStriker.name} ${nonStriker.runs}*');
    }
    if (bowler != null) {
      parts.add('${bowler.name} ${bowler.wickets}-${bowler.runsConceded}');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        parts.join('  •  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }

  // --- tables ---------------------------------------------------------------

  Widget _numHead(String v, double w) => SizedBox(
    width: w,
    child: Text(
      v,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 9,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _num(String v, double w, {bool strong = false}) => SizedBox(
    width: w,
    child: Text(
      v,
      textAlign: TextAlign.right,
      maxLines: 1,
      style: TextStyle(
        fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
        fontSize: 14,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );

  Widget _hairline() => Container(
    height: 1,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
  );

  Widget _battingTable(MatchStore store, InningsSheet sheet) {
    final cs = Theme.of(context).colorScheme;
    final m = store.match!;
    final squad = sheet.battingTeam == m.config.teamA
        ? m.config.squadA
        : m.config.squadB;
    final played = sheet.battingCards;
    final playedIds = played.map((c) => c.playerId).toSet();
    final unplayed = squad
        .where((id) => !playedIds.contains(id))
        .map((id) => BattingCard(playerId: id, name: sheet.nameOf(id)))
        .toList();
    final bat = [...played, ...unplayed];
    if (bat.isEmpty && squad.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Nobody batted.', style: TextStyle(fontSize: 12)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'BATTER',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ),
            _numHead('R', 30),
            _numHead('B', 30),
            _numHead('4s', 26),
            _numHead('6s', 26),
            _numHead('SR', 46),
          ],
        ),
        const SizedBox(height: 4),
        _hairline(),
        for (final c in bat) ...[
          Opacity(
            opacity: c.position == 0 ? 0.55 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.playerId == sheet.strikerId
                              ? '${c.name} *'
                              : c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color:
                                (c.playerId == sheet.strikerId ||
                                    c.playerId == sheet.nonStrikerId)
                                ? const Color(0xFF1D4ED8)
                                : null,
                          ),
                        ),
                        Text(
                          _dismissalLine(sheet, c),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _num('${c.runs}', 30, strong: c.position > 0),
                  _num('${c.balls}', 30),
                  _num('${c.fours}', 26),
                  _num('${c.sixes}', 26),
                  _num(
                    c.strikeRate == null
                        ? '—'
                        : c.strikeRate!.toStringAsFixed(1),
                    46,
                  ),
                ],
              ),
            ),
          ),
          _hairline(),
        ],
      ],
    );
  }

  String _dismissalLine(InningsSheet sheet, BattingCard c) {
    if (c.position == 0) return 'did not bat';
    if (c.playerId == sheet.strikerId) return 'on strike';
    if (c.playerId == sheet.nonStrikerId) return 'at the other end';
    if (c.isNotOut) return 'not out';
    return c.dismissal?.text(
          fielder: c.dismissedByName,
          bowler: c.bowlerName,
        ) ??
        'out';
  }

  Widget _extrasRow(Innings inn) {
    final cs = Theme.of(context).colorScheme;
    final bits = <String>[
      if (inn.byes > 0) '${inn.byes}b',
      if (inn.legByes > 0) '${inn.legByes}lb',
      if (inn.wides > 0) '${inn.wides}w',
      if (inn.noBalls > 0) '${inn.noBalls}nb',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Text(
            'Extras:',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const Spacer(),
          Text(
            '${inn.extrasTotal}${bits.isEmpty ? '' : '   ${bits.join(', ')}'}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.8),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bowlingTable(MatchStore store, InningsSheet sheet) {
    final cs = Theme.of(context).colorScheme;
    final m = store.match!;
    final squad = sheet.battingTeam == m.config.teamA
        ? m.config.squadB
        : m.config.squadA;
    final played = sheet.bowlingCards;
    final playedIds = played.map((c) => c.playerId).toSet();
    final unplayed = squad
        .where((id) => !playedIds.contains(id))
        .map((id) => BowlingCard(playerId: id, name: sheet.nameOf(id)))
        .toList();
    final bowl = [...played, ...unplayed];
    if (bowl.isEmpty && squad.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Nobody bowled.', style: TextStyle(fontSize: 12)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'BOWLING',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        _hairline(),
        for (final c in bowl) ...[
          Opacity(
            opacity: (c.balls == 0 && c.wickets == 0) ? 0.55 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (c.penaltyRuns > 0)
                          Text(
                            'incl ${c.penaltyRuns} penalty',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        if (c.balls == 0 && c.wickets == 0)
                          Text(
                            'did not bowl',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _num(c.oversDisplay, 32),
                  _num('${c.maidens}', 28),
                  _num('${c.runsConceded}', 32),
                  _num('${c.wickets}', 28, strong: true),
                  _num(
                    c.economy == null ? '—' : c.economy!.toStringAsFixed(2),
                    46,
                  ),
                ],
              ),
            ),
          ),
          _hairline(),
        ],
      ],
    );
  }

  // --- summary tab ----------------------------------------------------------

  Widget _summaryTab(MatchStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: TopPerformersView(store: store),
    );
  }

  // --- balls sheet ----------------------------------------------------------

  /// Over-by-over, with the bowler who bowled each over.
  ///
  /// It was inline in the archive before, and the coloured ball badges made
  /// the page look like a toy. It is one link away now.
  void _showBalls(MatchStore store, Innings inn, InningsSheet? sheet) {
    showAppSheet(
      context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'BALLS • ${inn.battingTeam}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              for (final o in inn.overs)
                if (o.balls.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'OVER ${o.overNumber.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bowlerOfOver(o, sheet),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${o.balls.fold<int>(0, (s, b) => s + b.totalRuns)} runs'
                        ' • ${o.balls.where((b) => b.isWicket).length} wkt',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final b in o.balls) BallBadge(b)],
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  /// Who bowled the over: the first ball's bowler wins.
  String _bowlerOfOver(Over o, InningsSheet? sheet) {
    for (final b in o.balls) {
      final id = b.bowlerId;
      if (id != null && id.isNotEmpty) {
        return sheet?.nameOf(id) ?? '—';
      }
    }
    return '—';
  }
}
