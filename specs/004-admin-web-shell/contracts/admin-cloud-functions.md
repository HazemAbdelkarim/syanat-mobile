# Contract: `AdminCloudFunctions` (Dart → Firebase Callables)

**File**: `.claude/AdminWebApp/lib/services/admin_cloud_functions.dart`
**Stability**: Declaring this contract is IN-SCOPE for Spec 004 (Phase 6). Implementing each stub is OUT-OF-SCOPE until Phase 7 (Spec 005).
**Underlying callables**: Deployed by Spec 002 in project `syana-ea75a`, region `europe-west1`. Each Dart method wraps one callable.

## Imports required

```dart
import 'package:cloud_functions/cloud_functions.dart';
```

## Class contract

```dart
class AdminCloudFunctions {
  AdminCloudFunctions();
  // 5 methods — see below.
}
```

The class is a thin wrapper. No state. Phase 7 MAY add a `FirebaseFunctions` parameter for testability, but MUST preserve the no-arg constructor.

## Method-to-callable mapping

| # | Dart method | Underlying callable (deployed in Spec 002) | Auth / audit |
|---|-------------|---------------------------------------------|--------------|
| 1 | `Future<void> assignJob(String jobId, String technicianId)` | `adminAssignJob` (callable, region `europe-west1`) | Writes `assignedBy`, `assignedAt` server-side. |
| 2 | `Future<void> approvePayment(String paymentId)` | `adminApprovePayment` | Writes `reviewedBy`, `reviewedAt`. |
| 3 | `Future<void> rejectPayment(String paymentId, String reason)` | `adminRejectPayment` | Writes `reviewedBy`, `reviewedAt`, `rejectionReason`. |
| 4 | `Future<void> resolveDispute(String jobId, String resolution, String reason, {double? overrideAmount})` | `adminResolveDispute` | Writes `resolvedBy`, `disputeResolvedAt`, `resolutionNote`. |
| 5 | `Future<void> closeJob(String jobId, double amountPaid)` | `adminCloseJob` | Writes `adminClosedBy`, `adminClosedAt`. |

The Dart method names deliberately drop the `admin` prefix (`assignJob` not `adminAssignJob`) — the class name already conveys the admin context. The underlying callable names retain the prefix for server-side clarity.

## Phase 6 behavior

**Every** method throws:

```dart
throw UnimplementedError(
  'AdminCloudFunctions.<methodName> not implemented (Phase 7)',
);
```

No callable is actually invoked in Phase 6. `FirebaseFunctions.instance.httpsCallable(...)` MUST NOT appear anywhere in `admin_cloud_functions.dart` until Phase 7.

## Phase 7 invocation pattern (reference only — not in scope for Spec 004)

```dart
final fns = FirebaseFunctions.instanceFor(region: 'europe-west1');
final callable = fns.httpsCallable('adminAssignJob');
await callable.call({'jobId': jobId, 'technicianId': technicianId});
```

Phase 7 specs will fill this in, each calling `verifyAdmin` server-side per Principle IX and writing audit fields per Principle XI.

## Error surfacing contract (Phase 7 — reference only)

When Phase 7 implements these methods, the Dart-side `FirebaseFunctionsException.message` will be the only field shown to the admin UI, per Principle XIII ("Error messages shown in the admin web UI on a failed CF call MUST use the `HttpsError.message` field only"). Implementers of Phase 7 must NOT show stack traces or full response JSON.

## Phase 6 verification

1. `cd .claude/AdminWebApp && flutter analyze` reports zero issues.
2. `import 'package:<package-name>/services/admin_cloud_functions.dart';` compiles.
3. Any runtime call to any of the 5 methods throws `UnimplementedError` whose `.message` contains the Dart method name.
