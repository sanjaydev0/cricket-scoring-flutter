import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scoring/screens/widgets.dart';
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
