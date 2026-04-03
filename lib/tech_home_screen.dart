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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
        .where('technicianId', isEqualTo: user.uid)
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
    });
  }

  void _switchLanguage() {
    final newLocale = Localizations.localeOf(context).languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    AppLocale.of(context).value = newLocale;
  }

  Future<void> _acceptJob(String jobId) async {
    try {
      await FirebaseService.firestore.collection('jobs').doc(jobId).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting: $e')),
      );
    }
  }

  Future<void> _rejectJob(String jobId) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    try {
      // Re-queue the job as urgent so it reappears in the admin "Requested" tab
      // for reassignment to another technician.
      await FirebaseService.firestore.collection('jobs').doc(jobId).update({
        'status': 'requested',
        'technicianId': '',
        'assignedTechnicianId': null,
        'assignedTechnicianName': null,
        'urgencyType': 'urgent',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn
              ? 'Job returned to admin for reassignment'
              : 'تم إعادة الطلب للإدارة لإعادة التعيين'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isEn ? "Error" : "خطأ"}: $e')),
      );
    }
  }

  Future<void> _completeJob(String jobId) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Mark Work Done' : 'تأكيد إنهاء العمل'),
        content: Text(
          isEn
              ? 'Mark this job as done on your end? The admin will record the payment and officially close the order.'
              : 'هل أنهيت العمل؟ الإدارة ستسجل المبلغ وتغلق الطلب رسمياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEn ? 'Cancel' : 'إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: syanatBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(isEn ? 'Mark Done' : 'تم الانتهاء'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // Signal to admin that work is done; status moves to in_progress.
      // Revenue is ONLY recorded when admin manually closes the job.
      await FirebaseService.firestore.collection('jobs').doc(jobId).update({
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final user = FirebaseService.getCurrentUser();

    if (_activeJob != null && user != null) {
      return TechnicianActiveJobScreen(
        job: _activeJob!,
        technicianId: user.uid,
      );
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
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  SizedBox(
                                                    width: 72,
                                                    child: ElevatedButton(
                                                      onPressed: () async {
                                                        final currentUser =
                                                            FirebaseService
                                                                .getCurrentUser();
                                                        if (currentUser == null ||
                                                            customerId.isEmpty) {
                                                          return;
                                                        }

                                                        final chatId =
                                                            await FirebaseService
                                                                .getOrCreateChat(
                                                          customerId,
                                                          currentUser.uid,
                                                          jobId: j['id'] as String,
                                                        );

                                                        if (!mounted) return;

                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                ChatScreen(
                                                              chatId: chatId,
                                                              isTechnician: true,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            syanatBlue,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                        textStyle:
                                                            const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                        minimumSize:
                                                            const Size(72, 32),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        isEn ? 'Chat' : 'Chat',
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  if (status == 'requested') ...[
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: syanatBlue,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                        padding: EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        onPressed: () => _acceptJob(
                                                          j['id'] as String,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        color: syanatBlue
                                                            .withOpacity(0.85),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                        padding: EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        onPressed: () => _rejectJob(
                                                          j['id'] as String,
                                                        ),
                                                      ),
                                                    ),
                                                  ] else if (status == 'accepted' ||
                                                      status == 'in_progress' ||
                                                      status == 'inprogress')
                                                    SizedBox(
                                                      width: 72,
                                                      child: ElevatedButton(
                                                        onPressed: () =>
                                                            _completeJob(
                                                          j['id'] as String,
                                                        ),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              syanatBlue,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 6,
                                                          ),
                                                          textStyle:
                                                              const TextStyle(
                                                            fontSize: 13,
                                                          ),
                                                          minimumSize:
                                                              const Size(72, 32),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(8),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          isEn
                                                              ? 'Done'
                                                              : 'تم',
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
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
