import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

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
  'technician_arrived',
  'work_finished',
  'awaiting_customer_approval',
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
  StreamSubscription<Map<String, dynamic>?>? _pendingReceiptSub;
  Map<String, dynamic>? _pendingReceipt;
  // Populated once auth state is confirmed, then used in build().
  User? _user;

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
      _pendingReceiptSub =
          FirebaseService.streamCustomerPendingReceipt(user.uid).listen((job) {
        if (mounted) {
          setState(() => _pendingReceipt = job);
        }
      });
    }
  }

  @override
  void dispose() {
    _pendingReceiptSub?.cancel();
    _tabController.dispose();
    super.dispose();
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
              topWidget: _buildPendingReceiptBanner(uid, isEn),
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

  Widget? _buildPendingReceiptBanner(String uid, bool isEn) {
    final receipt = _pendingReceipt;
    if (receipt == null) return null;

    final jobId = receipt['id'] as String? ?? '';
    if (jobId.isEmpty) return null;

    final receiptData = receipt['receipt'] as Map<String, dynamic>?;
    final grandTotal = (receiptData?['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final techName = receipt['assignedTechnicianName'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showReceiptApprovalSheet(
          context, uid, jobId, receipt, receiptData, isEn),
      child: Container(
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
        child: Row(
          children: [
            const Icon(Icons.receipt_long, color: _syanatBlue, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn
                        ? 'Receipt Ready for Review'
                        : 'Ø§Ù„Ø¥ÙŠØµØ§Ù„ Ø¬Ø§Ù‡Ø² Ù„Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEn
                        ? 'Total: ${grandTotal.toStringAsFixed(0)} EGP${techName.isNotEmpty ? ' Â· $techName' : ''}'
                        : 'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ: ${grandTotal.toStringAsFixed(0)} Ø¬Ù†ÙŠÙ‡${techName.isNotEmpty ? ' Â· $techName' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _syanatBlue.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  void _showReceiptApprovalSheet(
    BuildContext context,
    String uid,
    String jobId,
    Map<String, dynamic> job,
    Map<String, dynamic>? receiptData,
    bool isEn,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiptApprovalSheet(
        uid: uid,
        jobId: jobId,
        receiptData: receiptData,
        isEn: isEn,
        onApproved: () => FirebaseService.approveReceipt(jobId, uid),
        approving: false,
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
    final price = (job['price'] as num?)?.toDouble() ?? 0.0;
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Receipt approval bottom sheet (customer-side)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ReceiptApprovalSheet extends StatefulWidget {
  final String uid;
  final String jobId;
  final Map<String, dynamic>? receiptData;
  final bool isEn;
  final Future<void> Function() onApproved;
  // approving param kept for API compat but loading managed locally
  final bool approving;

  const _ReceiptApprovalSheet({
    required this.uid,
    required this.jobId,
    required this.receiptData,
    required this.isEn,
    required this.onApproved,
    required this.approving,
  });

  @override
  State<_ReceiptApprovalSheet> createState() => _ReceiptApprovalSheetState();
}

class _ReceiptApprovalSheetState extends State<_ReceiptApprovalSheet> {
  bool _approving = false;

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEn;
    final receiptData = widget.receiptData;
    final services = (receiptData?['services'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final parts = (receiptData?['parts'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final servicesSubtotal =
        (receiptData?['servicesSubtotal'] as num?)?.toDouble() ?? 0.0;
    final partsSubtotal =
        (receiptData?['partsSubtotal'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (receiptData?['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final notes = receiptData?['notes'] as String? ?? '';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          shouldCloseOnMinExtent: true,
          builder: (ctx, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Title
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: _syanatBlue, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEn ? 'Service Receipt' : 'Ø¥ÙŠØµØ§Ù„ Ø§Ù„Ø®Ø¯Ù…Ø©',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: isEn ? 'Close' : 'إغلاق',
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(ctx).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // â”€â”€ Disclaimer (customer-only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6A817)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFCC8400), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Important Notice' : 'ØªÙ†Ø¨ÙŠÙ‡ Ù…Ù‡Ù…',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF7A4F00),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEn
                          ? 'Please make sure the prices listed here match exactly what you paid. Any manipulation in prices must not be tolerated. The technician must enter the exact prices paid by you â€” these are our official reference for any complaint, dispute, or use of the 14-day free checkup guarantee.'
                          : 'ØªØ£ÙƒØ¯ Ù…Ù† Ø£Ù† Ø§Ù„Ø£Ø³Ø¹Ø§Ø± Ø§Ù„Ù…Ø¯Ø±Ø¬Ø© Ù‡Ù†Ø§ ØªØ·Ø§Ø¨Ù‚ ØªÙ…Ø§Ù…Ù‹Ø§ Ù…Ø§ Ø¯ÙØ¹ØªÙ‡. Ø£ÙŠ ØªÙ„Ø§Ø¹Ø¨ ÙÙŠ Ø§Ù„Ø£Ø³Ø¹Ø§Ø± ÙŠØ¬Ø¨ Ø¹Ø¯Ù… Ø§Ù„ØªØ³Ø§Ù…Ø­ Ù…Ø¹Ù‡. ÙŠØ¬Ø¨ Ø¹Ù„Ù‰ Ø§Ù„ÙÙ†ÙŠ Ø¥Ø¯Ø®Ø§Ù„ Ø§Ù„Ø£Ø³Ø¹Ø§Ø± Ø§Ù„ÙØ¹Ù„ÙŠØ© Ø§Ù„ØªÙŠ Ø¯ÙØ¹ØªÙ‡Ø§ â€” Ù‡Ø°Ù‡ Ù‡ÙŠ Ù…Ø±Ø¬Ø¹Ù†Ø§ Ø§Ù„Ø±Ø³Ù…ÙŠ ÙÙŠ Ø­Ø§Ù„Ø© Ø£ÙŠ Ø´ÙƒÙˆÙ‰ Ø£Ùˆ Ø®Ù„Ø§Ù Ø£Ùˆ Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø¶Ù…Ø§Ù† Ø§Ù„ÙØ­Øµ Ø§Ù„Ù…Ø¬Ø§Ù†ÙŠ Ù„Ù…Ø¯Ø© 14 ÙŠÙˆÙ…Ù‹Ø§.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A4F00),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // â”€â”€ Services â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (services.isNotEmpty) ...[
                _sectionTitle(
                    isEn
                        ? 'Services Performed'
                        : 'Ø§Ù„Ø®Ø¯Ù…Ø§Øª Ø§Ù„Ù…Ù†Ø¬Ø²Ø©',
                    isEn),
                const SizedBox(height: 10),
                ...services.map((s) => _receiptRow(
                      s['title'] as String? ?? '',
                      (s['price'] as num?)?.toDouble() ?? 0.0,
                    )),
                const SizedBox(height: 6),
                _subtotalRow(
                    isEn ? 'Services Subtotal' : 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø®Ø¯Ù…Ø§Øª',
                    servicesSubtotal),
              ],

              // â”€â”€ Parts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (parts.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle(
                    isEn ? 'Parts Used' : 'Ø§Ù„Ù‚Ø·Ø¹ Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù…Ø©',
                    isEn),
                const SizedBox(height: 10),
                ...parts.map((p) => _receiptRow(
                      p['name'] as String? ?? '',
                      (p['price'] as num?)?.toDouble() ?? 0.0,
                    )),
                const SizedBox(height: 6),
                _subtotalRow(
                    isEn ? 'Parts Subtotal' : 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù‚Ø·Ø¹',
                    partsSubtotal),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(thickness: 1.5),
              ),

              // â”€â”€ Grand Total â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn ? 'Grand Total' : 'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„ÙƒÙ„ÙŠ',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${grandTotal.toStringAsFixed(0)} EGP',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _syanatBlue,
                    ),
                  ),
                ],
              ),

              // â”€â”€ Notes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Technician Note' : 'Ù…Ù„Ø§Ø­Ø¸Ø© Ø§Ù„ÙÙ†ÙŠ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(notes,
                          style: const TextStyle(fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // â”€â”€ Action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _approving
                      ? null
                      : () async {
                          setState(() => _approving = true);
                          try {
                            await widget.onApproved();
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(widget.isEn
                                  ? 'Order completed successfully.'
                                  : 'ØªÙ… Ø¥ØªÙ…Ø§Ù… Ø§Ù„Ø·Ù„Ø¨ Ø¨Ù†Ø¬Ø§Ø­.'),
                              backgroundColor: Colors.green,
                            ));
                          } catch (e) {
                            debugPrint('Approve receipt error: $e');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(widget.isEn
                                  ? 'Something went wrong. Please try again.'
                                  : 'Ø­Ø¯Ø« Ø®Ø·Ø£. ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.'),
                              backgroundColor: Colors.red,
                            ));
                          } finally {
                            if (mounted) setState(() => _approving = false);
                          }
                        },
                  icon: _approving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isEn
                        ? 'Approve Receipt'
                        : 'Ø§Ù„Ù…ÙˆØ§ÙÙ‚Ø© Ø¹Ù„Ù‰ Ø§Ù„Ø¥ÙŠØµØ§Ù„',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _approving
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(isEn
                                  ? 'Reject Receipt?'
                                  : 'Ø±ÙØ¶ Ø§Ù„Ø¥ÙŠØµØ§Ù„ØŸ'),
                              content: Text(isEn
                                  ? 'This will flag the order for admin review. The admin will mediate between you and the technician.'
                                  : 'Ø³ÙŠØªÙ… ØªØ­ÙˆÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨ Ù„Ù„Ø¥Ø¯Ø§Ø±Ø© Ù„Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©. Ø³ØªØªÙˆØ³Ø· Ø§Ù„Ø¥Ø¯Ø§Ø±Ø© Ø¨ÙŠÙ†Ùƒ ÙˆØ¨ÙŠÙ† Ø§Ù„ÙÙ†ÙŠ.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(isEn ? 'Cancel' : 'Ø¥Ù„ØºØ§Ø¡'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(isEn ? 'Reject' : 'Ø±ÙØ¶'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true || !mounted) return;
                          setState(() => _approving = true);
                          try {
                            await FirebaseService.rejectReceipt(
                                widget.jobId, widget.uid);
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isEn
                                  ? 'Receipt rejected. Admin will review.'
                                  : 'ØªÙ… Ø±ÙØ¶ Ø§Ù„Ø¥ÙŠØµØ§Ù„. Ø³ØªÙ‚ÙˆÙ… Ø§Ù„Ø¥Ø¯Ø§Ø±Ø© Ø¨Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©.'),
                              backgroundColor: Colors.orange,
                            ));
                          } catch (e) {
                            debugPrint('Reject receipt error: $e');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isEn
                                  ? 'Something went wrong. Please try again.'
                                  : 'Ø­Ø¯Ø« Ø®Ø·Ø£. ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.'),
                              backgroundColor: Colors.red,
                            ));
                          } finally {
                            if (mounted) {
                              setState(() => _approving = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    isEn ? 'Reject Receipt' : 'Ø±ÙØ¶ Ø§Ù„Ø¥ÙŠØµØ§Ù„',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isEn) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.3),
    );
  }

  Widget _receiptRow(String label, double price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child:
                Text(label, style: const TextStyle(fontSize: 14, height: 1.3)),
          ),
          const SizedBox(width: 16),
          Text(
            '${price.toStringAsFixed(0)} EGP',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _subtotalRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500)),
        Text(
          '${amount.toStringAsFixed(0)} EGP',
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
