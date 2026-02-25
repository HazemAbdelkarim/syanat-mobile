// tech_home_screen.dart - COMPLETE FIXED VERSION (NO OVERFLOW)

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
  StreamSubscription? _jobsSub;

  @override
  void initState() {
    super.initState();
    _loadJobsRealtime();
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    super.dispose();
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
      final jobs =
          snapshot.docs.map((d) => d.data()..['id'] = d.id).toList();

      final active = jobs
          .where((j) =>
              j['status'] == 'accepted' || j['status'] == 'in_progress')
          .length;
      final earnings = jobs
          .where((j) => j['status'] == 'completed')
          .fold<double>(
              0.0, (sum, j) => sum + (j['price'] as num? ?? 0).toDouble());

      final profile =
          await FirebaseService.getProfile(user.uid);
      final rating = (profile?['rating'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _jobs = jobs;
        _activeCount = active;
        _earnings = earnings;
        _rating = rating;
        _loading = false;
      });
    });
  }

  void _switchLanguage() {
    final newLocale =
        Localizations.localeOf(context).languageCode == 'en'
            ? const Locale('ar')
            : const Locale('en');
    widget.setLocale(newLocale);
  }

  Future<void> _acceptJob(String jobId) async {
    try {
      await FirebaseService.firestore
          .collection('jobs')
          .doc(jobId)
          .update({'status': 'accepted'});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting: $e')),
      );
    }
  }

  Future<void> _rejectJob(String jobId) async {
    try {
      await FirebaseService.firestore
          .collection('jobs')
          .doc(jobId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request rejected')),
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
        title: Text(isEn ? 'Complete Job' : 'إنهاء المهمة'),
        content: TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: isEn ? 'Final price' : 'السعر النهائي',
          ),
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
            child: Text(isEn ? 'Complete' : 'إنهاء'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final price = double.tryParse(priceController.text.trim()) ?? 0.0;

    try {
      await FirebaseService.firestore
          .collection('jobs')
          .doc(jobId)
          .update({'status': 'completed', 'price': price});
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
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
                // Blue header with settings
                Container(
                  color: syanatBlue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEn ? 'Welcome Technician' : 'مرحباً أيها الفني',
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
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings,
                                color: Colors.white),
                            tooltip:
                                isEn ? 'Settings' : 'الإعدادات',
                          ),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TechnicianInventoryScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.inventory,
                                color: Colors.white),
                            tooltip: isEn
                                ? 'Manage Inventory'
                                : 'إدارة المخزون',
                          ),
                          IconButton(
                            onPressed: _switchLanguage,
                            icon: const Icon(Icons.language,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // White content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Stats
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                isEn ? 'Active Jobs' : 'الطلبات النشطة',
                                '$_activeCount',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                isEn ? 'Earnings Today' : 'أرباح اليوم',
                                '${_earnings.toStringAsFixed(2)} EGP',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                isEn ? 'Rating' : 'التقييم',
                                _rating > 0
                                    ? '⭐ ${_rating.toStringAsFixed(2)}'
                                    : '—',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          isEn ? 'Active Jobs' : 'الطلبات الحالية',
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
                                        isEn
                                            ? 'No jobs yet'
                                            : 'لا يوجد مهام',
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
                                            j['status'] as String? ??
                                                'requested';
                                        final customerId =
                                            j['customerId'] as String? ??
                                                '';

                                        return FutureBuilder<
                                            Map<String, dynamic>?>(
                                          future:
                                              FirebaseService.getProfile(
                                                  customerId),
                                          builder:
                                              (context, snapshot) {
                                            final customer =
                                                snapshot.data ?? {};
                                            final username =
                                                customer['username'] ??
                                                    customer['email'] ??
                                                    'Customer';
                                            final description =
                                                j['description'] ??
                                                    '';
                                            final price =
                                                j['price'] ?? 0;

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                      bottom: 10),
                                              child: GlassCard(
                                                padding: const EdgeInsets
                                                    .fromLTRB(12, 8, 4, 8),
                                                child: ListTile(
                                                  dense: true,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                              horizontal: 12,
                                                              vertical: 0),
                                                  minVerticalPadding: 0,
                                                  leading: CircleAvatar(
                                                    backgroundColor:
                                                        Colors.grey
                                                            .shade300,
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors
                                                          .black54,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    username,
                                                    style:
                                                        const TextStyle(
                                                      color:
                                                          Colors.black,
                                                    ),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (description
                                                          .toString()
                                                          .isNotEmpty)
                                                        Text(
                                                          description,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors
                                                                .black54,
                                                          ),
                                                        ),
                                                      const SizedBox(
                                                          height: 6),
                                                      Text(
                                                        isEn
                                                            ? 'Status: $status'
                                                            : 'الحالة: $status',
                                                        style:
                                                            const TextStyle(
                                                          color: Colors
                                                              .black54,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 4),
                                                      Text(
                                                        isEn
                                                            ? 'Price: $price EGP'
                                                            : 'السعر: $price ج.م',
                                                        style:
                                                            const TextStyle(
                                                          color: Colors
                                                              .black54,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

// FINAL PERFECT VERSION - Normal Chat button + Compact tick/X

trailing: Row(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    // NORMAL Chat button (back to original 72x32 size)
    SizedBox(
      width: 72,
      child: ElevatedButton(
        onPressed: () async {
          final chatId = await FirebaseService.getOrCreateChat(
            customerId,
            FirebaseService.getCurrentUser()!.uid,
            jobId: j['id'] as String,
          );
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chatId, isTechnician: true),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: syanatBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          textStyle: const TextStyle(fontSize: 13),
          minimumSize: const Size(72, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(isEn ? 'Chat' : 'دردشة'),
      ),
    ),
    const SizedBox(width: 6),

    // Compact tick/X buttons (24x24) - SAME ROW
    if (status == 'requested') ...[
      // Accept ✅
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: syanatBlue,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.check, color: Colors.white, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _acceptJob(j['id'] as String),
        ),
      ),
      const SizedBox(width: 4),
      // Reject ❌
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: syanatBlue.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _rejectJob(j['id'] as String),
        ),
      ),
    ] else if (status == 'accepted' || status == 'in_progress')
      // Complete button - SAME ROW, normal size
      SizedBox(
        width: 72,
        child: ElevatedButton(
          onPressed: () => _completeJob(j['id'] as String),
          style: ElevatedButton.styleFrom(
            backgroundColor: syanatBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            textStyle: const TextStyle(fontSize: 13),
            minimumSize: const Size(72, 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(isEn ? 'Complete' : 'إنهاء'),
        ),
      ),
  ],
),


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
          ),
        ],
      ),
    );
  }
}
