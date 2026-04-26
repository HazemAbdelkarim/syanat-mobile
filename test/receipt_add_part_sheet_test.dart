import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_projects/technician_receipt_screen.dart';

void main() {
  group('ReceiptAddPartSheet (release 006 — inventory removed)', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(body: child),
        );

    testWidgets('renders the custom-entry form', (tester) async {
      await tester.pumpWidget(wrap(const ReceiptAddPartSheet(isEn: true)));

      expect(find.text('Add Custom Item'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Item name'), findsOneWidget);
      expect(
          find.widgetWithText(ElevatedButton, 'Add to Receipt'), findsOneWidget);
    });

    testWidgets('has NO "Pick from Inventory" tab', (tester) async {
      await tester.pumpWidget(wrap(const ReceiptAddPartSheet(isEn: true)));

      expect(find.text('Pick from Inventory'), findsNothing,
          reason: 'Inventory picker was retired in release 006.');
      expect(find.text('Custom'), findsNothing,
          reason:
              'The "Custom" tab label is gone too — the sheet is single-form now.');
      expect(find.byType(TabBar), findsNothing,
          reason: 'No TabBar should be present in the single-form sheet.');
      expect(find.byType(TabBarView), findsNothing);
    });

    testWidgets('renders Arabic form when isEn: false', (tester) async {
      await tester.pumpWidget(wrap(const ReceiptAddPartSheet(isEn: false)));

      expect(find.text('إضافة عنصر مخصص'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'اسم العنصر'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'إضافة إلى الإيصال'),
          findsOneWidget);
      // No inventory equivalents leak through.
      expect(find.textContaining('المخزون'), findsNothing);
    });

    testWidgets('empty item name triggers validation snackbar', (tester) async {
      await tester.pumpWidget(wrap(const ReceiptAddPartSheet(isEn: true)));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add to Receipt'));
      await tester.pump();

      expect(find.text('Enter an item name.'), findsOneWidget);
    });
  });
}
