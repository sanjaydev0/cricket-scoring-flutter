import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scoring/store.dart';
import 'package:cricket_scoring/main.dart';

void main() {
  testWidgets('app boots', (t) async {
    final store = MatchStore();
    await t.pumpWidget(CricketApp(store: store));
    expect(find.text('CRICSCORE'), findsOneWidget);
    expect(find.text('START NEW MATCH'), findsOneWidget);
    expect(find.text('ARCHIVES'), findsOneWidget);
  });
}
