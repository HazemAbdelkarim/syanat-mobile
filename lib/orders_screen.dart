import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'support_chat_screen.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------

/// Statuses that appear in the "Ongoing" tab.
const _ongoingStatuses = {
  'requested',
  'accepted',
  'en_route',
  'payment_pending',
  'in_progress',
  'inprogress'
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
  StreamSubscription<Map<String, dynamic>?>? _pendingPaymentSub;
  Map<String, dynamic>? _pendingPayment;
  bool _confirmingPendingPayment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final user = FirebaseService.getCurrentUser();
    if (user != null) {
      _pendingPaymentSub =
          FirebaseService.streamCustomerActivePayment(user.uid).listen((job) {
        if (mounted) {
          setState(() => _pendingPayment = job);
        }
      });
    }
  }

  @override
  void dispose() {
    _pendingPaymentSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final user = FirebaseService.getCurrentUser();

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            isEn ? 'My Orders' : 'طلباتي',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: [
              Tab(text: isEn ? 'Ongoing' : 'جارية'),
              Tab(text: isEn ? 'Recent' : 'حديثة'),
              Tab(text: isEn ? 'Cancelled' : 'ملغية'),
            ],
          ),
        ),
        body: user == null
            ? _buildNotLoggedIn(isEn)
            : _buildTabViews(user.uid, isEn),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Tab views — one StreamBuilder per tab filter
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

        final allJobs = snapshot.data ?? [];

        final ongoing = allJobs
            .where((j) => _ongoingStatuses.contains(j['status'] as String? ?? ''))
            .toList();
        final recent = allJobs
            .where((j) => _recentStatuses.contains(j['status'] as String? ?? ''))
            .toList();
        final cancelled = allJobs
            .where((j) => _cancelledStatuses.contains(j['status'] as String? ?? ''))
            .toList();

        return TabBarView(
          controller: _tabController,
          children: [
            _buildJobList(
              jobs: ongoing,
              emptyIcon: Icons.pending_actions,
              emptyLabel: isEn ? 'No ongoing orders' : 'لا توجد طلبات جارية',
              isEn: isEn,
              topWidget: _buildPendingPaymentBanner(uid, isEn),
            ),
            _buildJobList(
              jobs: recent,
              emptyIcon: Icons.check_circle_outline,
              emptyLabel: isEn ? 'No recent orders' : 'لا توجد طلبات حديثة',
              isEn: isEn,
            ),
            _buildJobList(
              jobs: cancelled,
              emptyIcon: Icons.cancel_outlined,
              emptyLabel: isEn ? 'No cancelled orders' : 'لا توجد طلبات ملغية',
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
      return _buildEmptyState(icon: emptyIcon, label: emptyLabel);
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
          return _buildEmptyState(icon: emptyIcon, label: emptyLabel);
        }
        return _buildJobCard(jobs[jobIndex], isEn);
      },
    );
  }

  Widget? _buildPendingPaymentBanner(String uid, bool isEn) {
    final payment = _pendingPayment;
    if (payment == null) return null;

    final amount = (payment['technicianPaymentAmount'] as num?)?.toDouble();
    final jobId = payment['id'] as String? ?? '';
    if (amount == null || jobId.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Color(0xFFFF9800), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Payment Confirmation Required' : 'مطلوب تأكيد الدفع',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(2)} EGP',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isEn
                ? 'Only confirm the exact amount you paid. Do not confirm if the amount was changed. This protects your rights and ensures accurate service records.'
                : 'قم بالتأكيد فقط إذا كان هذا هو المبلغ الذي دفعته بالضبط. لا تقبل أي تعديل على المبلغ. هذا يحمي حقوقك ويضمن دقة سجلات الخدمة.',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmingPendingPayment
                      ? null
                      : () => _confirmPendingPayment(jobId, uid, isEn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _confirmingPendingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEn ? 'Confirm' : 'تأكيد'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportChatScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: Text(isEn ? 'Report Issue' : 'الإبلاغ عن مشكلة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPendingPayment(String jobId, String uid, bool isEn) async {
    setState(() => _confirmingPendingPayment = true);
    try {
      await FirebaseService.confirmCustomerPayment(jobId, uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Payment confirmed successfully.' : 'تم تأكيد الدفع بنجاح.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Error: $e' : 'خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _confirmingPendingPayment = false);
      }
    }
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000), // black @ 6% opacity
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top strip: service key + status badge ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x0D3C21C8), // _syanatBlue @ 5% opacity
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Service icon + key
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x1F3C21C8), // _syanatBlue @ 12% opacity
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.home_repair_service,
                        color: _syanatBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _serviceLabel(serviceKey, isEn),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo['color'] as Color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusInfo['icon'] as IconData,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusInfo['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                ],

                // Price + date row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          price > 0
                              ? '${price.toStringAsFixed(0)} EGP'
                              : (isEn ? 'TBD' : 'سيُحدَّد'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: price > 0
                                ? Colors.green.shade700
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),

                    // Job ID chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${jobId.length > 6 ? jobId.substring(0, 6).toUpperCase() : jobId.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Date
                    if (dateStr.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Bottom action buttons ────────────────────────────────────
          if (_ongoingStatuses.contains(status))
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _showCancelDialog(context, jobId, isEn),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(isEn ? 'Cancel Order' : 'إلغاء الطلب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Dialog for cancel confirmation
  // -----------------------------------------------------------------------

  void _showCancelDialog(BuildContext context, String jobId, bool isEn) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEn ? 'Cancel Order?' : 'إلغاء الطلب؟'),
        content: Text(
          isEn
              ? 'Are you sure you want to cancel this order? This action cannot be undone.'
              : 'هل أنت متأكد من إلغاء هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isEn ? 'Keep It' : 'الاحتفاظ به'),
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
                        isEn ? 'Order cancelled successfully' : 'تم إلغاء الطلب بنجاح',
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
                        isEn ? 'Failed to cancel order: $e' : 'فشل إلغاء الطلب: $e',
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
            child: Text(isEn ? 'Cancel Order' : 'إلغاء الطلب'),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Map<String, dynamic> _statusInfo(String status, bool isEn) {
    switch (status) {
      case 'requested':
        return {
          'label': isEn ? 'Requested' : 'مطلوب',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.hourglass_top,
        };
      case 'accepted':
        return {
          'label': isEn ? 'Accepted' : 'مقبول',
          'color': const Color(0xFF3B82F6),
          'icon': Icons.thumb_up_alt_outlined,
        };
      case 'en_route':
        return {
          'label': isEn ? 'En Route' : 'في الطريق',
          'color': const Color(0xFF2563EB),
          'icon': Icons.directions_car,
        };
      case 'payment_pending':
        return {
          'label': isEn ? 'Payment Pending' : 'بانتظار الدفع',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.payments_outlined,
        };
      case 'in_progress':
        return {
          'label': isEn ? 'In Progress' : 'قيد التنفيذ',
          'color': const Color(0xFF8B5CF6),
          'icon': Icons.construction,
        };
      case 'completed':
        return {
          'label': isEn ? 'Completed' : 'مكتمل',
          'color': const Color(0xFF10B981),
          'icon': Icons.check_circle,
        };
      case 'cancelled':
        return {
          'label': isEn ? 'Cancelled' : 'ملغي',
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
    'ac': 'تكييف',
    'plumbing': 'سباكة',
    'electricity': 'كهرباء',
    'security_intercom': 'أنظمة أمن وإنتركم',
    'large_appliances': 'أجهزة منزلية كبيرة',
    'small_appliances': 'أجهزة منزلية صغيرة',
    'carpentry': 'نجارة',
    'pest_control': 'مكافحة حشرات',
    'aluminum': 'ألوميتال',
    'finishing': 'تشطيبات',
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

  Widget _buildEmptyState({required IconData icon, required String label}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
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
            isEn ? 'Please log in to view your orders' : 'يرجى تسجيل الدخول لمشاهدة طلباتك',
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
              isEn ? 'Failed to load orders' : 'فشل تحميل الطلبات',
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
