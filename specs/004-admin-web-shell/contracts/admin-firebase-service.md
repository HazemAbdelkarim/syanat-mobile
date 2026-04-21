# Contract: `AdminFirebaseService` (Dart)

**File**: `.claude/AdminWebApp/lib/services/admin_firebase_service.dart`
**Stability**: Declaring this contract is IN-SCOPE for Spec 004 (Phase 6). Implementing each stub is OUT-OF-SCOPE until Phase 7 (Spec 005).

## Imports required

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

## Class contract

```dart
class AdminFirebaseService {
  AdminFirebaseService();
  // 13 methods — see below.
}
```

The class is a plain value type. No fields. No dependencies injected via constructor in Phase 6. Phase 7 MAY add an optional `FirebaseFirestore` parameter for testability, but MUST preserve the no-arg constructor as the default.

## Methods — exact signatures

| # | Signature | Phase 6 behavior | Phase 7 behavior (target) |
|---|-----------|------------------|---------------------------|
| 1 | `Stream<DocumentSnapshot<Map<String, dynamic>>> streamStats()` | **IMPLEMENTED.** Returns `FirebaseFirestore.instance.doc('stats/global').snapshots()`. | Unchanged. |
| 2 | `Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveJobsAdmin()` | Throws `UnimplementedError('AdminFirebaseService.streamActiveJobsAdmin not implemented (Phase 7)')`. | Streams `jobs` where `status in ['requested','assigned','technician_accepted','active','awaiting_customer_approval','disputed']` ordered by `createdAt desc`. |
| 3 | `Stream<QuerySnapshot<Map<String, dynamic>>> streamJobsByStatus(String status)` | Stub (same pattern). | Streams `jobs.where('status', isEqualTo: status).orderBy('createdAt', descending: true).limit(100)`. |
| 4 | `Stream<QuerySnapshot<Map<String, dynamic>>> streamAllPayments()` | Stub. | Streams `payments` ordered by `createdAt desc limit 100`. |
| 5 | `Stream<QuerySnapshot<Map<String, dynamic>>> streamSupportChats()` | Stub. Note: name is `streamSupportChats`, NOT `streamAllSupportChats`. | Streams `support_chats` ordered by `updatedAt desc`. |
| 6 | `Stream<int> streamUnreadSupportCount()` | Stub. | Returns a stream of the count of `support_chats` where `adminUnread == true`. |
| 7 | `Future<void> markSupportChatReadByAdmin(String chatId)` | Stub. | Sets `adminUnread: false` on `support_chats/{chatId}`. |
| 8 | `Future<void> closeSupportChat(String chatId)` | Stub. | Sets `status: 'closed'` on `support_chats/{chatId}`. |
| 9 | `Future<void> sendSupportMessage({required String chatId, required String text})` | Stub. | Appends a message doc under `support_chats/{chatId}/messages`. |
| 10 | `Future<List<Map<String, dynamic>>> fetchRecentUsers({int limit = 10})` | Stub. | One-shot `.get()` on `users` ordered by `createdAt desc limit`. |
| 11 | `Future<List<Map<String, dynamic>>> fetchRecentActivity({int limit = 50})` | Stub. | One-shot `.get()` on `activity_log` ordered by `timestamp desc limit`. |
| 12 | `Future<List<String>> getAvailableTechnicianIdsByService(String serviceKey)` | Stub. | Queries `users` where `role == 'technician' && services contains serviceKey`. |
| 13 | `Future<void> initializeStatsGlobal()` | Stub. | One-time bootstrap write of all counter fields on `stats/global` with zeros; idempotent. |

## Error-message template (stubs)

Every stub MUST throw with this exact template:

```
'AdminFirebaseService.<methodName> not implemented (Phase 7)'
```

Where `<methodName>` is the Dart identifier — e.g., `streamActiveJobsAdmin`, `sendSupportMessage`, `initializeStatsGlobal`. Variance in the message (different wording, punctuation, or missing method name) is a spec defect.

## Phase 6 verification

1. `cd .claude/AdminWebApp && flutter analyze` reports zero issues.
2. Importing the class compiles:
   ```dart
   import 'package:<package-name>/services/admin_firebase_service.dart';
   void _ = () { AdminFirebaseService(); };
   ```
3. A runtime smoke test calling any of the 12 stubs inside a `try/catch` catches `UnimplementedError` whose `.message` contains the method name.
