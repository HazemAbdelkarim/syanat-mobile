import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_service.dart';
import 'main.dart' show AppLocale;
import 'chat_screen.dart';
import 'glass_card.dart';
import 'technician_active_job_screen.dart';
import 'technician_profile_screen.dart';
import 'settings_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class TechHomeScreen extends StatefulWidget {
  const TechHomeScreen({super.key});

  @override
  State<TechHomeScreen> createState() => _TechHomeScreenState();
}

class _TechHomeScreenState extends State<TechHomeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _jobs = [];
  int _activeCount = 0;
  double _earnings = 0.0;
  double _rating = 0.0;
  bool _isAvailable = true;
  int _unreadNotifCount = 0;
  Map<String, dynamic>? _activeJob;

  final Map<String, Map<String, dynamic>> _customerCache = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _jobsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<int>? _notifCountSub;
  StreamSubscription<Map<String, dynamic>?>? _activeJobSub;

  @override
  void initState() {
    super.initState();
    _initAfterAuth();
  }

  Future<void> _initAfterAuth() async {
    // Wait for Firebase Auth to confirm the session before subscribing to
    // any streams — prevents false "not logged in" state on web.
    await FirebaseService.auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (!mounted) return;
    _subscribeProfile();
    _loadJobsRealtime();
    _subscribeNotifCount();
    _subscribeActiveJob();
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _profileSub?.cancel();
    _notifCountSub?.cancel();
    _activeJobSub?.cancel();
    super.dispose();
  }

  void _subscribeProfile() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    _profileSub = FirebaseService.firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      final rating = (doc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
      final available = doc.data()?['available'] as bool? ?? true;
      if (!mounted) return;
      setState(() {
        _rating = rating;
        _isAvailable = available;
      });
    });
  }

  void _subscribeNotifCount() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;
    _notifCountSub =
        FirebaseService.streamTechnicianUnreadNotifCount(user.uid).listen((n) {
      if (mounted) setState(() => _unreadNotifCount = n);
    });
  }

  void _subscribeActiveJob() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    _activeJobSub =
        FirebaseService.streamTechnicianActiveJob(user.uid).listen((job) {
      if (mounted) {
        setState(() => _activeJob = job);
      }
    });
  }

  Future<void> _toggleAvailability() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;
    try {
      final newVal = !_isAvailable;
      await FirebaseService.updateAvailability(user.uid, newVal);
      // UI updates via profile stream
    } catch (e) {
      debugPrint('Toggle availability error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update availability. Please try again.')));
      }
    }
  }

  void _openNotifications() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) =>
          _TechNotificationsSheet(uid: user.uid, isEn: isEn),
    );
  }

  Future<void> _primeCustomerCache(List<Map<String, dynamic>> jobs) async {
    final missingIds = jobs
        .map((j) => (j['customerId'] as String?) ?? '')
        .where((id) => id.isNotEmpty && !_customerCache.containsKey(id))
        .toSet()
        .toList();

    if (missingIds.isEmpty) return;

    for (var i = 0; i < missingIds.length; i += 10) {
      final chunk = missingIds.skip(i).take(10).toList();
      final snap = await FirebaseService.firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        _customerCache[doc.id] = doc.data();
      }
    }
  }

  void _loadJobsRealtime() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    setState(() => _loading = true);

    _jobsSub = FirebaseService.firestore
        .collection('jobs')
        .where('assignedTechnicianId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
      final jobs = snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();

      final active = jobs
          .where(
            (j) {
              final s = j['status'] as String? ?? '';
              return s == 'active' ||
                  s == 'technician_accepted' ||
                  s == 'technician_arrived' ||
                  s == 'work_finished' ||
                  s == 'awaiting_customer_approval' ||
                  s == 'receipt_disputed' ||
                  s == 'accepted' ||
                  s == 'in_progress' ||
                  s == 'inprogress';
            },
          )
          .length;

      final earnings = jobs
          .where((j) => j['status'] == 'completed')
          .fold<double>(
            0.0,
            (sum, j) => sum + (j['price'] as num? ?? 0).toDouble(),
          );

      await _primeCustomerCache(jobs);
      if (!mounted) return;

      setState(() {
        _jobs = jobs;
        _activeCount = active;
        _earnings = earnings;
        _loading = false;
      });
    }, onError: (e) {
      debugPrint('Jobs stream error: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  void _switchLanguage() {
    final newLocale = Localizations.localeOf(context).languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    AppLocale.of(context).value = newLocale;
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final user = FirebaseService.getCurrentUser();

    // Lock into active-job screen only during known active work steps.
    // Passive waiting, disputed, and unknown statuses show home screen
    // so the tech can access notifications, settings, etc.
    const _lockedStatuses = {
      'active',
      'technician_accepted',
      'technician_arrived',
      'work_finished',
    };
    if (_activeJob != null && user != null) {
      final activeStatus = _activeJob!['status'] as String? ?? '';
      if (_lockedStatuses.contains(activeStatus)) {
        return TechnicianActiveJobScreen(
          job: _activeJob!,
          technicianId: user.uid,
        );
      }
    }

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        color: syanatBlue,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: syanatBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isEn ? 'Welcome Technician' : 'مرحباً بك',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Availability toggle
                            GestureDetector(
                              onTap: _toggleAvailability,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isAvailable
                                        ? Icons.circle
                                        : Icons.circle_outlined,
                                    size: 10,
                                    color: _isAvailable
                                        ? Colors.greenAccent
                                        : Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAvailable
                                        ? (isEn ? 'Available' : 'متاح')
                                        : (isEn ? 'Unavailable' : 'غير متاح'),
                                    style: TextStyle(
                                      color: _isAvailable
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          // Notification bell
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                onPressed: _openNotifications,
                                icon: const Icon(Icons.notifications,
                                    color: Colors.white),
                                tooltip: isEn ? 'Notifications' : 'الإشعارات',
                              ),
                              if (_unreadNotifCount > 0)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                        minWidth: 16, minHeight: 16),
                                    child: Text(
                                      _unreadNotifCount > 9
                                          ? '9+'
                                          : _unreadNotifCount.toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TechnicianProfileScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.person_outline, color: Colors.white),
                            tooltip: isEn ? 'Profile' : 'الملف الشخصي',
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings, color: Colors.white),
                            tooltip: isEn ? 'Settings' : 'الإعدادات',
                          ),
                          IconButton(
                            onPressed: _switchLanguage,
                            icon: const Icon(Icons.language, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                isEn ? 'Active Jobs' : 'Active Jobs',
                                '$_activeCount',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                isEn ? 'Earnings Today' : 'Earnings Today',
                                '${_earnings.toStringAsFixed(2)} EGP',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                isEn ? 'Rating' : 'Rating',
                                _rating > 0
                                    ? '★ ${_rating.toStringAsFixed(2)}'
                                    : '—',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Banner for passive-wait active job
                        if (_activeJob != null && user != null) ...[
                          _buildPassiveWaitBanner(isEn, user.uid),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          isEn ? 'Active Jobs' : 'Active Jobs',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: syanatBlue,
                                  ),
                                )
                              : _jobs.isEmpty
                                  ? Center(
                                      child: Text(
                                        isEn ? 'No jobs yet' : 'No jobs yet',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _jobs.length,
                                      itemBuilder: (context, index) {
                                        final j = _jobs[index];
                                        final status =
                                            j['status'] as String? ?? 'requested';
                                        final customerId =
                                            j['customerId'] as String? ?? '';
                                        final customer =
                                            _customerCache[customerId] ?? const {};
                                        final username = customer['username'] ??
                                            customer['email'] ??
                                            'Customer';
                                        final description = j['description'] ?? '';
                                        final price = j['price'] ?? 0;

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: GlassCard(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              8,
                                              4,
                                              8,
                                            ),
                                            child: ListTile(
                                              dense: true,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 0,
                                              ),
                                              minVerticalPadding: 0,
                                              leading: CircleAvatar(
                                                backgroundColor:
                                                    Colors.grey.shade300,
                                                child: const Icon(
                                                  Icons.person,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              title: Text(
                                                username.toString(),
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                ),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (description
                                                      .toString()
                                                      .isNotEmpty)
                                                    Text(
                                                      description.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    isEn
                                                        ? 'Status: $status'
                                                        : 'Status: $status',
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isEn
                                                        ? 'Price: $price EGP'
                                                        : 'Price: $price EGP',
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              trailing: _buildJobTrailing(
                                                status, customerId,
                                                j['id'] as String, isEn),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassiveWaitBanner(bool isEn, String techId) {
    final status = _activeJob!['status'] as String? ?? '';
    final isDisputed = status == 'receipt_disputed';
    final color = isDisputed ? Colors.red.shade400 : syanatBlue;
    final icon = isDisputed ? Icons.gavel : Icons.hourglass_top;
    final title = isDisputed
        ? (isEn ? 'Receipt Disputed — Admin Reviewing' : 'إيصال متنازع عليه — الإدارة تراجع')
        : (isEn ? 'Awaiting Customer Approval' : 'بانتظار موافقة العميل');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TechnicianActiveJobScreen(
              job: _activeJob!,
              technicianId: techId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  /// Legacy statuses that have active work but may lack assignedTechnicianId,
  /// meaning they won't be caught by the active-job stream.
  static const _legacyActiveStatuses = {
    'accepted', 'in_progress', 'inprogress', 'en_route', 'payment_pending',
  };

  /// Maps a legacy status to its closest new-flow equivalent.
  static const _legacyStatusMap = {
    'accepted': 'technician_accepted',
    'en_route': 'technician_arrived',
    'in_progress': 'work_finished',
    'inprogress': 'work_finished',
    'payment_pending': 'awaiting_customer_approval',
  };

  /// Migrates a legacy job to the new flow by setting assignedTechnicianId
  /// AND normalizing the status so the active-job screen has a valid step.
  Future<void> _migrateLegacyJob(
      String jobId, String techId, String currentStatus) async {
    final newStatus = _legacyStatusMap[currentStatus];
    if (newStatus == null) return; // unknown — don't touch
    try {
      await FirebaseService.firestore.collection('jobs').doc(jobId).update({
        'assignedTechnicianId': techId,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Job status update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  Widget _buildJobTrailing(
      String status, String customerId, String jobId, bool isEn) {
    // Status badge color/label
    Color badgeColor;
    String badgeLabel;
    switch (status) {
      case 'completed':
        badgeColor = const Color(0xFF10B981);
        badgeLabel = isEn ? 'Done' : 'مكتمل';
        break;
      case 'cancelled':
        badgeColor = const Color(0xFFEF4444);
        badgeLabel = isEn ? 'Cancelled' : 'ملغي';
        break;
      default:
        badgeColor = syanatBlue;
        badgeLabel = isEn ? 'Active' : 'نشط';
    }

    final user = FirebaseService.getCurrentUser();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chat button for non-terminal statuses
        if (status != 'completed' && status != 'cancelled')
          SizedBox(
            width: 64,
            child: ElevatedButton(
              onPressed: () async {
                final currentUser = FirebaseService.getCurrentUser();
                if (currentUser == null || customerId.isEmpty) return;
                final chatId = await FirebaseService.getOrCreateChat(
                  customerId,
                  currentUser.uid,
                  jobId: jobId,
                );
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: chatId,
                      isTechnician: true,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: syanatBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
                minimumSize: const Size(64, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isEn ? 'Chat' : 'محادثة'),
            ),
          ),
        // Legacy fallback: "Open" button migrates the job to the new flow
        if (_legacyActiveStatuses.contains(status) && user != null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: SizedBox(
              width: 64,
              child: ElevatedButton(
                onPressed: () => _migrateLegacyJob(jobId, user.uid, status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: const Size(64, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(isEn ? 'Open' : 'فتح'),
              ),
            ),
          ),
        const SizedBox(width: 6),
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badgeLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _TechNotificationsSheet — Technician notification center
// ═════════════════════════════════════════════════════════════════════════════

class _TechNotificationsSheet extends StatelessWidget {
  final String uid;
  final bool isEn;

  const _TechNotificationsSheet({required this.uid, required this.isEn});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      shouldCloseOnMinExtent: true,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEn ? 'Notifications' : 'الإشعارات',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    tooltip: isEn ? 'Close' : 'إغلاق',
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(ctx).maybePop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService.streamTechnicianNotifications(uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: syanatBlue));
                  }
                  final notifs = snapshot.data!;
                  if (notifs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_none,
                              size: 56, color: Colors.black26),
                          const SizedBox(height: 12),
                          Text(
                            isEn
                                ? 'No notifications yet'
                                : 'لا توجد إشعارات بعد',
                            style: const TextStyle(color: Colors.black45),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final n = notifs[i];
                      final notifId = n['id'] as String? ?? '';
                      final isRead = n['read'] as bool? ?? false;
                      final serviceCategory =
                          n['serviceCategory'] as String? ??
                              n['serviceKey'] as String? ?? '—';
                      final customerName =
                          n['customerName'] as String? ?? '—';
                      final urgency = n['urgencyType'] as String? ?? '';
                      final locationAddress =
                          n['locationAddress'] as String? ?? '';
                      final createdAt = n['createdAt'];
                      String dateStr = '';
                      if (createdAt is Timestamp) {
                        final dt = createdAt.toDate();
                        dateStr =
                            '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      }

                      return GestureDetector(
                        onTap: () {
                          if (!isRead && notifId.isNotEmpty) {
                            FirebaseService.markNotificationRead(notifId);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead
                                ? Colors.grey.shade50
                                : syanatBlue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRead
                                  ? Colors.grey.shade200
                                  : syanatBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: syanatBlue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.work,
                                    color: syanatBlue, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      serviceCategory,
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${isEn ? 'Customer' : 'العميل'}: $customerName',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54),
                                    ),
                                    if (locationAddress.isNotEmpty)
                                      Text(
                                        locationAddress,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (urgency.isNotEmpty)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(top: 4),
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: urgency == 'urgent'
                                              ? Colors.red.withOpacity(0.1)
                                              : Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          urgency == 'urgent'
                                              ? (isEn ? 'Urgent' : 'عاجل')
                                              : (isEn
                                                  ? 'Scheduled'
                                                  : 'مجدول'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: urgency == 'urgent'
                                                ? Colors.red
                                                : Colors.blue,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Text(dateStr,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black38)),
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: syanatBlue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
