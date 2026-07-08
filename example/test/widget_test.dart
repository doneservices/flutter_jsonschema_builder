import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('demo boots into the stepped form', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // first step of the stepped demo form
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.textContaining('First name'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // the mode toggle lives in the settings menu (bounded pumps: the
    // looping Lottie animation would keep pumpAndSettle from settling)
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Switch to classic'), findsOneWidget);
  });
}
