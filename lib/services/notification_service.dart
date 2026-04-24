import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../job_status.dart';

/// Who drove the current state transition. Used to suppress self-caused
/// notifications — the tech doesn't need to see "Technician marked arrived"
/// on their own device, the customer doesn't need to see "Customer marked
/// paid" on theirs.
enum TransitionActor { tech, customer, admin }

/// The local device's role. Passed in by callers so the service can compare
/// against the inferred actor and skip self-caused notifications.
enum ViewerRole { customer, technician }

/// Returns the role that could have caused the given [from] → [to]
/// transition, or null if the transition is ambiguous / unknown. Keep this
/// table in lockstep with the branch list in firestore.rules and the guard
/// in [isValidJobTransition]. Cancellations from `active` are intentionally
/// returned as null because the rules allow customer / tech / admin to make
/// that write, and local notifications can't tell which one fired.
TransitionActor? inferTransitionActor(String from, String to) {
  // Tech-driven
  if ((from == JobStatus.active && to == JobStatus.technicianAccepted) ||
      (from == JobStatus.technicianAccepted && to == JobStatus.onTheWay) ||
      (from == JobStatus.onTheWay && to == JobStatus.technicianArrived) ||
      (from == JobStatus.technicianArrived && to == JobStatus.workFinished) ||
      (from == JobStatus.workFinished &&
          to == JobStatus.awaitingCustomerApproval) ||
      (from == JobStatus.awaitingPaymentVerification &&
          to == JobStatus.completed)) {
    return TransitionActor.tech;
  }
  // Customer-driven
  if ((from == JobStatus.awaitingCustomerApproval &&
          to == JobStatus.awaitingPayment) ||
      (from == JobStatus.awaitingPayment &&
          to == JobStatus.awaitingPaymentVerification) ||
      (from == JobStatus.awaitingCustomerApproval &&
          to == JobStatus.receiptDisputed)) {
    return TransitionActor.customer;
  }
  // Admin-driven
  if ((from == JobStatus.requested && to == JobStatus.active) ||
      (from == JobStatus.receiptDisputed &&
          (to == JobStatus.completed ||
              to == JobStatus.awaitingCustomerApproval ||
              to == JobStatus.cancelled))) {
    return TransitionActor.admin;
  }
  // Ambiguous / unknown — includes cancellation from active (any of the
  // three could have fired it) and any transition the rules don't support.
  return null;
}

/// Returns the bilingual notification (title, body) the [viewer] should
/// see for a transition landing at [toStatus], or null if the viewer should
/// not be notified for this specific transition.
///
/// Content mirrors `jobStatusCustomerLabel` / `jobStatusTechLabel` so the
/// notification copy lines up with the label on the order card the user
/// taps into.
({String title, String body})? transitionNotificationFor({
  required ViewerRole viewer,
  required String toStatus,
  required bool isEn,
}) {
  if (viewer == ViewerRole.customer) {
    // Customer cares about every transition the tech drives that changes
    // what they see on their order card. Skip the tech-only waiting states
    // where the customer already knows (e.g. awaiting_customer_approval is
    // notified as "review receipt"; awaiting_payment_verification is a
    // passive hand-off notifiable to the customer as "tech is confirming").
    switch (toStatus) {
      case JobStatus.active:
        return (
          title: isEn ? 'Technician assigned' : 'تم تعيين الفني',
          body: jobStatusCustomerLabel(toStatus, isEn: isEn),
        );
      case JobStatus.technicianAccepted:
      case JobStatus.onTheWay:
      case JobStatus.technicianArrived:
      case JobStatus.workFinished:
      case JobStatus.awaitingCustomerApproval:
      case JobStatus.awaitingPaymentVerification:
      case JobStatus.completed:
      case JobStatus.receiptDisputed:
        return (
          title: isEn ? 'Order update' : 'تحديث الطلب',
          body: jobStatusCustomerLabel(toStatus, isEn: isEn),
        );
      default:
        return null;
    }
  }

  // Technician side — only notify for states that require the tech's next
  // action or signal the customer moved. No notification for tech-driven
  // transitions (self-caused, suppressed earlier by the inferActor check).
  switch (toStatus) {
    case JobStatus.active:
      return (
        title: isEn ? 'New assignment' : 'مهمة جديدة',
        body: jobStatusTechLabel(toStatus, isEn: isEn),
      );
    case JobStatus.awaitingPayment:
      return (
        title: isEn
            ? 'Customer approved — awaiting payment'
            : 'وافق العميل — بانتظار الدفع',
        body: jobStatusTechLabel(toStatus, isEn: isEn),
      );
    case JobStatus.awaitingPaymentVerification:
      return (
        title: isEn
            ? 'Customer paid — upload proof'
            : 'دفع العميل — ارفع الإثبات',
        body: jobStatusTechLabel(toStatus, isEn: isEn),
      );
    case JobStatus.receiptDisputed:
      return (
        title: isEn ? 'Receipt disputed' : 'نزاع على الفاتورة',
        body: jobStatusTechLabel(toStatus, isEn: isEn),
      );
    default:
      return null;
  }
}

