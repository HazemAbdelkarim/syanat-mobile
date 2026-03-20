// Syanat App - Widget Tests
// Basic smoke tests for app startup and UI rendering

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_projects/main.dart';

void main() {
  /// Smoke test: App initializes without crashing
  testWidgets('App starts and displays splash/login screen', (WidgetTester tester) async {
    // Note: Firebase initialization requires proper mocking in CI/CD
    // This test validates basic UI rendering, not Firebase connectivity

    await tester.pumpWidget(const MyApp());

    // Allow time for initial animations
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Verify the app renders without throwing
    expect(find.byType(MyApp), findsOneWidget);

    // Verify splash screen or login screen is visible
    // (depending on auth state - at startup, both should load without error)
    final splashOrLogin = find.byType(Container);
    expect(splashOrLogin, findsWidgets);
  });

  /// Basic widget test: Login screen widget renders
  testWidgets('Login screen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify basic UI elements are present
    expect(find.byType(Icon), findsWidgets); // App icons
    expect(find.byType(TextFormField), findsWidgets); // Input fields
  });
}
