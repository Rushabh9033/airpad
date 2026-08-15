// Basic smoke test: the connection page renders and reaches the
// "Connect" button. We don't drive a real TCP connection in tests.

import 'package:airpad/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Connection page renders with Connect button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AirpadApp());
    // Pump enough frames for any layout + GoRouter redirect to settle.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Airpad'), findsWidgets);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.byIcon(Icons.link_off), findsNothing); // not on trackpad page yet
  });
}
