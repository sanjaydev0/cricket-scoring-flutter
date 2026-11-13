import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scoring/screens/widgets.dart';
import 'package:cricket_scoring/store.dart';
import 'package:cricket_scoring/theme.dart';

/// The design rules that are easy to break by accident: a name row is a
/// target, the app is used one-handed in the sun, and a control that is
/// pressed must look pressed.
void main() {
  /// The app's own theme, not a bare MaterialApp: the tokens only exist as a
  /// ThemeExtension, so a widget test has to install the real thing.
  Widget app(Widget child) => MaterialApp(
    theme: UmpireTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('a name row is a 48dp target, not a line of text', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const PlayerRow(name: 'Ravi Kumar', subtitle: 'Right-hand bat')),
    );
    expect(
      tester.getSize(find.byType(PlayerRow)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a locked row is a solid fill with full-contrast ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const PlayerRow(
          name: 'Sanjay',
          subtitle: 'just bowled',
          enabled: false,
        ),
      ),
    );

    final tokens = UmpireTheme.light().extension<DesignTokens>()!;
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(PlayerRow),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(
      decoration.color,
      tokens.lockedFill,
      reason: 'locked rows are a solid fill, never an opacity',
    );
    final border = decoration.border! as Border;
    expect(
      border.bottom.color,
      tokens.borderRow,
      reason: 'the row rule is 1px solid borderRow, not a 50% hairline',
    );

    final name = tester.widget<Text>(find.text('Sanjay'));
    expect(
      name.style!.color,
      tokens.lockedInk,
      reason: 'the name keeps full contrast against its own fill',
    );

    // And it says why it will not respond.
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('a selected row is a solid slab, not a tint', (tester) async {
    await tester.pumpWidget(
      app(const PlayerRow(name: 'Rohit Sharma', selected: true, onTap: _noop)),
    );
    final tokens = UmpireTheme.light().extension<DesignTokens>()!;
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(PlayerRow),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration! as BoxDecoration).color, tokens.primaryFill);
    expect(
      tester.widget<Text>(find.text('Rohit Sharma')).style!.color,
      tokens.onPrimaryFill,
    );
  });

  test('both themes register the roles and the roles flip', () {
    final light = UmpireTheme.light().extension<DesignTokens>();
    final dark = UmpireTheme.dark().extension<DesignTokens>();
    expect(light, isNotNull, reason: 'light theme must register DesignTokens');
    expect(dark, isNotNull, reason: 'dark theme must register DesignTokens');
    expect(light!.lockedFill, isNot(dark!.lockedFill));
    expect(light.lockedInk, isNot(dark.lockedInk));
    expect(light.statGoodInk, isNot(dark.statGoodInk));
    expect(light.statWarnInk, isNot(dark.statWarnInk));
    expect(light.surfaceOutline, isNot(dark.surfaceOutline));
  });

  group('the chrome kit', () {
    testWidgets('a rect card is flat: no Card, no elevation', (tester) async {
      await tester.pumpWidget(app(const RectCard(child: Text('MATCH FORMAT'))));
      expect(find.byType(Card), findsNothing);
      final tokens = UmpireTheme.light().extension<DesignTokens>()!;
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RectCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, tokens.surface);
      expect((deco.border! as Border).top.color, tokens.surfaceOutline);
    });

    testWidgets('a settings row is a 56dp target and a locked one is solid', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              SettingsRow(label: 'Sound', subtitle: 'Single quick bleeps'),
              SettingsRow(
                label: 'Battery saver',
                subtitle: 'No celebration',
                locked: true,
                last: true,
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(SettingsRow).first).height,
        greaterThanOrEqualTo(56),
      );
      final tokens = UmpireTheme.light().extension<DesignTokens>()!;
      final locked = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SettingsRow).last,
              matching: find.byType(Container),
            )
            .first,
      );
      expect((locked.decoration! as BoxDecoration).color, tokens.lockedFill);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('a rect toggle is a 48dp target that states its value', (
      tester,
    ) async {
      var v = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            RectToggle(
              value: v,
              semanticsLabel: 'Dark mode',
              onChanged: (x) => setState(() => v = x),
            ),
          ),
        ),
      );
      final target = tester.getSize(find.byType(InkWell));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(v, isTrue);
      final tokens = UmpireTheme.light().extension<DesignTokens>()!;
      final track = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect((track.decoration! as BoxDecoration).color, tokens.primaryFill);
    });

    testWidgets('a section band is a solid slab, not a grey caption', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const SectionBand('Format', trailing: '6 v 6')),
      );
      final tokens = UmpireTheme.light().extension<DesignTokens>()!;
      final band = tester.widget<Container>(find.byType(Container).first);
      expect(band.color, tokens.primaryFill);
      expect(find.text('FORMAT'), findsOneWidget);
      expect(find.text('6 v 6'), findsOneWidget);
    });

    testWidgets('a settings row with a toggle flips it from the label', (
      tester,
    ) async {
      var v = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            SettingsRow(
              label: 'Track players + stats',
              trailing: RectToggle(
                value: v,
                onChanged: (x) => setState(() => v = x),
              ),
            ),
          ),
        ),
      );
      // The row is the target, not just the 48dp knob.
      await tester.tap(find.text('Track players + stats'));
      await tester.pumpAndSettle();
      expect(v, isTrue);
    });

    testWidgets('a sheet header bands in a team colour or sits flat', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const SheetHeader(title: 'Openers + Bowler', caption: 'Lions'),
              SheetHeader(
                title: 'Over done',
                band: const Color(MatchStore.teamAColor),
                onClose: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('OPENERS + BOWLER'), findsOneWidget);
      expect(find.text('OVER DONE'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a detail row is a 48dp target too', (tester) async {
    await tester.pumpWidget(
      app(
        const DetailRow(
          title: 'Ravi Kumar',
          subtitle: 'Right-hand bat • Off spin',
          valueLabel: 'MATCHES',
          value: '14',
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(DetailRow)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a keypad key is a 72dp target', (tester) async {
    await tester.pumpWidget(
      app(const KeyBtn(label: '4', sub: 'FOUR', onTap: null)),
    );
    expect(
      tester.getSize(find.byType(KeyBtn)).height,
      greaterThanOrEqualTo(72),
    );
  });

  testWidgets('the detail row shows the value under its label', (tester) async {
    await tester.pumpWidget(
      app(
        const DetailRow(
          title: 'Ravi Kumar',
          subtitle: 'Right-hand bat',
          valueLabel: 'MATCHES',
          value: '14',
        ),
      ),
    );
    expect(find.text('MATCHES'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
  });
}

void _noop() {}
