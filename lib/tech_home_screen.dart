import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_service.dart';
import 'chat_screen.dart';
import 'glass_card.dart';
import 'technician_inventory_screen.dart';
import 'settings_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class TechHomeScreen extends StatefulWidget {
  final Function(Locale) setLocale;
  const TechHomeScreen({required this.setLocale, super.key});

  @override
  State<TechHomeScreen> createState() => _TechHomeScreenState();
}

class _TechHomeScreenState extends State<TechHomeScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _jobs = [];
  int _activeCount = 0;
  double _earnings = 0.0;
  double _rating = 0.0;

  final Map<String, Map<String, dynamic>> _customerCache = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _jobsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  @override
  void initState() {
    super.initState();
    _subscribeProfile();
    _loadJobsRealtime();
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  void _subscribeProfile() {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    _profileSub = FirebaseService.firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      final rating = (doc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
      if (!mounted) return;
      setState(() => _rating = rating);
    });
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
        .snapshots()
        .listen((snapshot) async {
      final jobs = snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] = d.id;
        return data;
      }).toList();

      final active = jobs
          .where(
            (j) =>
                j['status'] == 'accepted' ||
                j['status'] == 'in_progress' ||
                j['status'] == 'inprogress',
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
    // Defer past the current frame so the tap animation completes
    // before the full-app rebuild triggered by setLocale.
    Future.microtask(() => widget.setLocale(newLocale));
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
    try {
      await FirebaseService.firestore.collection('jobs').doc(jobId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting: $e')),
      );
    }
  }

  Future<void> _completeJob(String jobId) async {
    final priceController = TextEditingController();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Complete Job' : 'Complete Job'),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: isEn ? 'Final price' : 'Final price',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEn ? 'Cancel' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: syanatBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(isEn ? 'Complete' : 'Complete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final price = double.tryParse(priceController.text.trim()) ?? 0.0;

    try {
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        await FirebaseService.firestore
            .collection('jobs')
            .doc(jobId)
            .update({
          'status': 'completed',
          'price': price,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // addEarnings atomically increments both
        // users/{uid}.earnings and stats/global.totalEarnings.
        await FirebaseService.addEarnings(user.uid, price);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

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
                        child: Text(
                          isEn ? 'Welcome Technician' : 'Welcome Technician',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SettingsScreen(
                                    setLocale: widget.setLocale),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings, color: Colors.white),
                            tooltip: isEn ? 'Settings' : 'Settings',
                          ),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TechnicianInventoryScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.inventory, color: Colors.white),
                            tooltip:
                                isEn ? 'Manage Inventory' : 'Manage Inventory',
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
                                                              ? 'Complete'
                                                              : 'Complete',
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