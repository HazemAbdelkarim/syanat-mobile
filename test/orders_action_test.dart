import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_projects/orders_screen.dart' show customerOrderAction;

/// Smoke tests for `customerOrderAction` — the status → action-widget helper
/// used under the active-order card on `orders_screen.dart`. We're only
/// verifying which button label or read-only message renders for each
/// customer-visible status. No navigation, no Firebase streams mocked.
Future<void> _pumpAction(
  WidgetTester tester, {
  required String status,
  required bool isEn,
  double? amountPaid,
}) async {
  final job = <String, dynamic>{
    'id': 'job123',
    'status': status,
    if (amountPaid != null) 'amountPaid': amountPaid,
  };
  await tester.pumpWidget(MaterialApp(
    locale: Locale(isEn ? 'en' : 'ar'),
    home: Scaffold(
      body: Directionality(
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        child: Builder(
          builder: (ctx) =>
              customerOrderAction(ctx, job, 'customer-uid', isEn),
        ),
      ),
    ),
  ));
}

void main() {
  group('customerOrderAction — action buttons', () {
    testWidgets('awaiting_customer_approval renders "Review receipt" button',
        (tester) async {
      await _pumpAction(tester,
          status: 'awaiting_customer_approval', isEn: true);
      expect(
          find.widgetWithText(ElevatedButton, 'Review receipt'),
          findsOneWidget);
    });

    testWidgets('awaiting_customer_approval renders Arabic button label',
        (tester) async {
      await _pumpAction(tester,
          status: 'awaiting_customer_approval', isEn: false);
      expect(find.widgetWithText(ElevatedButton, 'راجع الفاتورة'),
          findsOneWidget);
    });

    testWidgets('awaiting_payment renders "Pay technician" button',
        (tester) async {
      await _pumpAction(tester, status: 'awaiting_payment', isEn: true);
      expect(find.widgetWithText(ElevatedButton, 'Pay technician'),
          findsOneWidget);
    });

    testWidgets('awaiting_payment renders Arabic button label',
        (tester) async {
      await _pumpAction(tester, status: 'awaiting_payment', isEn: false);
      expect(find.widgetWithText(ElevatedButton, 'ادفع للفني'),
          findsOneWidget);
    });
  });

  group('customerOrderAction — read-only messages', () {
    testWidgets('requested shows customer label, no button', (tester) async {
      await _pumpAction(tester, status: 'requested', isEn: true);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Waiting for a technician to be assigned'),
          findsOneWidget);
    });

    testWidgets('on_the_way shows customer label, no button',
        (tester) async {
      await _pumpAction(tester, status: 'on_the_way', isEn: true);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Technician is on the way'), findsOneWidget);
    });

    testWidgets('technician_arrived shows customer label, no button',
        (tester) async {
      await _pumpAction(tester, status: 'technician_arrived', isEn: true);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Technician has arrived'), findsOneWidget);
    });

    testWidgets('work_finished shows customer label, no button',
        (tester) async {
      await _pumpAction(tester, status: 'work_finished', isEn: true);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(
          find.text(
              'Work finished — technician is preparing your receipt'),
          findsOneWidget);
    });

    testWidgets('awaiting_payment_verification shows verification message',
        (tester) async {
      await _pumpAction(tester,
          status: 'awaiting_payment_verification', isEn: true);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Technician is confirming your payment.'),
          findsOneWidget);
    });

    testWidgets('receipt_disputed shows dispute message', (tester) async {
      await _pumpAction(tester, status: 'receipt_disputed', isEn: true);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Receipt disputed — admin is reviewing.'),
          findsOneWidget);
    });

    testWidgets('completed shows paid amount', (tester) async {
      await _pumpAction(tester,
          status: 'completed', isEn: true, amountPaid: 450);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Completed — 450 EGP paid.'), findsOneWidget);
    });
  });
}
