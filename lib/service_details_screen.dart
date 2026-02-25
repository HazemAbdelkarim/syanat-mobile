import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'technicians_list_screen.dart';
import '../firebase_service.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class ServiceDetailsScreen extends StatefulWidget {
  final String serviceKey;
  final String serviceLabel;

  const ServiceDetailsScreen({
    super.key,
    required this.serviceKey,
    required this.serviceLabel,
  });

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  Locale _locale = const Locale('en');

  void _switchLanguage() {
    setState(() {
      _locale = _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    });
  }

  List<Map<String, String>> _commonProblems() {
    final isPlumbing = widget.serviceKey.toLowerCase().contains('plumb') ||
        widget.serviceKey.toLowerCase().contains('سباك');
    final isEn = _locale.languageCode == 'en';

    if (isPlumbing) {
      return [
        {'en': 'Leak under sink', 'ar': 'تسريب تحت البانيو'},
        {'en': 'Clogged drain', 'ar': 'الصرف مسدود'},
        {'en': 'Toilet not flushing', 'ar': 'الحمام مش بيشتغل'},
        {'en': 'Low water pressure', 'ar': 'المية ضعيفة'},
        {'en': 'Water heater not working', 'ar': 'الغاز مش شغال'},
      ];
    } else {
      return [
        {'en': 'No electricity in room', 'ar': 'الكهربا مقطوعة في الأوضة'},
        {'en': 'Circuit breaker tripping', 'ar': 'الجريب يقفّل لوحده'},
        {'en': 'Lights flickering', 'ar': 'اللمبات بتومض'},
        {'en': 'Outlet not working', 'ar': 'الموصلا مش شغال'},
        {'en': 'Install new light/fan', 'ar': 'تركيب لمبة/مروحة جديدة'},
      ];
    }
  }

  Future<void> _showQuickOrderDialog(BuildContext context) async {
    final isEn = _locale.languageCode == 'en';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Quick Order' : 'طلب سريع'),
        content: Text(
          isEn
              ? 'A technician will be sent immediately to check your problem.\n\nVisit cost: 200 EGP'
              : 'هيتبعتلك فني حالا يشوف المشكلة في المكان.\n\nتكلفة الزيارة: ٢٠٠ جنيه',
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
            child: Text(isEn ? 'Confirm' : 'تمام'),
          ),
        ],
      ),
    );

    if (confirmed == true && FirebaseService.getCurrentUser() != null) {
      try {
        await FirebaseService.createJob(
          customerId: FirebaseService.getCurrentUser()!.uid,
          serviceKey: widget.serviceKey,
          description: 'طلب سريع - فحص ميداني',
          price: 200.0,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Quick order sent!' : 'الطلب السريع اتبعت!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  void _openProblemTechnicians(String problem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TechniciansListScreen(
          serviceKey: widget.serviceKey,
          serviceLabel: problem,
          preSelectedDescription: problem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _locale.languageCode == 'en';
    final problems = _commonProblems();

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // Purple header with language button
            Container(
              width: double.infinity,
              color: syanatBlue,
              padding: const EdgeInsets.only(
                top: 50,
                left: 16,
                right: 16,
                bottom: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      widget.serviceLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _switchLanguage,
                    icon: const Icon(Icons.language, color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick order button
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Quick Order' : 'طلب سريع',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isEn
                                ? 'Send a technician right now to check your problem on-site!'
                                : 'هيتبعتلك فني حالا يشوف المشكلة في بيتك!',
                            style: const TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () => _showQuickOrderDialog(context),
                              icon: const Icon(Icons.flash_on, color: Colors.white),
                              label: Text(
                                isEn ? 'Quick Order - 200 EGP' : 'طلب سريع - ٢٠٠ جنيه',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: syanatBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Common problems section
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: syanatBlue, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'Common Problems' : 'المشاكل الشائعة',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                isEn
                                    ? 'Tap any problem to find the right technician'
                                    : 'اضغط على المشكلة وهتلاقي الفني المناسب',
                                style: const TextStyle(fontSize: 15, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Problems list
                    ..._commonProblems().map(
                      (problemMap) {
                        final problem = isEn ? problemMap['en']! : problemMap['ar']!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: GestureDetector(
                            onTap: () => _openProblemTechnicians(problem),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.grey.shade50,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: syanatBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.build_circle,
                                      color: syanatBlue,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      problem,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey.shade600,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
