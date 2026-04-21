# Contract: `AdminFirebaseService`

**File**: `.claude/AdminWebApp/lib/services/admin_firebase_service.dart`
**Purpose**: Every Firestore read and the three allowed Low-risk writes from the admin web app flow through this one class. No widget talks to `FirebaseFirestore.instance` directly. No method here bypasses an `.limit(...)` (FR-027, SC-004).

Modifies the Spec-004 stub file in place; does NOT create a new file. Every `UnimplementedError` thrown by Spec 004's stubs is replaced by a real implementation matching the signature below.

---

## Method: `streamStats`

```dart
Stream<DocumentSnapshot<Map<String, dynamic>>> streamStats()
```

**Behaviour**: returns the real-time stream of `stats/global`. Already implemented in Spec 004; this spec does NOT change it.

**Caller**: `OverviewScreen` — wraps it in a `StreamBuilder`, decodes to `StatsGlobal` model.

**Error behaviour**: stream errors propagate to the `StreamBuilder`, which renders the error banner from User Story 1 AS4.

---

## Method: `streamJobsByStatus`

```dart
Stream<QuerySnapshot<Map<String, dynamic>>> streamJobsByStatus(String status)
```

**Query** (exact):
```dart
FirebaseFirestore.instance
    .collection('jobs')
    .where('status', isEqualTo: status)
    .orderBy('createdAt', descending: true)
    .limit(50)
    .snapshots();
```

**Allowed `status` values** (enumerated via `JobStatus` constant; unknown values throw an `ArgumentError` synchronously — no silent fallback): `'requested' | 'active' | 'technician_accepted' | 'technician_arrived' | 'work_finished' | 'awaiting_customer_approval' | 'receipt_disputed' | 'completed' | 'cancelled'`.

**Callers**:
- Requested tab — `streamJobsByStatus('requested')`.
- Completed tab — `streamJobsByStatus('completed')`.
- Disputes screen — `streamJobsByStatus('receipt_disputed')` (research R-9).

**Composite index**: pre-existing `status` + `createdAt desc` (research R-4).

---

## Method: `streamActiveJobsAdmin`

```dart
Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveJobsAdmin()
```

**Query** (exact):
```dart
FirebaseFirestore.instance
    .collection('jobs')
    .where('status', whereIn: <String>[
      'active',
      'technician_accepted',
      'technician_arrived',
      'work_finished',
      'awaiting_customer_approval',
      'receipt_disputed',
    ])
    .orderBy('createdAt', descending: true)
    .limit(50)
    .snapshots();
```

**Caller**: Active tab of Jobs screen (read-only).

---

## Method: `streamAllPayments`

```dart
Stream<QuerySnapshot<Map<String, dynamic>>> streamAllPayments()
```

**Query** (exact):
```dart
FirebaseFirestore.instance
    .collection('payments')
    .orderBy('createdAt', descending: true)
    .limit(100)
    .snapshots();
```

**Caller**: Payments screen.

---

## Method: `streamSupportChats`

```dart
Stream<QuerySnapshot<Map<String, dynamic>>> streamSupportChats()
```

**Query** (exact):
```dart
FirebaseFirestore.instance
    .collection('support_chats')
    .orderBy('lastMessageAt', descending: true)
    .limit(50)
    .snapshots();
```

**Caller**: Support inbox.

---

## Method: `streamUnreadSupportCount`

```dart
Stream<int> streamUnreadSupportCount()
```

**Internal implementation** — returns the size of a bounded `support_chats` stream filtered to unread+open:
```dart
return FirebaseFirestore.instance
    .collection('support_chats')
    .where('unreadByAdmin', isEqualTo: true)
    .where('status', isEqualTo: 'open')
    .limit(100)
    .snapshots()
    .map((snap) => snap.size);
```

**NOT an aggregation `count()` call** (INPUT.md §C-4, FR-006). `count()` would cost one billed read per sidebar rebuild; the bounded stream costs one read per actual change.

**Caller**: `DashboardScreen.State` (research R-7), cancelled in the shell's `dispose()`.

**Composite index**: pre-existing `unreadByAdmin` + `status` (research R-4 row 5).

---

## Method: `streamActivityLog`

```dart
Stream<QuerySnapshot<Map<String, dynamic>>> streamActivityLog()
```

