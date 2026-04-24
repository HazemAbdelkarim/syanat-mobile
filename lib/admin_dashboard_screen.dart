import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth_gate.dart';
import '../firebase_service.dart';
import '../admin_support_chat_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _jobsTabController;

  int totalUsers = 0;
  int customers = 0;
  int technicians = 0;

  double totalRevenue = 0.0;

  int jobsRequested = 0;
  int jobsOngoing = 0;
  int jobsFinished = 0;
  int jobsCancelled = 0;

  int activeChats = 0;

  bool _loading = true;

  int _unreadSupportCount = 0;
  StreamSubscription<int>? _supportCountSub;

  /// True while a stats fetch is already in-flight; prevents overlapping calls.
  bool _fetching = false;

  /// One-time fetch for recent users — refreshed explicitly, not via stream.
  late Future<List<Map<String, dynamic>>> _recentUsersFuture;

  /// One-time fetch for recent activity — refreshed explicitly, not via stream.
  late Future<List<Map<String, dynamic>>> _recentActivityFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _jobsTabController = TabController(length: 3, vsync: this);
    _recentUsersFuture = FirebaseService.fetchRecentUsers(limit: 3);
    _recentActivityFuture = FirebaseService.fetchRecentActivity(limit: 10);
    _loadAllStats();
    _supportCountSub = FirebaseService.streamUnreadSupportCount().listen(
      (n) {
        if (mounted) setState(() => _unreadSupportCount = n);
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jobsTabController.dispose();
    _supportCountSub?.cancel();
    super.dispose();
  }

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  Future<void> _loadAllStats() async {
    // In-flight guard: drop concurrent calls caused by multiple RefreshIndicators
    // or rapid refresh taps while a fetch is already running.
    if (_fetching) return;
    _fetching = true;
    if (mounted) setState(() {
      _loading = true;
      _recentUsersFuture = FirebaseService.fetchRecentUsers(limit: 3);
      _recentActivityFuture = FirebaseService.fetchRecentActivity(limit: 10);
    });

    try {
      final firestore = FirebaseService.firestore;

      // ── Fast path: single document read ──────────────────────────────────
      // When a Cloud Function (or admin write) keeps stats/global up-to-date,
      // the entire dashboard costs exactly 1 Firestore read.
      final statsSnap = await firestore.doc('stats/global').get();
      final statsData = statsSnap.data() ?? {};

      // Revenue = total technician payout (full amountPaid on completed jobs).
      // We do NOT multiply by a platform-margin factor; the admin calculates
      // their own bottom line manually outside the app.
      final totalEarnings =
          (statsData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
      final revenue = totalEarnings;

      final int? aggUsers       = (statsData['totalUsers']    as num?)?.toInt();
      final int? aggCustomers   = (statsData['customers']     as num?)?.toInt();
      final int? aggTechnicians = (statsData['technicians']   as num?)?.toInt();
      final int? aggRequested   = (statsData['jobsRequested'] as num?)?.toInt();
      final int? aggOngoing     = (statsData['jobsOngoing']   as num?)?.toInt();
      final int? aggCompleted   = (statsData['jobsCompleted'] as num?)?.toInt();
      final int? aggChats       = (statsData['activeChats']   as num?)?.toInt();
      // jobsCancelled is now stored in stats/global — no separate count() needed.
      final int? aggCancelled   = (statsData['jobsCancelled'] as num?)?.toInt();

      // Use stats/global values directly — defaults to 0 for any missing field.
      // If the doc is missing or incomplete, log a warning so the admin can
      // run the stats initializer rather than silently falling back to
      // expensive aggregation queries.
      if (!statsSnap.exists ||
          aggUsers == null || aggCustomers == null || aggTechnicians == null ||
          aggRequested == null || aggOngoing == null || aggCompleted == null ||
          aggChats == null || aggCancelled == null) {
        debugPrint(
          '[AdminDashboard] stats/global is missing or incomplete — '
          'run FirebaseService.initializeStatsGlobal() to seed counters.',
        );
      }

      final usersCount     = aggUsers ?? 0;
      final custCount      = aggCustomers ?? 0;
      final techCount      = aggTechnicians ?? 0;
      final reqCount       = aggRequested ?? 0;
      final ongCount       = aggOngoing ?? 0;
      final finCount       = aggCompleted ?? 0;
      final chatCount      = aggChats ?? 0;
      final cancelledCount = aggCancelled ?? 0;

      if (!mounted) return;
      setState(() {
        totalUsers    = usersCount;
        customers     = custCount;
        technicians   = techCount;
        totalRevenue  = revenue;
        jobsRequested = reqCount;
        jobsOngoing   = ongCount;
        jobsFinished  = finCount;
        activeChats   = chatCount;
        jobsCancelled = cancelledCount;
        _loading      = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(isEn, 'Error loading stats. Please try again.', 'حصل خطأ في تحميل الإحصائيات. حاول مرة أخرى.'),
          ),
        ),
      );
    } finally {
      _fetching = false;
    }
  }


  Future<void> _refreshStats() async {
    await _loadAllStats();
    if (!mounted) return;

    final isEn = Localizations.localeOf(context).languageCode == 'en';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(isEn, 'Dashboard refreshed!', 'تم تحديث لوحة التحكم!'),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseService.auth.signOut();
    if (!mounted) return;

    // Reset the navigator to the root AuthGate so it observes the signed-out
    // state (authStateChanges emits null) and rebuilds to LoginScreen. Never
    // push SplashScreen here — the splash is purely visual and has no routing.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            _t(isEn, 'Dashboard', 'لوحة التحكم'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: syanatBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _refreshStats,
              icon: const Icon(Icons.refresh),
              tooltip: _t(isEn, 'Refresh', 'تحديث'),
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  child: Text(_t(isEn, 'Export CSV', 'تصدير CSV')),
                ),
                PopupMenuItem(
                  value: 'users',
                  child: Text(_t(isEn, 'Manage Users', 'إدارة المستخدمين')),
                ),
                PopupMenuItem(
                  value: 'jobs',
                  child: Text(_t(isEn, 'Manage Jobs', 'إدارة الطلبات')),
                ),
                PopupMenuItem(
                  value: 'payouts',
                  child: Text(_t(isEn, 'Payouts', 'المدفوعات')),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Text(_t(isEn, 'Logout', 'تسجيل الخروج')),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _t(isEn, 'Coming soon: $value', 'قريباً: $value'),
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: const Icon(Icons.dashboard),
                text: _t(isEn, 'Overview', 'نظرة عامة'),
              ),
              Tab(
                icon: const Icon(Icons.people),
                text: _t(isEn, 'Users', 'المستخدمين'),
              ),
              Tab(
                icon: const Icon(Icons.work),
                text: _t(isEn, 'Jobs', 'الطلبات'),
              ),
              Tab(
                icon: _buildSupportTabIcon(),
                text: _t(isEn, 'Support', 'الدعم'),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: syanatBlue),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _overviewTab(isEn),
                  _usersTab(isEn),
                  _jobsTab(isEn),
                  _supportTab(isEn),
                ],
              ),
      ),
    );
  }

  Widget _overviewTab(bool isEn) {
    final cancellationPct = jobsRequested > 0
        ? (jobsCancelled / jobsRequested * 100).toStringAsFixed(1)
        : '0.0';

    return RefreshIndicator(
      onRefresh: _loadAllStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    isEn,
                    titleEn: 'Total Users',
                    titleAr: 'إجمالي المستخدمين',
                    value: totalUsers.toString(),
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _kpiCard(
                    isEn,
                    titleEn: 'Total Payouts',
                    titleAr: 'إجمالي المدفوعات',
                    value: '${totalRevenue.toStringAsFixed(0)} EGP',
                    icon: Icons.monetization_on,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    isEn,
                    titleEn: 'Jobs Requested',
                    titleAr: 'طلبات جديدة',
                    value: jobsRequested.toString(),
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _kpiCard(
                    isEn,
                    titleEn: 'Completed Jobs',
                    titleAr: 'طلبات مكتملة',
                    value: jobsFinished.toString(),
                    icon: Icons.check_circle,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    isEn,
                    titleEn: 'Cancelled Orders',
                    titleAr: 'طلبات ملغية',
                    value: jobsCancelled.toString(),
                    icon: Icons.cancel,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _kpiCard(
                    isEn,
                    titleEn: 'Cancellation %',
                    titleAr: 'نسبة الإلغاء',
                    value: '$cancellationPct%',
                    icon: Icons.percent,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _chartCard(
              _t(isEn, 'Revenue This Week', 'إيرادات هذا الأسبوع'),
              _t(isEn, 'Chart coming soon', 'الرسم البياني قريباً'),
              isEn: isEn,
            ),
            const SizedBox(height: 16),
            _activityCard(isEn),
          ],
        ),
      ),
    );
  }

  Widget _usersTab(bool isEn) {
    return RefreshIndicator(
      onRefresh: _loadAllStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User Breakdown ─────────────────────────────────────────────
            _usersBreakdownCard(isEn),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _statCard(
                      isEn,
                      titleEn: 'Customers',
                      titleAr: 'العملاء',
                      value: customers,
                      icon: Icons.person,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _statCard(
                      isEn,
                      titleEn: 'Technicians',
                      titleAr: 'الفنيين',
                      value: technicians,
                      icon: Icons.construction,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _t(isEn, 'Recent Users', 'المستخدمين الجدد'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // ── Real recent-users feed (latest 3 signups) ──────────────────
            _recentUsersSection(isEn),
          ],
        ),
      ),
    );
  }

  /// Bar-breakdown card. Reads from already-loaded state vars — 0 extra reads.
  Widget _usersBreakdownCard(bool isEn) {
    final breakdown = customers + technicians;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(isEn, 'User Breakdown', 'توزيع المستخدمين'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              isEn,
              'Total registered: $totalUsers accounts',
              'إجمالي المسجلين: $totalUsers حساب',
            ),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          _breakdownBar(
            label: _t(isEn, 'Customers', 'العملاء'),
            count: customers,
            total: breakdown,
            color: Colors.blue,
          ),
          const SizedBox(height: 14),
          _breakdownBar(
            label: _t(isEn, 'Technicians', 'الفنيين'),
            count: technicians,
            total: breakdown,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _breakdownBar({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Text(
              '$count  (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  /// Fetches the latest 3 signups — one-time read, refreshed via pull-to-refresh.
  Widget _recentUsersSection(bool isEn) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recentUsersFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _t(isEn, 'Could not load recent users.',
                  'تعذر تحميل المستخدمين الجدد.'),
              style: const TextStyle(color: Colors.black45),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: CircularProgressIndicator(color: syanatBlue)),
          );
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _t(isEn, 'No users yet.', 'لا يوجد مستخدمون بعد.'),
              style: const TextStyle(color: Colors.black45),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: List.generate(users.length, (i) {
              final u = users[i];
              final username = (u['username'] as String?)?.trim() ?? '';
              final email = (u['email'] as String?)?.trim() ?? '';
              final role = (u['role'] as String?) ?? '';
              final display = username.isNotEmpty ? username : email;
              final createdAt = u['createdAt'];
              String joined = '';
              if (createdAt is Timestamp) {
                final dt = createdAt.toDate();
                joined =
                    '${dt.day}/${dt.month}/${dt.year}';
              }
              final isTech = role == 'technician';
              return Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isTech
                          ? Colors.green.shade50
                          : syanatBlue.withOpacity(0.10),
                      child: Icon(
                        isTech ? Icons.construction : Icons.person,
                        color: isTech ? Colors.green : syanatBlue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      display.isNotEmpty
                          ? display
                          : _t(isEn, 'Unknown', 'غير معروف'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      isTech
                          ? _t(isEn, 'Technician', 'فني')
                          : _t(isEn, 'Customer', 'عميل'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      joined,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38),
                    ),
                  ),
                  if (i < users.length - 1)
                    const Divider(
                        height: 1, indent: 56, endIndent: 16),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _jobsTab(bool isEn) {
    return Column(
      children: [
        // Inner sub-tab bar
        Container(
          color: syanatBlue,
          child: TabBar(
            controller: _jobsTabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: _t(isEn, 'Requested', 'مطلوبة')),
              Tab(text: _t(isEn, 'Active', 'نشطة')),
              Tab(text: _t(isEn, 'Completed', 'مكتملة')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _jobsTabController,
            children: [
              _requestedJobsList(isEn),
              _activeJobsList(isEn),
              _completedJobsList(isEn),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Requested Jobs ────────────────────────────────────────────────────────

  Widget _requestedJobsList(bool isEn) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.streamJobsByStatus('requested'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _jobStreamErrorState(snapshot.error.toString(), isEn,
              onRetry: () => setState(() {}));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: syanatBlue));
        }
        final jobs = snapshot.data!;
        if (jobs.isEmpty) {
          return _emptyJobsState(isEn ? 'No requested jobs' : 'لا توجد طلبات جديدة');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _jobListTile(
            jobs[i],
            isEn,
            statusColor: Colors.orange,
            onTap: () => _openRequestedJobDetail(jobs[i], isEn),
          ),
        );
      },
    );
  }

  // ─── Active Jobs ───────────────────────────────────────────────────────────

  Widget _activeJobsList(bool isEn) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.streamActiveJobsAdmin(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _jobStreamErrorState(snapshot.error.toString(), isEn,
              onRetry: () => setState(() {}));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: syanatBlue));
        }
        final jobs = snapshot.data!;
        if (jobs.isEmpty) {
          return _emptyJobsState(isEn ? 'No active jobs' : 'لا توجد طلبات نشطة');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _jobListTile(
            jobs[i],
            isEn,
            statusColor: Colors.blue,
            onTap: () => _openActiveJobDetail(jobs[i], isEn),
          ),
        );
      },
    );
  }

  // ─── Completed Jobs ────────────────────────────────────────────────────────

  Widget _completedJobsList(bool isEn) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.streamJobsByStatus('completed'),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _jobStreamErrorState(snapshot.error.toString(), isEn,
              onRetry: () => setState(() {}));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: syanatBlue));
        }
        final jobs = snapshot.data!;
        if (jobs.isEmpty) {
          return _emptyJobsState(isEn ? 'No completed jobs' : 'لا توجد طلبات مكتملة');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _completedJobTile(jobs[i], isEn),
        );
      },
    );
  }

  // ─── Shared job card ───────────────────────────────────────────────────────

  Widget _jobListTile(
    Map<String, dynamic> job,
    bool isEn, {
    Color statusColor = Colors.orange,
    required VoidCallback onTap,
  }) {
    final serviceKey = job['serviceKey'] as String? ?? '';
    final serviceCategory = job['serviceCategory'] as String? ??
        job['serviceKey'] as String? ?? '';
    final customerName =
        job['customerName'] as String? ?? job['customerId'] as String? ?? '—';
    final description = job['description'] as String? ?? '';
    final urgency = job['urgencyType'] as String? ?? '';
    final status = job['status'] as String? ?? '';
    final locationAddress = job['locationAddress'] as String? ?? '';
    final locationLabel = job['locationLabel'] as String? ?? '';
    final createdAt = job['createdAt'];
    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    serviceCategory.isNotEmpty ? serviceCategory : serviceKey,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    urgency == 'urgent'
                        ? (isEn ? 'Urgent' : 'عاجل')
                        : (urgency == 'scheduled'
                            ? (isEn ? 'Scheduled' : 'مجدول')
                            : urgency),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(customerName,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54)),
                ),
              ],
            ),
            if (locationAddress.isNotEmpty || locationLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationLabel.isNotEmpty
                          ? '$locationLabel — $locationAddress'
                          : locationAddress,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black45),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(dateStr,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black38)),
            ],
            if (status == 'requested') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: syanatBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    isEn ? 'Assign Technician' : 'تعيين فني',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _completedJobTile(Map<String, dynamic> job, bool isEn) {
    final serviceCategory = job['serviceCategory'] as String? ??
        job['serviceKey'] as String? ?? '—';
    final customerName =
        job['customerName'] as String? ?? job['customerId'] as String? ?? '—';
    final techName = job['assignedTechnicianName'] as String? ?? '—';
    final amountPaid = (job['amountPaid'] as num?)?.toDouble();
    final adminClosedAt = job['adminClosedAt'];

    final customerApprovedAt = job['customerApprovedAt'];
    final closedTimestamp = adminClosedAt ?? customerApprovedAt;
    String closedStr = '';
    if (closedTimestamp is Timestamp) {
      final dt = closedTimestamp.toDate();
      closedStr =
          '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  serviceCategory,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isEn ? 'Completed' : 'مكتمل',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${isEn ? 'Customer' : 'العميل'}: $customerName',
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.construction, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${isEn ? 'Technician' : 'الفني'}: $techName',
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                amountPaid != null
                    ? '${isEn ? 'Paid' : 'المدفوع'}: ${amountPaid.toStringAsFixed(2)} EGP'
                    : (isEn ? 'Payment not set' : 'لم يُحدد المبلغ'),
                style: TextStyle(
                  fontSize: 13,
                  color: amountPaid != null ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (closedStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${isEn ? 'Completed' : 'اكتمل'}: $closedStr',
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyJobsState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.black45, fontSize: 16)),
        ],
      ),
    );
  }

  /// Shown whenever a job stream emits an error (permission denied, missing
  /// index, network failure, etc.).  Replaces the infinite loading spinner.
  Widget _jobStreamErrorState(String error, bool isEn,
      {required VoidCallback onRetry}) {
    // Extract a concise message from the Firestore error string.
    // Full Firestore errors can be very verbose; show only the first sentence.
    final brief = error.contains('\n') ? error.substring(0, error.indexOf('\n')) : error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              _t(isEn, 'Failed to load jobs', 'فشل تحميل الطلبات'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              brief,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(_t(isEn, 'Retry', 'إعادة المحاولة')),
              style: TextButton.styleFrom(foregroundColor: syanatBlue),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Requested job detail (assign technician) ──────────────────────────────

  void _openRequestedJobDetail(Map<String, dynamic> job, bool isEn) {
    final serviceKey = job['serviceKey'] as String? ?? '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) =>
          _RequestedJobSheet(job: job, serviceKey: serviceKey, isEn: isEn),
    );
  }

  // ─── Active job detail (close with payment) ────────────────────────────────

  void _openActiveJobDetail(Map<String, dynamic> job, bool isEn) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ActiveJobSheet(job: job, isEn: isEn),
    );
  }

  Widget _kpiCard(
    bool isEn, {
    required String titleEn,
    required String titleAr,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: syanatBlue,
            ),
          ),
          Text(
            _t(isEn, titleEn, titleAr),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    bool isEn, {
    required String titleEn,
    required String titleAr,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(isEn, titleEn, titleAr),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: syanatBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(String title, String subtitle, {required bool isEn}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_up, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    _t(isEn, 'Chart coming soon', 'الرسم البياني قريباً'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportTabIcon() {
    if (_unreadSupportCount == 0) {
      return const Icon(Icons.support_agent);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.support_agent),
        Positioned(
          top: -4,
          right: -6,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              _unreadSupportCount > 99
                  ? '99+'
                  : _unreadSupportCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _supportTab(bool isEn) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.streamSupportChats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: syanatBlue),
          );
        }
        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent, size: 64, color: Colors.black26),
                const SizedBox(height: 16),
                Text(
                  _t(isEn, 'No support requests yet.', 'لا توجد طلبات دعم حتى الآن.'),
                  style: const TextStyle(color: Colors.black45, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: chats.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final chatId = chat['id'] as String;
            final userName = chat['userName'] as String? ?? 'User';
            final status = chat['status'] as String? ?? 'open';
            final unread = chat['unreadByAdmin'] as bool? ?? false;
            final closed = status == 'closed';

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: closed
                        ? Colors.grey.shade300
                        : syanatBlue.withOpacity(0.12),
                    child: Icon(
                      Icons.person,
                      color: closed ? Colors.grey : syanatBlue,
                    ),
                  ),
                  if (unread && !closed)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
              title: Text(
                userName,
                style: TextStyle(
                  fontWeight:
                      unread && !closed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                closed
                    ? _t(isEn, 'Closed', 'مغلق')
                    : _t(isEn, 'Open · Tap to reply', 'مفتوح · اضغط للرد'),
                style: TextStyle(
                  fontSize: 12,
                  color: closed ? Colors.grey : Colors.green.shade700,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminSupportChatScreen(
                      chatId: chatId,
                      userName: userName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _activityCard(bool isEn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(isEn, 'Recent Activity', 'آخر النشاطات'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _recentActivityFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _t(isEn, 'Could not load activity', 'تعذر تحميل النشاطات'),
                    style: const TextStyle(color: Colors.black45),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: CircularProgressIndicator(color: syanatBlue)),
                );
              }
              final events = snapshot.data!;
              if (events.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      _t(isEn, 'No activity yet.', 'لا توجد نشاطات بعد.'),
                      style: const TextStyle(color: Colors.black45),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                itemBuilder: (context, i) {
                  final ev = events[i];
                  final type = ev['type'] as String? ?? '';
                  final desc = ev['description'] as String? ?? '';
                  final role = ev['role'] as String? ?? '';
                  final ts = ev['createdAt'];
                  final timeStr = _relativeTime(ts, isEn);

                  IconData icon;
                  Color color;
                  String titleEn;
                  String titleAr;

                  switch (type) {
                    case 'account_created':
                      icon = Icons.person_add;
                      color = syanatBlue;
                      if (role == 'technician') {
                        titleEn = 'New technician joined';
                        titleAr = 'فني جديد انضم';
                      } else {
                        titleEn = 'New customer joined';
                        titleAr = 'عميل جديد انضم';
                      }
                      break;
                    case 'job_requested':
                      icon = Icons.pending_actions;
                      color = Colors.orange;
                      titleEn = 'Job requested';
                      titleAr = 'طلب جديد';
                      break;
                    case 'job_completed':
                      icon = Icons.check_circle;
                      color = Colors.green;
                      titleEn = 'Job completed';
                      titleAr = 'طلب مكتمل';
                      break;
                    case 'job_cancelled':
                      icon = Icons.cancel;
                      color = Colors.red;
                      titleEn = 'Job cancelled';
                      titleAr = 'طلب ملغي';
                      break;
                    default:
                      icon = Icons.info_outline;
                      color = Colors.grey;
                      titleEn = type;
                      titleAr = type;
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      _t(isEn, titleEn, titleAr),
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: desc.isNotEmpty
                        ? Text(
                            desc,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45),
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Text(
                      timeStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Returns a human-readable relative time string for a Firestore Timestamp.
  String _relativeTime(dynamic ts, bool isEn) {
    if (ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return isEn ? 'just now' : 'الآن';
    if (diff.inMinutes < 60) {
      return isEn ? '${diff.inMinutes}m ago' : 'من ${diff.inMinutes} د';
    }
    if (diff.inHours < 24) {
      return isEn ? '${diff.inHours}h ago' : 'من ${diff.inHours} س';
    }
    return isEn ? '${diff.inDays}d ago' : 'من ${diff.inDays} ي';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _RequestedJobSheet — Admin views a requested job and assigns a technician
// ═════════════════════════════════════════════════════════════════════════════

class _RequestedJobSheet extends StatefulWidget {
  final Map<String, dynamic> job;
  final String serviceKey;
  final bool isEn;

  const _RequestedJobSheet({
    required this.job,
    required this.serviceKey,
    required this.isEn,
  });

  @override
  State<_RequestedJobSheet> createState() => _RequestedJobSheetState();
}

class _RequestedJobSheetState extends State<_RequestedJobSheet> {
  List<Map<String, dynamic>> _techs = [];
  bool _loadingTechs = true;
  String? _assigningTechId;

  @override
  void initState() {
    super.initState();
    _loadTechs();
  }

  Future<void> _loadTechs() async {
    try {
      final results = await Future.wait([
        FirebaseService.firestore
            .collection('users')
            .where('role', isEqualTo: 'technician')
            .where('available', isEqualTo: true)
            .limit(50)
            .get(),
        FirebaseService.firestore
            .collection('jobs')
            .where('status', whereIn: [
              'active',
              'technician_accepted',
              'technician_arrived',
              'work_finished',
              'awaiting_customer_approval',
              'receipt_disputed',
              'accepted',
              'en_route',
              'payment_pending',
            ])
            .limit(50)
            .get(),
      ]);
      final techSnap = results[0];
      final activeSnap = results[1];
      final busyTechIds = activeSnap.docs
          .map((doc) => doc.data()['assignedTechnicianId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final techs = techSnap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((tech) => !busyTechIds.contains(tech['id'] as String? ?? ''))
          .toList();
      if (mounted) {
        setState(() {
          _techs = techs;
          _loadingTechs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTechs = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEn
                  ? 'Failed to load technicians. Please try again.'
                  : 'فشل تحميل قائمة الفنيين. حاول مرة أخرى.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _assign(String techId, String techName) async {
    setState(() => _assigningTechId = techId);
    try {
      final jobId = widget.job['id'] as String? ?? '';
      if (jobId.isEmpty) throw Exception('Invalid job ID');
      await FirebaseService.assignJob(
        jobId: jobId,
        technicianId: techId,
        technicianName: techName,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isEn
              ? 'Technician assigned successfully'
              : 'تم تعيين الفني بنجاح'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _assigningTechId = null);
        debugPrint('Assign technician error: $e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Assignment failed. Please try again.')));
      }
    } finally {
      if (mounted && _assigningTechId != null) {
        setState(() => _assigningTechId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final isEn = widget.isEn;
    final serviceCategory = job['serviceCategory'] as String? ??
        job['serviceKey'] as String? ?? '—';
    final customerName =
        job['customerName'] as String? ?? job['customerId'] as String? ?? '—';
    final description = job['description'] as String? ?? '';
    final locationLabel = job['locationLabel'] as String? ?? '';
    final locationAddress = job['locationAddress'] as String? ?? '';
    final urgencyType = job['urgencyType'] as String? ?? '';
    final scheduledTime = job['scheduledTime'];
    final createdAt = job['createdAt'];

    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr =
          '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    String scheduledStr = '';
    if (scheduledTime is Timestamp) {
      final dt = scheduledTime.toDate();
      scheduledStr =
          '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isEn ? 'Job Request Details' : 'تفاصيل الطلب',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.build, isEn ? 'Service' : 'الخدمة', serviceCategory),
            _infoRow(Icons.person, isEn ? 'Customer' : 'العميل', customerName),
            if (locationLabel.isNotEmpty || locationAddress.isNotEmpty)
              _infoRow(
                  Icons.location_on,
                  isEn ? 'Location' : 'الموقع',
                  locationLabel.isNotEmpty
                      ? '$locationLabel — $locationAddress'
                      : locationAddress),
            if (description.isNotEmpty)
              _infoRow(Icons.description,
                  isEn ? 'Description' : 'الوصف', description),
            _infoRow(
                Icons.flash_on,
                isEn ? 'Urgency' : 'الأولوية',
                urgencyType == 'urgent'
                    ? (isEn ? 'Urgent / Now' : 'عاجل / الآن')
                    : (isEn ? 'Scheduled' : 'مجدول')),
            if (scheduledStr.isNotEmpty)
              _infoRow(Icons.schedule,
                  isEn ? 'Scheduled For' : 'موعد', scheduledStr),
            if (dateStr.isNotEmpty)
              _infoRow(Icons.access_time,
                  isEn ? 'Requested At' : 'وقت الطلب', dateStr),
            const Divider(height: 32),
            Text(
              isEn
                  ? 'Available Technicians (Same Service)'
                  : 'الفنيون المتاحون (نفس الخدمة)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loadingTechs)
              const Center(
                  child: CircularProgressIndicator(color: syanatBlue))
            else if (_techs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'No available technicians for this service right now.'
                            : 'لا يوجد فنيون متاحون لهذه الخدمة حالياً.',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_techs.map((tech) {
                final techId = tech['id'] as String? ?? '';
                final techName = tech['username'] as String? ??
                    tech['email'] as String? ?? 'Technician';
                final rating = (tech['rating'] as num?)?.toDouble() ?? 0.0;
                final isAssigning = _assigningTechId == techId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: syanatBlue.withOpacity(0.12),
                        child: const Icon(Icons.construction,
                            color: syanatBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(techName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (rating > 0)
                              Text('★ ${rating.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.amber)),
                          ],
                        ),
                      ),
                      isAssigning
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: syanatBlue))
                          : ElevatedButton(
                              onPressed: _assigningTechId != null
                                  ? null
                                  : () => _assign(techId, techName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: syanatBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(isEn ? 'Assign' : 'تعيين'),
                            ),
                    ],
                  ),
                );
              }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: syanatBlue),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ActiveJobSheet — Admin views an active job (read-only monitoring)
// ═════════════════════════════════════════════════════════════════════════════

class _ActiveJobSheet extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool isEn;

  const _ActiveJobSheet({required this.job, required this.isEn});

  @override
  State<_ActiveJobSheet> createState() => _ActiveJobSheetState();
}

class _ActiveJobSheetState extends State<_ActiveJobSheet> {
  bool _resolving = false;

  static const _statusLabelsEn = {
    'active': 'Active — Awaiting Tech Acceptance',
    'technician_accepted': 'Tech Accepted',
    'on_the_way': 'On the Way',
    'technician_arrived': 'Tech Arrived',
    'work_finished': 'Work Finished — Awaiting Receipt',
    'awaiting_customer_approval': 'Awaiting Customer Approval',
    'awaiting_payment': 'Awaiting Payment',
    'awaiting_payment_verification': 'Payment Verification',
    'receipt_disputed': 'Receipt Disputed — Needs Resolution',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'accepted': 'Active',
    'en_route': 'En Route',
    'payment_pending': 'Payment Pending',
  };

  static const _statusLabelsAr = {
    'active': 'نشط — في انتظار قبول الفني',
    'technician_accepted': 'قبل الفني',
    'on_the_way': 'في الطريق',
    'technician_arrived': 'الفني وصل',
    'work_finished': 'اكتمل العمل — في انتظار الإيصال',
    'awaiting_customer_approval': 'في انتظار موافقة العميل',
    'awaiting_payment': 'بانتظار الدفع',
    'awaiting_payment_verification': 'التحقق من الدفع',
    'receipt_disputed': 'إيصال متنازع عليه — يحتاج حل',
    'completed': 'مكتمل',
    'cancelled': 'ملغي',
    'accepted': 'نشط',
    'en_route': 'في الطريق',
    'payment_pending': 'بانتظار الدفع',
  };

  Future<void> _resolveDispute(String resolution) async {
    setState(() => _resolving = true);
    try {
      await FirebaseService.adminResolveDispute(
        jobId: widget.job['id'] as String? ?? '',
        resolution: resolution,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isEn
            ? 'Dispute resolved: $resolution'
            : 'تم حل النزاع: $resolution'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      debugPrint('Resolve dispute error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to resolve dispute. Please try again.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final isEn = widget.isEn;
    final serviceCategory =
        job['serviceCategory'] as String? ?? job['serviceKey'] as String? ?? '—';
    final customerName =
        job['customerName'] as String? ?? job['customerId'] as String? ?? '—';
    final techName = job['assignedTechnicianName'] as String? ?? '—';
    final description = job['description'] as String? ?? '';
    final phoneNumber = job['phoneNumber'] as String? ?? '';
    final locationLabel = job['locationLabel'] as String? ?? '';
    final locationAddress = job['locationAddress'] as String? ?? '';
    final status = job['status'] as String? ?? '';
    final createdAt = job['createdAt'];
    final receipt = job['receipt'] as Map<String, dynamic>?;
    final paymentProofUrl =
        (job['paymentProofUrl'] as String?)?.trim() ?? '';

    final statusLabel = (isEn ? _statusLabelsEn : _statusLabelsAr)[status] ?? status;

    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr =
          '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              isEn ? 'Active Job Details' : 'تفاصيل الطلب النشط',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.build, isEn ? 'Service' : 'الخدمة', serviceCategory),
            _infoRow(Icons.person, isEn ? 'Customer' : 'العميل', customerName),
            _infoRow(
                Icons.construction, isEn ? 'Technician' : 'الفني', techName),
            if (phoneNumber.isNotEmpty)
              _infoRow(Icons.phone, isEn ? 'Phone' : 'الهاتف', phoneNumber),
            if (locationLabel.isNotEmpty || locationAddress.isNotEmpty)
              _infoRow(
                  Icons.location_on,
                  isEn ? 'Location' : 'الموقع',
                  locationLabel.isNotEmpty
                      ? '$locationLabel — $locationAddress'
                      : locationAddress),
            if (description.isNotEmpty)
              _infoRow(Icons.description,
                  isEn ? 'Description' : 'الوصف', description),
            _infoRow(Icons.info_outline, isEn ? 'Status' : 'الحالة',
                statusLabel),
            if (dateStr.isNotEmpty)
              _infoRow(Icons.access_time,
                  isEn ? 'Created' : 'وقت الإنشاء', dateStr),
            if (receipt != null) ...[
              const Divider(height: 32),
              Text(
                isEn ? 'Submitted Receipt' : 'الإيصال المقدَّم',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _receiptPreview(receipt, isEn),
            ],
            if (paymentProofUrl.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                isEn ? 'Payment Proof' : 'إثبات الدفع',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _paymentProofView(paymentProofUrl, isEn),
            ],
            // ── Dispute resolution actions ────────────────────────────
            if (status == 'receipt_disputed') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gavel, color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Dispute Resolution' : 'حل النزاع',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEn
                          ? 'The customer has rejected the receipt. Review the details above and choose an action.'
                          : 'رفض العميل الإيصال. راجع التفاصيل أعلاه واختر إجراءً.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    // Reopen for customer approval
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _resolving ? null : () => _resolveDispute('reopen'),
                        icon: const Icon(Icons.replay, size: 18),
                        label: Text(
                          isEn ? 'Send Back for Approval' : 'إعادة للعميل للموافقة',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3C21C8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Complete manually
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: _resolving
                                  ? null
                                  : () => _resolveDispute('complete'),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: Text(
                                isEn ? 'Close as Done' : 'إغلاق كمكتمل',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF10B981),
                                side: const BorderSide(color: Color(0xFF10B981)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Cancel
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: _resolving
                                  ? null
                                  : () => _resolveDispute('cancel'),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: Text(
                                isEn ? 'Cancel Job' : 'إلغاء الطلب',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3C21C8).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: Color(0xFF3C21C8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Order completion is now handled by the technician and customer. No manual closure required.'
                          : 'إتمام الطلب الآن يتم من قِبل الفني والعميل. لا يلزم إغلاق يدوي.',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF3C21C8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptPreview(Map<String, dynamic> receipt, bool isEn) {
    final services =
        (receipt['services'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final parts =
        (receipt['parts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final grandTotal =
        (receipt['grandTotal'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (services.isNotEmpty) ...[
          Text(isEn ? 'Services' : 'الخدمات',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          ...services.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(s['title'] as String? ?? '',
                            style: const TextStyle(fontSize: 14))),
                    Text(
                        '${(s['price'] as num?)?.toStringAsFixed(0) ?? '0'} EGP',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
        if (parts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(isEn ? 'Parts' : 'قطع الغيار',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          ...parts.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(p['name'] as String? ?? '',
                            style: const TextStyle(fontSize: 14))),
                    Text(
                        '${(p['price'] as num?)?.toStringAsFixed(0) ?? '0'} EGP',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isEn ? 'Grand Total' : 'الإجمالي',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${grandTotal.toStringAsFixed(0)} EGP',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF3C21C8))),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: syanatBlue),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the technician-uploaded payment proof photo as a thumbnail.
  /// Tapping opens a fullscreen InteractiveViewer so the admin can pan/zoom
  /// the image when mediating a dispute. The admin read of
  /// `payment_proofs/{fileName}` is covered by the existing storage.rules
  /// match block (authenticated-read), no rules change needed.
  Widget _paymentProofView(String url, bool isEn) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _openFullscreenProof(context, url, isEn),
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF3C21C8), strokeWidth: 2),
                        ),
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image,
                            color: Colors.black38, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          isEn
                              ? 'Could not load proof image'
                              : 'تعذر تحميل صورة الإثبات',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          isEn ? 'Tap to zoom' : 'اضغط للتكبير',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
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

  void _openFullscreenProof(BuildContext context, String url, bool isEn) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(isEn ? 'Payment Proof' : 'إثبات الدفع'),
          leading: IconButton(
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(Icons.close),
            tooltip: isEn ? 'Close' : 'إغلاق',
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