/// Thin wrapper around `flutter_local_notifications`. Single Android channel
/// ("Job Updates"), iOS/macOS permissions requested on first initialize.
///
/// No push notifications (FCM) are used — everything fires from a client-
/// side Firestore listener. That means status changes that happen while the
/// app is fully closed don't trigger a notification; the user sees the new
/// state when they reopen the app. Push is a future project.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _channelId = 'syanat_job_updates';
  static const String _channelName = 'Job Updates';
  static const String _channelDescription =
      'Notifications when a Syanat job changes state (assignment, arrival, payment, completion).';

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return;
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const macosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: macosInit,
    );
    try {
      await _plugin.initialize(initSettings);
      // Android 13+ requires runtime permission for POST_NOTIFICATIONS.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] init failed: $e');
      // Swallow — notifications are a non-critical feature. The app must
      // still function if the plugin fails (e.g. on a web build).
    }
  }

  /// Low-level notification show. Prefer [notifyJobTransition] below which
  /// assembles the title/body from the transition + viewer role.
  static Future<void> show({
    required String jobId,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await initialize();
    if (!_initialized) return; // init failed; bail silently.

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    // Stable id per (jobId, title) so re-firing the same event doesn't spam
    // the tray — the OS replaces the existing entry.
    final notificationId =
        (jobId.hashCode ^ title.hashCode) & 0x7FFFFFFF;
    try {
      await _plugin.show(notificationId, title, body, details, payload: jobId);
    } catch (e) {
      debugPrint('[NotificationService] show failed: $e');
    }
  }

  /// Fires a notification for a [from] → [to] transition on the job doc,
  /// unless (a) the transition is self-caused by [viewer], (b) the
  /// transition is ambiguous, or (c) the target status isn't notifiable
  /// for this role.
  ///
  /// Returns true if a notification was shown — useful for tests and for
  /// debug logging.
  static Future<bool> notifyJobTransition({
    required String jobId,
    required String from,
    required String to,
    required ViewerRole viewer,
    required bool isEn,
  }) async {
    // Guard: ignore the initial-load "first snapshot" case where callers
    // pass from == to (no real transition occurred).
    if (from == to) return false;

    final actor = inferTransitionActor(from, to);
    final viewerAsActor = viewer == ViewerRole.customer
        ? TransitionActor.customer
        : TransitionActor.tech;
    if (actor == viewerAsActor) return false; // self-caused — suppress.

    final content =
        transitionNotificationFor(viewer: viewer, toStatus: to, isEn: isEn);
    if (content == null) return false;

    await show(jobId: jobId, title: content.title, body: content.body);
    return true;
  }
}