**Query** (exact):
```dart
FirebaseFirestore.instance
    .collection('activity_log')
    .orderBy('createdAt', descending: true)
    .limit(50)
    .snapshots();
```

**Caller**: Activity screen.

---

## Method: `getAvailableTechnicianIdsByService`

```dart
Future<List<TechnicianOption>> getAvailableTechnicianIdsByService(String serviceKey)
```

**Query** (exact, one-shot):
```dart
final snap = await FirebaseFirestore.instance
    .collection('users')
    .where('role', isEqualTo: 'technician')
    .where('availableForServices', arrayContains: serviceKey)
    .limit(100)
    .get();
return snap.docs.map(TechnicianOption.fromDoc).toList(growable: false);
```

**Caller**: `AssignDialog` — on dialog open, once (no stream).

**Composite index**: pre-existing `role` + `availableForServices array-contains` (research R-4 row 7).

**Validation**:
- If `serviceKey.trim().isEmpty`, throw `ArgumentError` synchronously — caller blocks the Assign action earlier, this is defense-in-depth.
- Return value has `length <= 100`.

---

## Method: `markSupportChatReadByAdmin`

```dart
Future<void> markSupportChatReadByAdmin(String chatId)
```

**Write** (exact):
```dart
await FirebaseFirestore.instance
    .collection('support_chats')
    .doc(chatId)
    .update({'unreadByAdmin': false});
```

**Caller**: Support inbox — on tap of an unread row, before navigating to the chat.

**Firestore-rule coverage**: `firestore.rules:377–384` (admin unrestricted update branch).

---

## Method: `closeSupportChat`

```dart
Future<void> closeSupportChat(String chatId)
```

**Write** (exact):
```dart
await FirebaseFirestore.instance
    .collection('support_chats')
    .doc(chatId)
    .update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
    });
```

**Caller**: Support chat screen — on confirmed "Close chat".

**Firestore-rule coverage**: same as above — admin unrestricted update.

---

## Method: `sendSupportMessage`

```dart
Future<void> sendSupportMessage({
  required String chatId,
  required String text,
})
```

**Validation (client-side, per FR-036)**:
- `text = text.trim()`; reject if `text.isEmpty` with `ArgumentError`.
- Cap at 2000 chars; reject above.

**Write** (exact, sequential):
```dart
final uid = FirebaseAuth.instance.currentUser!.uid;
final chatRef = FirebaseFirestore.instance.collection('support_chats').doc(chatId);

await chatRef.collection('messages').add({
  'senderId': uid,
  'text': text,
  'createdAt': FieldValue.serverTimestamp(),
});

await chatRef.update({
  'lastMessageAt': FieldValue.serverTimestamp(),
});
```

**Caller**: Support chat screen — on Send tap (button disabled while in-flight).

**Firestore-rule coverage**: message create is allowed for admins per `firestore.rules:410–415`. Parent update is allowed for admins per `firestore.rules:377`.

**Concurrency note**: if the network fails between the two writes, the message lands but `lastMessageAt` is stale by one update — the next message sent from either party heals it. Acceptable tradeoff (same as the mobile admin).

---

## Methods REMOVED from the Spec-004 stub file

The following stubs exist in Spec 004 but are **deferred / not needed** for this spec and MUST be removed from `admin_firebase_service.dart`:

- `fetchRecentUsers` — migration plan §7 defers it post-MVP.
- `fetchRecentActivity` — superseded by `streamActivityLog` (real-time stream, which is more useful).
- `initializeStatsGlobal` — stats are event-driven since Spec 003. A one-shot init utility is no longer a valid admin action; removing it closes a direct-write surface (Principle XII).

Removal is the right action per Principle VII (no premature abstraction — don't keep code that no longer has a caller).

---

## Common invariants across every method in this contract

1. No method exposes `FirebaseFirestore.instance` to UI code.
2. Every query chain terminates in `.limit(N)` or `.doc(id)`.
3. `FieldValue.serverTimestamp()` is always used instead of `Timestamp.fromDate(DateTime.now())`.
4. Every `Future<void>` write propagates exceptions — the caller catches `FirebaseException` and surfaces `code + message` via the shared error helper (contract: `admin-cloud-functions.md` §Error handling).
5. No method calls `debugPrint` or `print` with a document body (Principle VIII + XIII).
