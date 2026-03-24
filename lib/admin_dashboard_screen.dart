import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../firebase_service.dart';
import '../login_screen.dart';
import '../admin_support_chat_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int totalUsers = 0;
  int customers = 0;
  int technicians = 0;

  double totalRevenue = 0.0;

  int jobsRequested = 0;
  int jobsOngoing = 0;
  int jobsFinished = 0;

  int activeChats = 0;

  Set<Marker> markers = {};
  DateTime? _selectedDate;
  bool _loading = true;

  int _unreadSupportCount = 0;
  StreamSubscription<int>? _supportCountSub;

  /// True while a stats fetch is already in-flight; prevents overlapping calls.
  bool _fetching = false;

  /// True once technician map markers have been loaded at least once.
  bool _markersLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Lazy-load map markers only when the Map tab is first opened.
    _tabController.addListener(_onTabChanged);
    _loadAllStats();
    _supportCountSub = FirebaseService.streamUnreadSupportCount().listen(
      (n) {
        if (mounted) setState(() => _unreadSupportCount = n);
      },
    );
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 3 && !_markersLoaded) {
      _loadTechnicianLocations();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _supportCountSub?.cancel();
    super.dispose();
  }

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  Future<void> _loadAllStats() async {
    // In-flight guard: drop concurrent calls caused by multiple RefreshIndicators
    // or rapid refresh taps while a fetch is already running.
    if (_fetching) return;
    _fetching = true;
    if (mounted) setState(() => _loading = true);

    try {
      final firestore = FirebaseService.firestore;

      // ── Fast path: single document read ──────────────────────────────────
      // When a Cloud Function (or admin write) keeps stats/global up-to-date,
      // the entire dashboard costs exactly 1 Firestore read.
      final statsSnap = await firestore.doc('stats/global').get();
      final statsData = statsSnap.data() ?? {};

      final totalEarnings =
          (statsData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
      final revenue = totalEarnings * 0.15;

      final int? aggUsers       = (statsData['totalUsers']    as num?)?.toInt();
      final int? aggCustomers   = (statsData['customers']     as num?)?.toInt();
      final int? aggTechnicians = (statsData['technicians']   as num?)?.toInt();
      final int? aggRequested   = (statsData['jobsRequested'] as num?)?.toInt();
      final int? aggOngoing     = (statsData['jobsOngoing']   as num?)?.toInt();
      final int? aggCompleted   = (statsData['jobsCompleted'] as num?)?.toInt();
      final int? aggChats       = (statsData['activeChats']   as num?)?.toInt();

      int usersCount, custCount, techCount, reqCount, ongCount, finCount, chatCount;

      if (aggUsers != null &&
          aggCustomers != null &&
          aggTechnicians != null &&
          aggRequested != null &&
          aggOngoing != null &&
          aggCompleted != null &&
          aggChats != null) {
        // All counters present in the aggregate doc — no extra reads needed.
        usersCount = aggUsers;
        custCount  = aggCustomers;
        techCount  = aggTechnicians;
        reqCount   = aggRequested;
        ongCount   = aggOngoing;
        finCount   = aggCompleted;
        chatCount  = aggChats;
      } else {
        // ── Slow path: aggregate doc incomplete, fall back to count() queries ──
        final results = await Future.wait([
          firestore.collection('users').count().get(),
          firestore.collection('users').where('role', isEqualTo: 'customer').count().get(),
          firestore.collection('users').where('role', isEqualTo: 'technician').count().get(),
          firestore.collection('jobs').where('status', isEqualTo: 'requested').count().get(),
          firestore.collection('jobs').where('status', isEqualTo: 'accepted').count().get(),
          firestore.collection('jobs').where('status', isEqualTo: 'in_progress').count().get(),
          firestore.collection('jobs').where('status', isEqualTo: 'inprogress').count().get(),
          firestore.collection('jobs').where('status', isEqualTo: 'completed').count().get(),
          firestore.collectionGroup('messages').count().get(),
        ]);

        usersCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
        custCount  = (results[1] as AggregateQuerySnapshot).count ?? 0;
        techCount  = (results[2] as AggregateQuerySnapshot).count ?? 0;
        final accepted   = (results[4] as AggregateQuerySnapshot).count ?? 0;
        final inProg     = (results[5] as AggregateQuerySnapshot).count ?? 0;
        final inProgLeg  = (results[6] as AggregateQuerySnapshot).count ?? 0;
        reqCount   = (results[3] as AggregateQuerySnapshot).count ?? 0;
        ongCount   = accepted + inProg + inProgLeg;
        finCount   = (results[7] as AggregateQuerySnapshot).count ?? 0;
        chatCount  = (results[8] as AggregateQuerySnapshot).count ?? 0;
      }

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
        _loading      = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(isEn, 'Error loading stats: $e', 'حصل خطأ في تحميل الإحصائيات: $e'),
          ),
        ),
      );
    } finally {
      _fetching = false;
    }
  }

  Future<void> _loadTechnicianLocations() async {
    final bool isEn =
        mounted ? Localizations.localeOf(context).languageCode == 'en' : true;

    final snap = await FirebaseService.firestore
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .where('available', isEqualTo: true)
        .get();

    final Set<Marker> temp = {};
    for (final d in snap.docs) {
      final data = d.data();
      if (data.containsKey('location') && data['location'] is GeoPoint) {
        final GeoPoint gp = data['location'] as GeoPoint;
        final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;

        temp.add(
          Marker(
            markerId: MarkerId(d.id),
            position: LatLng(gp.latitude, gp.longitude),
            infoWindow: InfoWindow(
              title: (data['username']?.toString().trim().isNotEmpty ?? false)
                  ? data['username'].toString()
                  : _t(isEn, 'Technician', 'فني'),
              snippet:
                  '${_t(isEn, 'Rating', 'التقييم')}: ${rating.toStringAsFixed(1)}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              rating >= 4.5
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueOrange,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        markers = temp;
        _markersLoaded = true;
      });
    }
  }

  Future<void> _refreshStats() async {
    // Allow map markers to reload on the next explicit refresh.
    _markersLoaded = false;
    await _loadAllStats();
    // Reload map data immediately if the map tab is currently visible.
    if (mounted && _tabController.index == 3) {
      await _loadTechnicianLocations();
    }
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

    // Navigate all the way back to root so MyApp rebuilds SplashScreen
    // with the real setLocale — avoids needing to thread setLocale into
    // AdminDashboardScreen (which is pushed without it from LoginScreen).
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(setLocale: (locale) {}),
      ),
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
                icon: const Icon(Icons.map),
                text: _t(isEn, 'Map', 'الخريطة'),
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
                  _mapTab(isEn),
                  _supportTab(isEn),
                ],
              ),
      ),
    );
  }

  Widget _overviewTab(bool isEn) {
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
                    titleEn: 'Revenue',
                    titleAr: 'الإيرادات',
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
                    titleEn: 'Active Jobs',
                    titleAr: 'طلبات شغالة',
                    value: jobsOngoing.toString(),
                    icon: Icons.hourglass_empty,
                    color: Colors.amber,
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
                    titleEn: 'Completed Jobs',
                    titleAr: 'طلبات مكتملة',
                    value: jobsFinished.toString(),
                    icon: Icons.check_circle,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _kpiCard(
                    isEn,
                    titleEn: 'Active Chats',
                    titleAr: 'الشاتات النشطة',
                    value: activeChats.toString(),
                    icon: Icons.chat_bubble,
                    color: Colors.deepPurple,
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
            _chartCard(
              _t(isEn, 'Users Growth', 'نمو المستخدمين'),
              _t(isEn, 'Growth chart coming soon', 'رسم النمو قريباً'),
              isEn: isEn,
            ),
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
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(_t(isEn, 'ahmed@example.com', 'ahmed@example.com')),
              subtitle: Text(
                _t(isEn, 'Customer - Joined today', 'عميل - انضم النهاردة'),
              ),
              trailing: const Icon(Icons.edit),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _jobsTab(bool isEn) {
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
                  child: _statCard(
                    isEn,
                    titleEn: 'Requested',
                    titleAr: 'مطلوب',
                    value: jobsRequested,
                    icon: Icons.pending,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    isEn,
                    titleEn: 'Ongoing',
                    titleAr: 'شغال',
                    value: jobsOngoing,
                    icon: Icons.schedule,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    isEn,
                    titleEn: 'Completed',
                    titleAr: 'مكتمل',
                    value: jobsFinished,
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _chartCard(
              _t(isEn, 'Jobs by Status', 'الطلبات حسب الحالة'),
              _t(isEn, 'Pie chart coming soon', 'مخطط دائري قريباً'),
              isEn: isEn,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: isEn ? Alignment.centerLeft : Alignment.centerRight,
              child: Text(
                _t(isEn, 'Recent Jobs', 'آخر الطلبات'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.work, color: syanatBlue),
              title: Text(_t(isEn, 'Plumbing - Ahmed St.', 'سباكة - شارع أحمد')),
              subtitle: Text(_t(isEn, 'Requested 2h ago', 'اتطلب من ساعتين')),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapTab(bool isEn) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(30.0444, 31.2357),
        zoom: 11,
      ),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t(isEn, 'Recent Activity', 'آخر النشاطات'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.history),
                label: Text(_t(isEn, 'View all', 'عرض الكل')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: syanatBlue,
              child: Icon(Icons.person_add, color: Colors.white),
            ),
            title: Text(_t(isEn, 'New customer joined', 'عميل جديد انضم')),
            subtitle: Text(_t(isEn, 'ahmed@example.com', 'ahmed@example.com')),
            trailing: Text(_t(isEn, '2 min ago', 'من دقيقتين')),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.check_circle, color: Colors.white),
            ),
            title: Text(_t(isEn, 'Job completed', 'طلب اتقفل')),
            subtitle: Text(_t(isEn, 'Plumbing - 150 EGP', 'سباكة - 150 جنيه')),
            trailing: Text(_t(isEn, '5 min ago', 'من 5 دقايق')),
          ),
        ],
      ),
    );
  }
}