import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cndlclar/main.dart';

void main() {
  testWidgets('CndlClar opens and navigates without backend connection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CndlClarApp(connectToBackend: false));

    expect(find.text('CndlClar'), findsOneWidget);
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Alerts'), findsOneWidget);

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(find.bySemanticsLabel('Alerts'));
    await tester.pump();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
  });
}
