import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'customer_payment_screen.dart';
import 'customer_receipt_approval_screen.dart';
import 'firebase_service.dart';
import 'job_status.dart' show jobDisplayPrice, jobStatusCustomerLabel;
import 'services/notification_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

// â”€â”€â”€ Premium Theme Colors â”€â”€â”€
const Color kPrimary = Color(0xFF6C3CE1);
const Color kPrimaryDark = Color(0xFF5228B5);
const Color kSurfaceBg = Color(0xFFF6F7F9);
const Color kCardBg = Color(0xFFFFFFFF);
const Color kTextPrimary = Color(0xFF1A1A2E);
const Color kTextSecondary = Color(0xFF6B7280);
const Color kTextMuted = Color(0xFF8B8FA3);
const Color kSuccessBg = Color(0xFFECFDF5);
const Color kSuccessText = Color(0xFF10B981);
const Color kDangerBg = Color(0xFFFEF2F2);
const Color kDangerText = Color(0xFFEF4444);
const Color kOngoingBg = Color(0xFFF3EEFF);
const Color kOngoingText = Color(0xFF6C3CE1);
const Color kDivider = Color(0x0F000000);
const Color kNavInactive = Color(0xFF9CA3AF);

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------

/// Statuses that appear in the "Ongoing" tab.
const _ongoingStatuses = {
  'requested',
  // new flow
  'active',
  'technician_accepted',
  'on_the_way',
  'technician_arrived',
  'work_finished',
  'awaiting_customer_approval',
  'awaiting_payment',
  'awaiting_payment_verification',
  'receipt_disputed',
  // legacy statuses (backward compat for existing data)
  'accepted',
  'en_route',
  'payment_pending',
  'in_progress',
  'inprogress',
};

/// Statuses that appear in the "Recent" (completed) tab.
const _recentStatuses = {'completed'};

