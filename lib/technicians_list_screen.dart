// technicians_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_service.dart';
import 'chat_screen.dart';
import 'payment_screen.dart';
import 'glass_card.dart';

const Color syanatBlue = Color(0xFF3C21C8);

/// Maps service keys to Arabic names for backward compatibility with existing technicians
const Map<String, List<String>> serviceKeyToArabicNames = {
  'ac': ['فني تكييف'],
  'plumbing': ['سباك', 'فني دشات', 'تصليح مواتير مياه', 'صيانة خزانات المياه'],
  'electricity': ['كهربائي'],
  'finishing': ['نقاش', 'فني رخام'],
  'carpentry': ['نجار'],
  'aluminum': ['تركيب ألوميتال / سلك'],
  'small_appliances': ['فني غسلات', 'فني سخانات'],
  'pest_control': ['صيانة المسابح'],
};

class TechniciansListScreen extends StatefulWidget {
  final String serviceKey;
  final String serviceLabel;
  final String? preSelectedDescription;

  const TechniciansListScreen({
    required this.serviceKey,
    required this.serviceLabel,
    super.key,
    this.preSelectedDescription,
  });

  @override
  State<TechniciansListScreen> createState() => _TechniciansListScreenState();
}

class _TechniciansListScreenState extends State<TechniciansListScreen> {
  List<Map<String, dynamic>> technicians = [];
  bool _loading = true;
  final _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTechs();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _fetchTechs() async {
    final cityFilter = _cityController.text.trim();

    // Get both the service key and any Arabic names associated with it for backward compatibility
    final arabicNames = serviceKeyToArabicNames[widget.serviceKey] ?? [];
    final allServiceValues = [widget.serviceKey, ...arabicNames];

    // Build query - filter by role and available, then filter by city if provided
    Query q = FirebaseService.firestore
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .where('available', isEqualTo: true);

    if (cityFilter.isNotEmpty) {
      q = q.where('city', isEqualTo: cityFilter);
    }

    // Cap server-side; client-side service filter reduces this further.
    q = q.limit(20);

    setState(() => _loading = true);

    try {
      final snapshot = await q.get();
      // Filter client-side to match either service key or Arabic names
      final list = snapshot.docs
          .where((d) {
            final service = (d.data() as Map<String, dynamic>)['service'] ?? '';
            return allServiceValues.contains(service);
          })
          .map((d) {
            final data =
                Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
            data['id'] = d.id;
            return data;
          })
          .toList();

      if (!mounted) return;
      setState(() {
        technicians = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Technicians fetch error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _requestJob(Map<String, dynamic> tech) async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    final techId = tech['id'] as String;
    final descController = TextEditingController(
    text: widget.preSelectedDescription ?? '',  // PRE-FILL HERE 
    );  
    final priceController = TextEditingController();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? "Request Job" : "طلب خدمة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: InputDecoration(
                hintText: isEn ? "Describe the issue" : "وصف المشكلة",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText:
                    isEn ? "Offer price (optional)" : "السعر (اختياري)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEn ? "Cancel" : "إلغاء"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: syanatBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(isEn ? "Send" : "إرسال"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final price = double.tryParse(priceController.text.trim()) ?? 0.0;
      final jobId = await FirebaseService.createJob(
        customerId: user.uid,
        technicianId: techId,
        serviceKey: widget.serviceKey,
        description: widget.preSelectedDescription ?? descController.text.trim(),
        price: price,
      );

      // Navigate to payment BEFORE creating chat
      if (!mounted) return;
      final paymentResult = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            amount: price > 0 ? price : 200.0,
            serviceKey: widget.serviceKey,
            serviceLabel: widget.serviceLabel,
          ),
        ),
      );

      // If user cancelled payment, don't proceed
      if (paymentResult == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment cancelled")),
        );
        return;
      }

      // Link payment to the job
      await FirebaseService.firestore
          .collection('payments')
          .doc(paymentResult.paymentId)
          .update({'orderId': jobId});

      final chatId = await FirebaseService.getOrCreateChat(
        user.uid,
        techId,
        jobId: jobId,
      );
      
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, isTechnician: false),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? "Job requested & payment confirmed" : "تم طلب الخدمة ودفع الخدمة"),
        ),
      );
    } catch (e) {
      debugPrint("request job error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? "Something went wrong. Please try again." : "حدث خطأ. يرجى المحاولة مرة أخرى.")),
      );
    }
  }

  InputDecoration _searchDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixIcon: const Icon(Icons.search, color: Colors.grey),
    );
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
            appBar: AppBar(
              backgroundColor: syanatBlue,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                widget.serviceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: Column(
              children: [
                // Blue header with city search
                Container(
                  color: syanatBlue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  child: TextField(
                    controller: _cityController,
                    decoration:
                        _searchDecoration(isEn ? "Search by name or service" : "ابحث بالاسم أو الخدمة"),
                    onSubmitted: (_) => _fetchTechs(),
                  ),
                ),

                // White content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    child: _loading
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: syanatBlue),
                          )
                        : technicians.isEmpty
                            ? Center(
                                child: Text(
                                  isEn
                                      ? "No technicians found"
                                      : "لم يتم العثور على فنيين",
                                  style: const TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: technicians.length,
                                itemBuilder: (context, index) {
                                  final t = technicians[index];
                                  final name =
                                      t['username'] ?? t['email'] ?? "Tech";
                                  final city = t['city'] ?? '';
                                  final rating = t['rating'] ?? 0.0;
                                  final available = t['available'] == true;

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: GlassCard(
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.grey.shade300,
                                          backgroundImage:
                                              (t['photoUrl'] as String?)
                                                          ?.isNotEmpty ==
                                                      true
                                                  ? NetworkImage(
                                                      t['photoUrl'] as String,
                                                    )
                                                  : null,
                                          child: (t['photoUrl'] as String?)
                                                      ?.isNotEmpty ==
                                                  true
                                              ? null
                                              : const Icon(
                                                  Icons.person,
                                                  color: Colors.black54,
                                                ),
                                        ),
                                        title: Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.black,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (city.isNotEmpty)
                                              Text(
                                                city,
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isEn
                                                  ? "Rating: $rating"
                                                  : "التقييم: $rating",
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: SizedBox(
                                          width: 90,
                                          child: ElevatedButton(
                                            onPressed: available
                                                ? () => _requestJob(t)
                                                : null,
                                            style: ElevatedButton
                                                .styleFrom(
                                              backgroundColor:
                                                  syanatBlue,
                                              foregroundColor:
                                                  Colors.white,
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 12,
                                                vertical: 3,
                                              ),
                                              minimumSize:
                                                  const Size(90, 32),
                                            ),
                                            child: Text(
                                              isEn ? "Request" : "اطلب",
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
}
