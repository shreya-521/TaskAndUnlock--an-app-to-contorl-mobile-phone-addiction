import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_and_unlock/main.dart';

void main() {
  testWidgets('App loads and shows home screen title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TaskAndUnlockApp());

    // Verify that our app bar title is displayed.
    expect(find.text('Task And Unlock'), findsOneWidget);
  });
}
