// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:teza_rider/main.dart';
import 'package:teza_rider/services/api_service.dart';

void main() {
  testWidgets('Splash screen rendering test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(apiService: ApiService()));

    // Verify that the splash screen shows the app name.
    expect(find.text('TEZA RIDER'), findsOneWidget);
    expect(find.text('Delivery Executions & Jobs'), findsOneWidget);

    // Let the delayed transitions/timers complete
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
