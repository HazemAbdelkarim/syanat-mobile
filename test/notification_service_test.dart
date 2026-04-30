import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_projects/services/notification_service.dart';

void main() {
  group('inferTransitionActor — tech-driven', () {
    test('active → technician_accepted is tech', () {
      expect(inferTransitionActor('active', 'technician_accepted'),
          TransitionActor.tech);
    });
    test('technician_accepted → on_the_way is tech', () {
      expect(inferTransitionActor('technician_accepted', 'on_the_way'),
          TransitionActor.tech);
    });
    test('on_the_way → technician_arrived is tech', () {
      expect(inferTransitionActor('on_the_way', 'technician_arrived'),
          TransitionActor.tech);
    });
    test('technician_arrived → work_finished is tech', () {
      expect(inferTransitionActor('technician_arrived', 'work_finished'),
          TransitionActor.tech);
    });
    test('work_finished → awaiting_customer_approval is tech', () {
      expect(
          inferTransitionActor(
              'work_finished', 'awaiting_customer_approval'),
          TransitionActor.tech);
    });
    test('awaiting_payment_verification → completed is tech', () {
      expect(
          inferTransitionActor(
              'awaiting_payment_verification', 'completed'),
          TransitionActor.tech);
    });
    test('technician_accepted → cancelled is tech (Batch B post-accept cancel)',
        () {
      // Only the assigned technician can drive this transition per
      // firestore.rules; the inference must resolve unambiguously so the
      // self-caused notification on the cancelling tech\'s device is
      // suppressed.
      expect(inferTransitionActor('technician_accepted', 'cancelled'),
          TransitionActor.tech);
    });
  });

  group('inferTransitionActor — customer-driven', () {
    test('awaiting_customer_approval → awaiting_payment is customer', () {
      expect(
          inferTransitionActor(
              'awaiting_customer_approval', 'awaiting_payment'),
          TransitionActor.customer);
    });
    test('awaiting_payment → awaiting_payment_verification is customer',
        () {
      expect(
          inferTransitionActor(
              'awaiting_payment', 'awaiting_payment_verification'),
          TransitionActor.customer);
    });
    test('awaiting_customer_approval → receipt_disputed is customer', () {
      expect(
          inferTransitionActor(
              'awaiting_customer_approval', 'receipt_disputed'),
          TransitionActor.customer);
    });
  });

  group('inferTransitionActor — admin-driven', () {
    test('requested → active is admin', () {
      expect(inferTransitionActor('requested', 'active'),
          TransitionActor.admin);
    });
    test('receipt_disputed → completed is admin', () {
      expect(inferTransitionActor('receipt_disputed', 'completed'),
          TransitionActor.admin);
    });
    test('receipt_disputed → cancelled is admin', () {
      expect(inferTransitionActor('receipt_disputed', 'cancelled'),
          TransitionActor.admin);
    });
  });

  group('inferTransitionActor — ambiguous / unknown', () {
    test('active → cancelled is ambiguous (customer/tech/admin all possible)',
        () {
      // The rule permits this write from any of the three actors, so the
      // inference can\'t disambiguate and returns null.
      expect(inferTransitionActor('active', 'cancelled'), isNull);
    });
    test('completed → anything is unknown (terminal sink)', () {
      expect(inferTransitionActor('completed', 'active'), isNull);
      expect(inferTransitionActor('completed', 'cancelled'), isNull);
    });
    test('unknown status strings return null', () {
      expect(inferTransitionActor('foo', 'bar'), isNull);
    });
  });

  group('transitionNotificationFor — customer viewer', () {
    test('awaiting_customer_approval renders review-receipt copy', () {
      final c = transitionNotificationFor(
        viewer: ViewerRole.customer,
        toStatus: 'awaiting_customer_approval',
        isEn: true,
      );
      expect(c, isNotNull);
      expect(c!.title, 'Order update');
      expect(c.body, 'Review and approve your receipt');
    });

    test('on_the_way renders "Technician is on the way"', () {
      final c = transitionNotificationFor(
        viewer: ViewerRole.customer,
        toStatus: 'on_the_way',
        isEn: true,
      );
      expect(c!.body, 'Technician is on the way');
    });

    test('completed renders "Completed"', () {
      final c = transitionNotificationFor(
        viewer: ViewerRole.customer,
        toStatus: 'completed',
        isEn: true,
      );
      expect(c!.body, 'Completed');
    });

    test('unknown status returns null (no notification)', () {
      expect(
        transitionNotificationFor(
          viewer: ViewerRole.customer,
          toStatus: 'foo',
          isEn: true,
        ),
        isNull,
      );
    });
  });

  group('transitionNotificationFor — tech viewer', () {
    test('active renders "New assignment"', () {
      final t = transitionNotificationFor(
        viewer: ViewerRole.technician,
        toStatus: 'active',
        isEn: true,
      );
      expect(t!.title, 'New assignment');
    });

    test('awaiting_payment renders customer-approved-awaiting-payment copy',
        () {
      final t = transitionNotificationFor(
        viewer: ViewerRole.technician,
        toStatus: 'awaiting_payment',
        isEn: true,
      );
      expect(t!.title, 'Customer approved — awaiting payment');
    });

    test('awaiting_payment_verification renders upload-proof copy', () {
      final t = transitionNotificationFor(
        viewer: ViewerRole.technician,
        toStatus: 'awaiting_payment_verification',
        isEn: true,
      );
      expect(t!.title, 'Customer paid — upload proof');
    });

    test('receipt_disputed renders dispute copy', () {
      final t = transitionNotificationFor(
        viewer: ViewerRole.technician,
        toStatus: 'receipt_disputed',
        isEn: true,
      );
      expect(t!.title, 'Receipt disputed');
    });

    test('technician_accepted (self-caused target) returns null', () {
      // The tech just accepted — no self-notification for the target they
      // landed themselves on. The outer notifyJobTransition gate also
      // filters by actor, but the content map is null here too so nothing
      // could leak even if the actor check was bypassed.
      expect(
        transitionNotificationFor(
          viewer: ViewerRole.technician,
          toStatus: 'technician_accepted',
          isEn: true,
        ),
        isNull,
      );
    });

    test('work_finished (self-caused target) returns null', () {
      expect(
        transitionNotificationFor(
          viewer: ViewerRole.technician,
          toStatus: 'work_finished',
          isEn: true,
        ),
        isNull,
      );
    });
  });

  group('transitionNotificationFor — bilingual', () {
    // NOTE: customer's own actions (approve → awaiting_payment, mark-paid →
    // awaiting_payment_verification) are self-caused and intentionally map
    // to null on the customer side — no self-notification. Bilingual
    // coverage below uses tech-driven transitions that the customer CAN see.
    test('customer on_the_way AR wording', () {
      final c = transitionNotificationFor(
        viewer: ViewerRole.customer,
        toStatus: 'on_the_way',
        isEn: false,
      );
      expect(c!.title, 'تحديث الطلب');
      expect(c.body, 'الفني في الطريق');
    });

    test('customer self-caused awaiting_payment yields null (no notification)',
        () {
      expect(
        transitionNotificationFor(
          viewer: ViewerRole.customer,
          toStatus: 'awaiting_payment',
          isEn: true,
        ),
        isNull,
        reason: 'Customer drove this transition — must not self-notify.',
      );
    });

    test('tech new-assignment AR wording', () {
      final t = transitionNotificationFor(
        viewer: ViewerRole.technician,
        toStatus: 'active',
        isEn: false,
      );
      expect(t!.title, 'مهمة جديدة');
    });
  });
}
