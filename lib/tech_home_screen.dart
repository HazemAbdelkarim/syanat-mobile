import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_service.dart';
import 'main.dart' show AppLocale;
import 'chat_screen.dart';
import 'glass_card.dart';
import 'job_status.dart' show jobStatusTechLabel;
import 'services/notification_service.dart';
import 'technician_active_job_screen.dart';
import 'technician_approve_payment_screen.dart';
import 'technician_job_detail_readonly_screen.dart';
import 'technician_profile_screen.dart';
import 'technician_receipt_screen.dart';
import 'settings_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class TechHomeScreen extends StatefulWidget {
  const TechHomeScreen({super.key});

  @override
  State<TechHomeScreen> createState() => _TechHomeScreenState();
}

class _TechHomeScreenState extends State<TechHomeScreen> {
  bool _loading = true;
  Object? _jobsError;
  // `_jobs` is an unfiltered list of every job assigned to this tech (last 50
  // by createdAt desc). Used only for the `_earnings` stat (sum over
  // completed jobs) and for the legacy-status migration check.
  // `_activeJobs` is the source of truth for the rendered active-jobs list
  // and the "Active Jobs" stat.
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _activeJobs = [];
  double _earnings = 0.0;
  double _rating = 0.0;
  bool _isAvailable = true;
  int _unreadNotifCount = 0;

  final Map<String, Map<String, dynamic>> _customerCache = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _jobsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<int>? _notifCountSub;
  StreamSubscription<List<Map<String, dynamic>>>? _activeJobsSub;

  // Release-006 notifications: diff status-per-jobId across jobs-stream
  // snapshots and fire local notifications for each non-self-caused
  // transition. First snapshot after auth populates the cache silently.
  final Map<String, String> _lastKnownStatus = {};
  bool _notifInitialSnapshotProcessed = false;

  @override
  void initState() {
    super.initState();
    _initAfterAuth();
  }