/// Statuses that appear in the "Cancelled" tab.
const _cancelledStatuses = {'cancelled'};

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Release-006: broader than the old pending-receipt stream — covers every
  // non-terminal customer job so the top-of-list action card can show the
  // right next-step for each lifecycle state.
  StreamSubscription<Map<String, dynamic>?>? _activeOrderSub;
  Map<String, dynamic>? _activeOrder;
  // Populated once auth state is confirmed, then used in build().
  User? _user;

  // Release-006 notifications: listens to the customer's full jobs stream
  // (not just the active-order narrow stream — we need to catch the
  // `awaiting_payment_verification → completed` transition, which moves the
  // job OUT of the active set). On each snapshot we diff status-per-jobId
  // against the local cache and fire a notification for each real change
  // that wasn't self-caused.
  StreamSubscription<List<Map<String, dynamic>>>? _notifJobsSub;
  final Map<String, String> _lastKnownStatus = {};
  bool _notifInitialSnapshotProcessed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initUser();
  }

  Future<void> _initUser() async {
    final user = await FirebaseService.auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (!mounted) return;
    setState(() => _user = user);
    if (user != null) {
      _activeOrderSub =
          FirebaseService.streamCustomerActiveOrder(user.uid).listen((job) {
        if (mounted) {
          setState(() => _activeOrder = job);
        }
      });
      _notifJobsSub = FirebaseService.streamJobs(
        uid: user.uid,
        role: 'customer',
      ).listen(_handleNotificationSnapshot);
    }
  }

  @override
  void dispose() {
    _activeOrderSub?.cancel();
    _notifJobsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Diffs status-per-jobId against the local cache and fires a local
  /// notification for each real transition that wasn't self-caused. The
  /// first snapshot after auth populates the cache but suppresses
  /// notifications — otherwise opening the app would fire one for every
  /// historical state, which is useless noise.
  void _handleNotificationSnapshot(List<Map<String, dynamic>> jobs) {
    final isEn = mounted &&
        Localizations.localeOf(context).languageCode == 'en';

    for (final job in jobs) {
      final jobId = (job['id'] as String?) ?? '';
      if (jobId.isEmpty) continue;
      final newStatus = (job['status'] as String?) ?? '';
      final prevStatus = _lastKnownStatus[jobId];

      if (_notifInitialSnapshotProcessed &&
          prevStatus != null &&
          prevStatus != newStatus) {
        // Fire-and-forget — notification failures are non-critical and the
        // service swallows them internally.
        NotificationService.notifyJobTransition(
          jobId: jobId,
          from: prevStatus,
          to: newStatus,
          viewer: ViewerRole.customer,
          isEn: isEn,
        );
      }
      _lastKnownStatus[jobId] = newStatus;
    }
    _notifInitialSnapshotProcessed = true;
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final user = _user;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.20,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 8, 20, 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7C4DFF),
                    Color(0xFF6C3CE1),
                    Color(0xFF5228B5)
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        isEn ? 'My Orders' : 'Ø·Ù„Ø¨Ø§ØªÙŠ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 26,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    indicatorSize: TabBarIndicatorSize.label,
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.6),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                              (isEn ? 'Ongoing' : 'Ø¬Ø§Ø±ÙŠØ©').toUpperCase()),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                              (isEn ? 'Recent' : 'ØØ¯ÙŠØ«Ø©').toUpperCase()),
                        ),
                      ),
                      Tab(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text((isEn ? 'Cancelled' : 'Ù…Ù„ØºÙŠØ©')
                              .toUpperCase()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: user == null
                  ? _buildNotLoggedIn(isEn)
                  : _buildTabViews(user.uid, isEn),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Tab views â€” one StreamBuilder per tab filter
  // -----------------------------------------------------------------------

  Widget _buildTabViews(String uid, bool isEn) {
    // Single stream for this user's jobs, ordered newest-first.
    final stream = FirebaseService.streamJobs(uid: uid, role: 'customer');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _syanatBlue),
          );
        }
        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString(), isEn);
        }

        final allJobs = (snapshot.data ?? [])
            .where((j) => j['hiddenForCustomer'] != true)
            .toList();

        final ongoing = allJobs
            .where(
                (j) => _ongoingStatuses.contains(j['status'] as String? ?? ''))
            .toList();
        final recent = allJobs
            .where(
                (j) => _recentStatuses.contains(j['status'] as String? ?? ''))
            .toList();
        final cancelled = allJobs
            .where((j) =>
                _cancelledStatuses.contains(j['status'] as String? ?? ''))
            .toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _buildJobList(
              jobs: ongoing,
              emptyIcon: Icons.pending_actions,
              emptyLabel: isEn
                  ? 'No ongoing orders'
                  : 'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ù„Ø¨Ø§Øª Ø¬Ø§Ø±ÙŠØ©',
              isEn: isEn,
              topWidget: _buildActiveOrderCard(uid, isEn),
            ),
            _buildJobList(
              jobs: recent,
              emptyIcon: Icons.check_circle_outline,
              emptyLabel: isEn
                  ? 'No recent orders'
                  : 'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ù„Ø¨Ø§Øª Ø­Ø¯ÙŠØ«Ø©',
              isEn: isEn,
            ),
            _buildJobList(
              jobs: cancelled,
              emptyIcon: Icons.cancel_outlined,
              emptyLabel: isEn
                  ? 'No cancelled orders'
                  : 'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø·Ù„Ø¨Ø§Øª Ù…Ù„ØºÙŠØ©',
              isEn: isEn,
            ),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Job list
  // -----------------------------------------------------------------------

  Widget _buildJobList({
    required List<Map<String, dynamic>> jobs,
    required IconData emptyIcon,
    required String emptyLabel,
    required bool isEn,
    Widget? topWidget,
  }) {
    if (jobs.isEmpty && topWidget == null) {
      return _buildEmptyState(icon: emptyIcon, label: emptyLabel, isEn: isEn);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: jobs.length + (topWidget == null ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (topWidget != null && index == 0) {
          return topWidget;
        }
        final jobIndex = topWidget == null ? index : index - 1;
        if (jobIndex >= jobs.length) {
          return _buildEmptyState(
              icon: emptyIcon, label: emptyLabel, isEn: isEn);
        }
        return _buildJobCard(jobs[jobIndex], isEn);
      },
    );
  }

  /// Release-006 active-order card — renders the customer's currently-in-
  /// flight order at the top of the Ongoing tab, with a status-driven
  /// action area below it. Returns null when there's no active order so
  /// the list's `topWidget` slot stays empty.
  ///
  /// The routing decision (what button or read-only message to show for
  /// each status) lives in the top-level [customerOrderAction] function,
  /// which is unit-testable — see `test/orders_action_test.dart`.
  Widget? _buildActiveOrderCard(String uid, bool isEn) {
    final order = _activeOrder;
    if (order == null) return null;

    final status = (order['status'] as String?) ?? '';
    final techName =
        (order['assignedTechnicianName'] as String?)?.trim() ?? '';
    final statusLabel = jobStatusCustomerLabel(status, isEn: isEn);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: _syanatBlue, width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  color: _syanatBlue, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Current Order' : 'الطلب الحالي',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      techName.isNotEmpty
                          ? (isEn
                              ? 'Technician: $techName'
                              : 'الفني: $techName')
                          : statusLabel,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusLabel,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _syanatBlue),
          ),
          const SizedBox(height: 12),
          customerOrderAction(context, order, uid, isEn),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Individual job card
  // -----------------------------------------------------------------------

  Widget _buildJobCard(Map<String, dynamic> job, bool isEn) {
    final status = (job['status'] as String? ?? 'requested').toLowerCase();
    final serviceKey = job['serviceKey'] as String? ?? '';
    final description = job['description'] as String? ?? '';
    final price = jobDisplayPrice(job).toDouble();
    final createdAt = job['createdAt'];
    final jobId = job['id'] as String? ?? '';

    // Format date
    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    final statusInfo = _statusInfo(status, isEn);
    final isOngoing = _ongoingStatuses.contains(status);

    final canDelete = status == 'cancelled' || status == 'completed';

    return Dismissible(
        key: Key(jobId),
        direction:
            canDelete ? DismissDirection.endToStart : DismissDirection.none,
        confirmDismiss: (direction) async {
          if (!canDelete) return false;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(isEn ? 'Delete Order?' : 'Ø­Ø°Ù Ø§Ù„Ø·Ù„Ø¨ØŸ'),
              content: Text(isEn
                  ? 'Are you sure you want to delete this order from your history?'
                  : 'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø­Ø°Ù Ù‡Ø°Ø§ Ø§Ù„Ø·Ù„Ø¨ Ù…Ù† Ø§Ù„Ø³Ø¬Ù„ØŸ'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(isEn ? 'Cancel' : 'Ø¥Ù„ØºØ§Ø¡'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isEn ? 'Delete' : 'Ø­Ø°Ù',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (confirmed != true) return false;
          try {
            await FirebaseService.hideJobForCustomer(jobId);
            return true;
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEn
                      ? 'Failed to delete order. Please try again.'
                      : 'ÙØ´Ù„ Ø­Ø°Ù Ø§Ù„Ø·Ù„Ø¨. ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.'),
                ),
              );
            }
            return false;
          }
        },
        onDismissed: (direction) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(isEn ? 'Order deleted' : 'ØªÙ… Ø­Ø°Ù Ø§Ù„Ø·Ù„Ø¨')),
          );
        },
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.red
                .withOpacity(0.08), // Premium soft red background for the swipe
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20), // Premium softer radius
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000), // even softer shadow
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // â”€â”€ Top strip: service key + status badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Service icon + key
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.home_repair_service,
                              color: _syanatBlue,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _serviceLabel(serviceKey, isEn),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${jobId.length > 6 ? jobId.substring(0, 6).toUpperCase() : jobId.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status badge & Delete Action
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: status == 'cancelled'
                                ? Colors.transparent
                                : (statusInfo['color'] as Color)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: status == 'cancelled'
                                ? null
                                : Border.all(
                                    color: (statusInfo['color'] as Color)
                                        .withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusInfo['icon'] as IconData,
                                color: statusInfo['color'] as Color,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusInfo['label'] as String,
                                style: TextStyle(
                                  color: statusInfo['color'] as Color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canDelete) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () =>
                                _confirmAndDeleteJob(context, jobId, isEn),
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              child: Icon(Icons.delete_outline,
                                  color: Colors.red, size: 20),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

              // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Price + date row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Row(
                          children: [
                            Icon(Icons.payments_outlined,
                                size: 18, color: Colors.green.shade600),
                            const SizedBox(width: 6),
                            Text(
                              price > 0
                                  ? '${price.toStringAsFixed(0)} EGP'
                                  : (isEn
                                      ? 'Price TBD'
                                      : 'Ø§Ù„Ø³Ø¹Ø± Ø³ÙŠÙØ­Ø¯ÙŽÙ‘Ø¯'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: price > 0
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),

                        // Date
                        if (dateStr.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Timeline tracking for Ongoing
                    if (isOngoing) ...[
                      const SizedBox(height: 16),
                      _OrderTimeline(status: status, isEn: isEn),
                    ],
                  ],
                ),
              ),

              // â”€â”€ Bottom action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              // Customer can only cancel before technician accepts (requested/active).
              // After acceptance, only admin can cancel.
              if (isOngoing && (status == 'requested' || status == 'active'))
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFA),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SizedBox(
                      height: 38,
                      child: TextButton.icon(
                        onPressed: () =>
                            _showCancelDialog(context, jobId, isEn),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(
                          isEn ? 'Cancel Order' : 'Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ));
  }

  // -----------------------------------------------------------------------
  // Dialog for cancel confirmation
  // -----------------------------------------------------------------------

  void _showCancelDialog(BuildContext context, String jobId, bool isEn) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEn ? 'Cancel Order?' : 'Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨ØŸ'),
        content: Text(
          isEn
              ? 'Are you sure you want to cancel this order? This action cannot be undone.'
              : 'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø¥Ù„ØºØ§Ø¡ Ù‡Ø°Ø§ Ø§Ù„Ø·Ù„Ø¨ØŸ Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„ØªØ±Ø§Ø¬Ø¹ Ø¹Ù† Ù‡Ø°Ø§ Ø§Ù„Ø¥Ø¬Ø±Ø§Ø¡.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isEn ? 'Keep It' : 'Ø§Ù„Ø§Ø­ØªÙØ§Ø¸ Ø¨Ù‡'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseService.cancelJob(jobId);
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEn
                            ? 'Order cancelled successfully'
                            : 'ØªÙ… Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨ Ø¨Ù†Ø¬Ø§Ø­',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEn
                            ? 'Failed to cancel order. Please try again.'
                            : 'ÙØ´Ù„ Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨. ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(isEn ? 'Cancel Order' : 'Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø·Ù„Ø¨'),
          ),
        ],
      ),
    );
  }

  // Dialog for deleting a terminal (cancelled/completed) order from history.
  Future<void> _confirmAndDeleteJob(
      BuildContext context, String jobId, bool isEn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Delete Order?' : 'Ø­Ø°Ù Ø§Ù„Ø·Ù„Ø¨ØŸ'),
        content: Text(isEn
            ? 'Are you sure you want to delete this order from your history?'
            : 'Ù‡Ù„ Ø£Ù†Øª Ù…ØªØ£ÙƒØ¯ Ù…Ù† Ø­Ø°Ù Ù‡Ø°Ø§ Ø§Ù„Ø·Ù„Ø¨ Ù…Ù† Ø§Ù„Ø³Ø¬Ù„ØŸ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEn ? 'Cancel' : 'Ø¥Ù„ØºØ§Ø¡'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isEn ? 'Delete' : 'Ø­Ø°Ù',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseService.hideJobForCustomer(jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isEn ? 'Order deleted' : 'ØªÙ… Ø­Ø°Ù Ø§Ù„Ø·Ù„Ø¨')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn
              ? 'Failed to delete order. Please try again.'
              : 'ÙØ´Ù„ Ø­Ø°Ù Ø§Ù„Ø·Ù„Ø¨. ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Map<String, dynamic> _statusInfo(String status, bool isEn) {
    switch (status) {
      case 'requested':
        return {
          'label': isEn ? 'Requested' : 'Ù…Ø·Ù„ÙˆØ¨',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.hourglass_top,
        };
      // New flow statuses
      case 'active':
        return {
          'label': isEn
              ? 'Pending Acceptance'
              : 'Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ù‚Ø¨ÙˆÙ„ Ø§Ù„ÙÙ†ÙŠ',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.hourglass_bottom,
        };
      case 'technician_accepted':
        return {
          'label': isEn ? 'Assigned' : 'ØªÙ… Ø§Ù„ØªØ¹ÙŠÙŠÙ†',
          'color': const Color(0xFF3B82F6),
          'icon': Icons.person_pin_outlined,
        };
      case 'on_the_way':
        return {
          'label': isEn ? 'On the Way' : 'في الطريق',
          'color': const Color(0xFF2563EB),
          'icon': Icons.directions_car,
        };
      case 'technician_arrived':
        return {
          'label': isEn ? 'Tech Arrived' : 'Ø§Ù„ÙÙ†ÙŠ ÙˆØµÙ„',
          'color': const Color(0xFF2563EB),
          'icon': Icons.directions_walk,
        };
      case 'work_finished':
        return {
          'label': isEn ? 'Work Done' : 'Ø§ÙƒØªÙ…Ù„ Ø§Ù„Ø¹Ù…Ù„',
          'color': const Color(0xFF8B5CF6),
          'icon': Icons.construction,
        };
      case 'awaiting_customer_approval':
        return {
          'label': isEn ? 'Awaiting Approval' : 'Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ù…ÙˆØ§ÙÙ‚ØªÙƒ',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.receipt_long_outlined,
        };
      case 'awaiting_payment':
        return {
          'label': isEn ? 'Payment Due' : 'بانتظار الدفع',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.payments_outlined,
        };
      case 'awaiting_payment_verification':
        return {
          'label': isEn ? 'Verifying Payment' : 'تأكيد الدفع',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.verified_outlined,
        };
      case 'receipt_disputed':
        return {
          'label': isEn ? 'Disputed' : 'Ù…ØªÙ†Ø§Ø²Ø¹ Ø¹Ù„ÙŠÙ‡',
          'color': const Color(0xFFEF4444),
          'icon': Icons.gavel,
        };
      // Legacy statuses
      case 'accepted':
        return {
          'label': isEn ? 'Accepted' : 'Ù…Ù‚Ø¨ÙˆÙ„',
          'color': const Color(0xFF3B82F6),
          'icon': Icons.thumb_up_alt_outlined,
        };
      case 'en_route':
        return {
          'label': isEn ? 'En Route' : 'ÙÙŠ Ø§Ù„Ø·Ø±ÙŠÙ‚',
          'color': const Color(0xFF2563EB),
          'icon': Icons.directions_car,
        };
      case 'payment_pending':
        return {
          'label': isEn ? 'Payment Pending' : 'Ø¨Ø§Ù†ØªØ¸Ø§Ø± Ø§Ù„Ø¯ÙØ¹',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.payments_outlined,
        };
      case 'in_progress':
        return {
          'label': isEn ? 'In Progress' : 'Ù‚ÙŠØ¯ Ø§Ù„ØªÙ†ÙÙŠØ°',
          'color': const Color(0xFF8B5CF6),
          'icon': Icons.construction,
        };
      case 'completed':
        return {
          'label': isEn ? 'Completed' : 'Ù…ÙƒØªÙ…Ù„',
          'color': const Color(0xFF10B981),
          'icon': Icons.check_circle,
        };
      case 'cancelled':
        return {
          'label': isEn ? 'Cancelled' : 'Ù…Ù„ØºÙŠ',
          'color': const Color(0xFFEF4444),
          'icon': Icons.cancel,
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.info_outline,
        };
    }
  }

  static const _serviceLabelsEn = {
    'ac': 'Air Conditioning',
    'plumbing': 'Plumbing',
    'electricity': 'Electrical',
    'security_intercom': 'Security & Intercom',
    'large_appliances': 'Large Appliances',
    'small_appliances': 'Small Appliances',
    'carpentry': 'Carpentry',
    'pest_control': 'Pest Control',
    'aluminum': 'Aluminum',
    'finishing': 'Finishing',
  };

  static const _serviceLabelsAr = {
    'ac': 'ØªÙƒÙŠÙŠÙ',
    'plumbing': 'Ø³Ø¨Ø§ÙƒØ©',
    'electricity': 'ÙƒÙ‡Ø±Ø¨Ø§Ø¡',
    'security_intercom': 'Ø£Ù†Ø¸Ù…Ø© Ø£Ù…Ù† ÙˆØ¥Ù†ØªØ±ÙƒÙ…',
    'large_appliances': 'Ø£Ø¬Ù‡Ø²Ø© Ù…Ù†Ø²Ù„ÙŠØ© ÙƒØ¨ÙŠØ±Ø©',
    'small_appliances': 'Ø£Ø¬Ù‡Ø²Ø© Ù…Ù†Ø²Ù„ÙŠØ© ØµØºÙŠØ±Ø©',
    'carpentry': 'Ù†Ø¬Ø§Ø±Ø©',
    'pest_control': 'Ù…ÙƒØ§ÙØ­Ø© Ø­Ø´Ø±Ø§Øª',
    'aluminum': 'Ø£Ù„ÙˆÙ…ÙŠØªØ§Ù„',
    'finishing': 'ØªØ´Ø·ÙŠØ¨Ø§Øª',
  };

  /// Returns the localized service label for a given key.
  /// Falls back to capitalizing the key if it's not in the map.
  String _serviceLabel(String key, bool isEn) {
    final map = isEn ? _serviceLabelsEn : _serviceLabelsAr;
    return map[key] ??
        key
            .split(RegExp(r'[_\-\s]+'))
            .map((p) => p.isEmpty
                ? ''
                : p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : ''))
            .join(' ');
  }

  Widget _buildEmptyState(
      {required IconData icon, required String label, required bool isEn}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _syanatBlue.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(icon, size: 72, color: _syanatBlue.withOpacity(0.7)),
              ),
              const SizedBox(height: 32),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isEn
                    ? "When you place an order, it will appear here."
                    : "Ø¹Ù†Ø¯Ù…Ø§ ØªÙ‚ÙˆÙ… Ø¨ØªÙ‚Ø¯ÙŠÙ… Ø·Ù„Ø¨ØŒ Ø³ÙŠØ¸Ù‡Ø± Ù‡Ù†Ø§.",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotLoggedIn(bool isEn) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isEn
                ? 'Please log in to view your orders'
                : 'ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù„Ù…Ø´Ø§Ù‡Ø¯Ø© Ø·Ù„Ø¨Ø§ØªÙƒ',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error, bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              isEn
                  ? 'Failed to load orders'
                  : 'ÙØ´Ù„ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨Ø§Øª',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  final String status;
  final bool isEn;

  const _OrderTimeline({required this.status, required this.isEn});

  @override
  Widget build(BuildContext context) {
    // Unified timeline covering both new and legacy status flows
    final Map<String, String> stepsLabelEn = {
      'requested': 'Requested',
      'technician_accepted': 'Assigned',
      'technician_arrived': 'Arrived',
      'work_finished': 'Work Done',
      'awaiting_customer_approval': 'Approval',
    };
    final Map<String, String> stepsLabelAr = {
      'requested': 'Ù…Ø·Ù„ÙˆØ¨',
      'technician_accepted': 'ØªÙ… Ø§Ù„ØªØ¹ÙŠÙŠÙ†',
      'technician_arrived': 'ÙˆØµÙ„',
      'work_finished': 'Ø§ÙƒØªÙ…Ù„',
      'awaiting_customer_approval': 'Ù…ÙˆØ§ÙÙ‚Ø©',
    };

    final List<String> stepKeys = [
      'requested',
      'technician_accepted',
      'technician_arrived',
      'work_finished',
      'awaiting_customer_approval',
    ];

    // Map legacy and intermediate statuses to the closest timeline step
    String normalizedStatus = status;
    const _legacyMap = {
      'active': 'requested', // admin assigned but tech hasn't accepted yet
      'accepted': 'technician_accepted',
      'en_route': 'technician_arrived',
      'in_progress': 'work_finished',
      'inprogress': 'work_finished',
      'payment_pending': 'awaiting_customer_approval',
      'receipt_disputed': 'awaiting_customer_approval',
    };
    normalizedStatus = _legacyMap[status] ?? status;

    int currentStepIndex = stepKeys.indexOf(normalizedStatus);
    if (currentStepIndex == -1) {
      if (status == 'completed') {
        currentStepIndex = stepKeys.length;
      } else {
        currentStepIndex = 0;
      }
    }

    final labels = isEn ? stepsLabelEn : stepsLabelAr;

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          Row(
            children: List.generate(stepKeys.length * 2 - 1, (index) {
              if (index % 2 == 0) {
                // Circle
                final stepIndex = index ~/ 2;
                final isCompleted = stepIndex <= currentStepIndex;
                final isActive = stepIndex == currentStepIndex;

                return Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color(0xFF3C21C8)
                        : Colors.grey.shade200,
                    border: isActive
                        ? Border.all(
                            color: const Color(0xFF3C21C8).withOpacity(0.3),
                            width: 4)
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                );
              } else {
                // Line
                final stepIndex = index ~/ 2;
                final isCompleted = stepIndex < currentStepIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? const Color(0xFF3C21C8)
                        : Colors.grey.shade200,
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stepKeys.length, (index) {
              final isCompleted = index <= currentStepIndex;
              final isActive = index == currentStepIndex;
              return Expanded(
                child: Center(
                  child: Text(
                    labels[stepKeys[index]]!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isCompleted
                          ? const Color(0xFF3C21C8)
                          : Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// customerOrderAction — status → action widget
//
// Public so it's unit-testable without exposing the entire _OrdersScreenState.
// Returns the action widget to render under the active-order card for a given
// job status. For passive-wait states (customer has no next step) it returns
// a read-only message; for action states it returns a primary button that
// navigates to the right customer screen.
//
// Release-006 status → action map:
//   requested / active / technician_accepted / on_the_way /
//     technician_arrived / work_finished → read-only status message
//   awaiting_customer_approval           → "Review receipt" button
//   awaiting_payment                     → "Pay technician" button
//   awaiting_payment_verification        → read-only "Tech is confirming"
//   receipt_disputed                     → read-only "Admin is reviewing"
//   completed                            → read-only "Paid X EGP" (edge case —
//                                          normally filtered from the active
//                                          stream, but guarded anyway)
//   anything else                        → customer-facing label from
//                                          jobStatusCustomerLabel
// ─────────────────────────────────────────────────────────────────────────────

Widget customerOrderAction(
  BuildContext context,
  Map<String, dynamic> job,
  String customerId,
  bool isEn,
) {
  final status = (job['status'] as String?) ?? '';
  final jobId = (job['id'] as String?) ?? '';

  switch (status) {
    case 'requested':
    case 'active':
    case 'technician_accepted':
    case 'on_the_way':
    case 'technician_arrived':
    case 'work_finished':
      return _readOnlyActionMessage(
          jobStatusCustomerLabel(status, isEn: isEn));

    case 'awaiting_customer_approval':
      return _primaryActionButton(
        label: isEn ? 'Review receipt' : 'راجع الفاتورة',
        icon: Icons.receipt_long,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerReceiptApprovalScreen(
              jobId: jobId,
              customerId: customerId,
              job: Map<String, dynamic>.from(job),
            ),
          ),
        ),
      );

    case 'awaiting_payment':
      return _primaryActionButton(
        label: isEn ? 'Pay technician' : 'ادفع للفني',
        icon: Icons.payments_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerPaymentScreen(
              jobId: jobId,
              customerId: customerId,
              job: Map<String, dynamic>.from(job),
            ),
          ),
        ),
      );

    case 'awaiting_payment_verification':
      return _readOnlyActionMessage(isEn
          ? 'Technician is confirming your payment.'
          : 'الفني يؤكد عملية الدفع.');

    case 'receipt_disputed':
      return _readOnlyActionMessage(isEn
          ? 'Receipt disputed — admin is reviewing.'
          : 'الفاتورة محل نزاع — الإدارة تراجع.');

    case 'completed':
      final amountPaid = (job['amountPaid'] as num?)?.toDouble() ?? 0.0;
      return _readOnlyActionMessage(isEn
          ? 'Completed — ${amountPaid.toStringAsFixed(0)} EGP paid.'
          : 'اكتملت — ${amountPaid.toStringAsFixed(0)} جنيه مدفوعة.');

    default:
      return _readOnlyActionMessage(
          jobStatusCustomerLabel(status, isEn: isEn));
  }
}

Widget _readOnlyActionMessage(String message) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x1F3C21C8)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: _syanatBlue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}

Widget _primaryActionButton({
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return SizedBox(
    width: double.infinity,
    height: 44,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _syanatBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
