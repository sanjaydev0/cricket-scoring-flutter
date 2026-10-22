import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scoring/screens/widgets.dart';

/// The design rules that are easy to break by accident: a name row is a
/// target, the app is used one-handed in the sun, and a control that is
/// pressed must look pressed.
void main() {
  testWidgets('a name row is a 48dp target, not a line of text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PlayerRow(name: 'Ravi Kumar', subtitle: 'Right-hand bat'),
      ),
    ));
    expect(tester.getSize(find.byType(PlayerRow)).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('a detail row is a 48dp target too', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DetailRow(
          title: 'Ravi Kumar',
          subtitle: 'Right-hand bat • Off spin',
          valueLabel: 'MATCHES',
          value: '14',
        ),
      ),
    ));
    expect(tester.getSize(find.byType(DetailRow)).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('a keypad key is a 72dp target', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: KeyBtn(label: '4', sub: 'FOUR', onTap: null),
      ),
    ));
    expect(
        tester.getSize(find.byType(KeyBtn)).height, greaterThanOrEqualTo(72));
  });

  testWidgets('the detail row shows the value under its label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DetailRow(
          title: 'Ravi Kumar',
          subtitle: 'Right-hand bat',
          valueLabel: 'MATCHES',
          value: '14',
        ),
      ),
    ));
    expect(find.text('MATCHES'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
  });
}