  Future<void> _initAfterAuth() async {
    // Wait for a non-null signed-in user. authStateChanges().first returns
    // the FIRST event which on cold web load can be null even if the user
    // is about to be hydrated — bailing on that null leaves the spinner
    // stuck. firstWhere with a timeout fixes the race without hanging.
    var user = FirebaseService.getCurrentUser();
    if (user == null) {
      try {
        user = await FirebaseService.auth
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        user = null;
      }
    }
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _loading = false;
        _jobsError = 'auth_not_ready';
      });
      return;
    }
    _subscribeProfile();
    _loadJobsRealtime();
    _subscribeNotifCount();
    _subscribeActiveJobs();
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _profileSub?.cancel();
    _notifCountSub?.cancel();
    _activeJobsSub?.cancel();
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

  void _subscribeActiveJobs() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    _activeJobsSub =
        FirebaseService.streamTechnicianActiveJobs(user.uid).listen((jobs) {
      if (mounted) {
        setState(() => _activeJobs = jobs);
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

  /// Best-effort: fetches customer display names for the cache.
  ///
  /// Failure here is intentionally non-fatal — `firestore.rules` does not let
  /// a technician list other users' documents (rule on `users/{uid}` is owner-
  /// or-admin only). When the read is denied the list still renders with the
  /// "Customer" fallback label. Errors must never escape this method, or they
  /// would crash the jobs stream listener and freeze the home screen on a
  /// spinner.
  Future<bool> _primeCustomerCache(List<Map<String, dynamic>> jobs) async {
    final missingIds = jobs
        .map((j) => (j['customerId'] as String?) ?? '')
        .where((id) => id.isNotEmpty && !_customerCache.containsKey(id))
        .toSet()
        .toList();

    if (missingIds.isEmpty) return false;

    var added = false;
    for (var i = 0; i < missingIds.length; i += 10) {
      final chunk = missingIds.skip(i).take(10).toList();
      try {
        final snap = await FirebaseService.firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          _customerCache[doc.id] = doc.data();
          added = true;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TechHome] customer cache chunk denied/failed: $e');
        }
      }
    }
    return added;
  }

  void _loadJobsRealtime() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      // _initAfterAuth already guards on this, but keep a defensive branch:
      // surface the state instead of leaving the spinner spinning.
      if (mounted) {
        setState(() {
          _loading = false;
          _jobsError = 'auth_not_ready';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _jobsError = null;
    });

    _jobsSub?.cancel();
    _jobsSub = FirebaseService.firestore
        .collection('jobs')
        .where('assignedTechnicianId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      final jobs = snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();

      // `_jobs` drives the earnings stat (sum over completed jobs) and the
      // legacy-status migration check at the bottom of the active list. The
      // active-jobs stat and the rendered list both come from `_activeJobs`
      // (plus legacy stragglers), not from this collection.
      final earnings = jobs
          .where((j) => j['status'] == 'completed')
          .fold<double>(
            0.0,
            (sum, j) => sum + (j['price'] as num? ?? 0).toDouble(),
          );

      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _earnings = earnings;
        _loading = false;
        _jobsError = null;
      });

      // Diff status-per-jobId and fire notifications for real transitions.
      // Runs AFTER paint so a notification miss never blocks the list.
      _processNotificationDiff(jobs);

      // Best-effort customer-name prime runs AFTER the UI is rendered. Its
      // failure (typical: rules deny tech reading customer users/*) cannot
      // freeze the spinner because we already cleared _loading above.
      _primeCustomerCache(jobs).then((added) {
        if (added && mounted) setState(() {});
      });
    }, onError: (e, st) {
      if (kDebugMode) {
        debugPrint('[TechHome] jobs stream error: $e\n$st');
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _jobsError = e;
        });
      }
    });
  }

  /// Release-006: diffs status-per-jobId vs cache and fires a local
  /// notification for each real, non-self-caused transition. The first
  /// snapshot after auth populates the cache silently — otherwise the tech
  /// would get a notification for every historical job on app open.
  void _processNotificationDiff(List<Map<String, dynamic>> jobs) {
    if (!mounted) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    for (final job in jobs) {
      final jobId = (job['id'] as String?) ?? '';
      if (jobId.isEmpty) continue;
      final newStatus = (job['status'] as String?) ?? '';
      final prevStatus = _lastKnownStatus[jobId];

      if (_notifInitialSnapshotProcessed &&
          prevStatus != null &&
          prevStatus != newStatus) {
        // Fire-and-forget — service swallows failures internally.
        NotificationService.notifyJobTransition(
          jobId: jobId,
          from: prevStatus,
          to: newStatus,
          viewer: ViewerRole.technician,
          isEn: isEn,
        );
      }
      _lastKnownStatus[jobId] = newStatus;
    }
    _notifInitialSnapshotProcessed = true;
  }

  void _retryJobs() {
    setState(() {
      _loading = true;
      _jobsError = null;
    });
    _jobsSub?.cancel();
    _initAfterAuth();
  }

  /// Returns the full-page widget to push when a tile in the active-jobs
  /// list is tapped. This is the single routing decision for active jobs —
  /// keep it here, don't scatter if/else chains through the build tree.
  ///
  /// Mapping:
  ///   active, technician_accepted, on_the_way, technician_arrived
  ///     → TechnicianActiveJobScreen (slider flow)
  ///   work_finished                → TechnicianReceiptScreen (fill receipt)
  ///   awaiting_payment_verification → TechnicianApprovePaymentScreen
  ///   awaiting_customer_approval, awaiting_payment, receipt_disputed
  ///     → TechnicianJobDetailReadonlyScreen (passive-wait, read-only)
  ///   any other                    → null (terminal/unknown — should not
  ///                                  appear in `_activeJobs` at all)
  Widget? _activeJobRouteFor(
      String status, Map<String, dynamic> job, String techId) {
    switch (status) {
      case 'active':
      case 'technician_accepted':
      case 'on_the_way':
      case 'technician_arrived':
        return TechnicianActiveJobScreen(
          job: job,
          technicianId: techId,
        );
      case 'work_finished':
        return TechnicianReceiptScreen(
          jobId: (job['id'] as String?) ?? '',
          technicianId: techId,
          job: Map<String, dynamic>.from(job),
        );
      case 'awaiting_payment_verification':
        return TechnicianApprovePaymentScreen(
          jobId: (job['id'] as String?) ?? '',
          technicianId: techId,
          job: Map<String, dynamic>.from(job),
        );
      case 'awaiting_customer_approval':
      case 'awaiting_payment':
      case 'receipt_disputed':
        return TechnicianJobDetailReadonlyScreen(
          job: Map<String, dynamic>.from(job),
        );
      default:
        return null;
    }
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

    // Multi-assignment: home screen always renders. The tech picks which
    // active job to drive by tapping a tile. Auto-routing was removed
    // because it bounced the tech back into the active screen on every
    // pop, making system back unusable.

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
                                _loading
                                    ? '…'
                                    : '${_activeJobs.length + _legacyJobsFromAll().length}',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                isEn ? 'Earnings Today' : 'Earnings Today',
                                _loading
                                    ? '—'
                                    : '${_earnings.toStringAsFixed(0)} EGP',
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
                          child: _buildJobsBody(isEn),
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

  Widget _buildJobsBody(bool isEn) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: syanatBlue),
      );
    }
    if (_jobsError != null) {
      final isAuth = _jobsError == 'auth_not_ready';
      final title = isAuth
          ? (isEn ? 'Signing in…' : 'جاري تسجيل الدخول...')
          : (isEn ? 'Could not load jobs.' : 'تعذر تحميل الوظائف.');
      final subtitle = isAuth
          ? (isEn
              ? 'Please wait or tap retry.'
              : 'يرجى الانتظار أو الضغط على إعادة المحاولة.')
          : (isEn
              ? 'Check your connection and try again.'
              : 'تحقق من الاتصال ثم أعد المحاولة.');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAuth ? Icons.lock_clock : Icons.error_outline,
                color: isAuth ? syanatBlue : Colors.red,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  _jobsError.toString(),
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _retryJobs,
                icon: const Icon(Icons.refresh),
                label: Text(isEn ? 'Retry' : 'إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: syanatBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final sortedActive = _sortActiveJobs(_activeJobs);
    final legacy = _legacyJobsFromAll();
    if (sortedActive.isEmpty && legacy.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined,
                  color: Colors.black26, size: 48),
              const SizedBox(height: 10),
              Text(
                isEn ? 'No active jobs yet.' : 'لا توجد وظائف نشطة بعد.',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? 'New jobs assigned by admin will appear here.'
                    : 'ستظهر الوظائف التي يعينها المسؤول هنا.',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final user = FirebaseService.getCurrentUser();
    return ListView(
      children: [
        ...sortedActive.map((j) => _buildActiveJobTile(j, isEn, user?.uid)),
        if (legacy.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildLegacySectionHeader(isEn),
          const SizedBox(height: 8),
          ...legacy.map((j) => _buildLegacyJobTile(j, isEn, user?.uid)),
        ],
      ],
    );
  }

  /// scheduledTime present → ascending by scheduled time.
  /// scheduledTime absent  → ascending by assignedAt.
  /// Two-bucket sort. Do NOT replace with a server-side
  /// `orderBy('scheduledTime')` — Firestore drops docs that lack the field
  /// (urgent/now orders write no `scheduledTime`).
  List<Map<String, dynamic>> _sortActiveJobs(List<Map<String, dynamic>> jobs) {
    final scheduled = <Map<String, dynamic>>[];
    final unscheduled = <Map<String, dynamic>>[];
    for (final j in jobs) {
      (j['scheduledTime'] is Timestamp ? scheduled : unscheduled).add(j);
    }
    scheduled.sort((a, b) => (a['scheduledTime'] as Timestamp)
        .compareTo(b['scheduledTime'] as Timestamp));
    unscheduled.sort((a, b) {
      final ta = a['assignedAt'] as Timestamp?;
      final tb = b['assignedAt'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
    return [...scheduled, ...unscheduled];
  }

  /// Filters `_jobs` for any straggler job still in a pre-release-006 status
  /// (`accepted`, `in_progress`, …). The plural active stream's whereIn does
  /// NOT include these statuses, so they would be invisible to the tech if
  /// we relied on `_activeJobs` alone. Once the stragglers are migrated (or
  /// admin-force-closed) and the count is verified zero in production, this
  /// helper and the migration code (`_legacyActiveStatuses`,
  /// `_legacyStatusMap`, `_migrateLegacyJob`) can all be removed.
  List<Map<String, dynamic>> _legacyJobsFromAll() {
    return _jobs
        .where((j) => _legacyActiveStatuses.contains(j['status']))
        .toList();
  }

  Widget _buildActiveJobTile(
      Map<String, dynamic> job, bool isEn, String? techId) {
    final status = (job['status'] as String?) ?? '';
    final customerId = (job['customerId'] as String?) ?? '';
    final customer = _customerCache[customerId] ?? const {};
    final username =
        (customer['username'] ?? customer['email'] ?? (isEn ? 'Customer' : 'العميل'))
            .toString();
    final address = ((job['locationAddress'] as String?)?.trim() ?? '');
    final dynamic scheduled = job['scheduledTime'];
    final scheduledLabel = scheduled is Timestamp
        ? _formatScheduledShort(scheduled.toDate())
        : (isEn ? 'No scheduled time' : 'بدون موعد محدد');
    final jobId = (job['id'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minVerticalPadding: 0,
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, color: Colors.black54),
          ),
          title: Text(username, style: const TextStyle(color: Colors.black)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${isEn ? 'Status' : 'الحالة'}: ${jobStatusTechLabel(status, isEn: isEn)}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                scheduledLabel,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          trailing: (techId == null || customerId.isEmpty || jobId.isEmpty)
              ? null
              : SizedBox(
                  width: 64,
                  child: ElevatedButton(
                    onPressed: () => _openChatForJob(customerId, jobId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: syanatBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                      minimumSize: const Size(64, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(isEn ? 'Chat' : 'محادثة'),
                  ),
                ),
          onTap: techId == null
              ? null
              : () {
                  final route = _activeJobRouteFor(status, job, techId);
                  if (route != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => route),
                    );
                  }
                },
        ),
      ),
    );
  }

  Future<void> _openChatForJob(String customerId, String jobId) async {
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
        builder: (_) => ChatScreen(chatId: chatId, isTechnician: true),
      ),
    );
  }

  String _formatScheduledShort(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $hh:$mm';
  }

  Widget _buildLegacySectionHeader(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          Text(
            isEn ? 'Needs migration' : 'تحتاج للترحيل',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyJobTile(
      Map<String, dynamic> job, bool isEn, String? techId) {
    final status = (job['status'] as String?) ?? '';
    final jobId = (job['id'] as String?) ?? '';
    final customerId = (job['customerId'] as String?) ?? '';
    final customer = _customerCache[customerId] ?? const {};
    final username =
        (customer['username'] ?? customer['email'] ?? (isEn ? 'Customer' : 'العميل'))
            .toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.history, color: Color(0xFFF59E0B)),
          title: Text(username, style: const TextStyle(color: Colors.black)),
          subtitle: Text(
            '${isEn ? 'Legacy status' : 'حالة قديمة'}: $status',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          trailing: (techId == null || jobId.isEmpty)
              ? null
              : SizedBox(
                  width: 64,
                  child: ElevatedButton(
                    onPressed: () => _migrateLegacyJob(jobId, techId, status),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
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
