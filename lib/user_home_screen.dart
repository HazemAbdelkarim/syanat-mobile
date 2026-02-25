import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_service.dart';
import 'service_details_screen.dart';
import 'chat_screen.dart';
import 'glass_card.dart';
import 'settings_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8); // brand blue

class UserHomeScreen extends StatefulWidget {
  final Function(Locale) setLocale;
  const UserHomeScreen({required this.setLocale, super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  List<Map<String, dynamic>> _activeTechnicians = [];
  StreamSubscription<QuerySnapshot>? _techsSubscription;

  // Used for search display of technician service names (en/ar) by key
  Map<String, Map<String, String>> _serviceNames = {};

  final _searchController = TextEditingController();

  String? _savedLocation; // local cached address text

  // ✅ Home services (service categories) with localized labels + icons
  // IMPORTANT: Make sure these keys match the values stored in technicians' `service` field in Firestore.
  final List<Map<String, dynamic>> _serviceCatalog = const [
    {
      'key': 'ac',
      'name_en': 'Air Conditioning',
      'name_ar': 'تكييف',
      'icon': Icons.ac_unit,
    },
    {
      'key': 'plumbing',
      'name_en': 'Plumbing',
      'name_ar': 'سباكة',
      'icon': Icons.plumbing,
    },
    {
      'key': 'electricity',
      'name_en': 'Electrical',
      'name_ar': 'كهرباء',
      'icon': Icons.electrical_services,
    },
    {
      'key': 'security_intercom',
      'name_en': 'Security & Intercom',
      'name_ar': 'أنظمة أمن وإنتركم',
      'icon': Icons.videocam,
    },
    {
      'key': 'large_appliances',
      'name_en': 'Large Appliances',
      'name_ar': 'أجهزة منزلية كبيرة (تلاجات – غسالات)',
      'icon': Icons.kitchen,
    },
    {
      'key': 'small_appliances',
      'name_en': 'Small Appliances',
      'name_ar': 'أجهزة منزلية صغيرة',
      'icon': Icons.coffee,
    },
    {
      'key': 'carpentry',
      'name_en': 'Carpentry',
      'name_ar': 'نجارة',
      'icon': Icons.carpenter,
    },
    {
      'key': 'pest_control',
      'name_en': 'Pest Control',
      'name_ar': 'مكافحة حشرات',
      'icon': Icons.bug_report,
    },
    {
      'key': 'aluminum',
      'name_en': 'Aluminum',
      'name_ar': 'ألوميتال',
      'icon': Icons.door_front_door,
    },
    {
      'key': 'finishing',
      'name_en': 'Finishing',
      'name_ar': 'تشطيبات',
      'icon': Icons.format_paint,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadServiceNames(); // keep technician search working
    _subscribeToActiveTechnicians();
  }

  @override
  void dispose() {
    _techsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Keeps search by service name working (uses Firebase services collection)
  // NOTE: If FirebaseService.getServices currently stores job titles instead of categories,
  // search might be slightly off, but Home grid will be correct.
  Future<void> _loadServiceNames() async {
    try {
      final services = await FirebaseService.getServices();
      final Map<String, Map<String, String>> names = {};
      for (final service in services) {
        final key = service['key'] as String? ?? '';
        final nameEn = service['name_en'] as String? ?? '';
        final nameAr = service['name_ar'] as String? ?? '';
        if (key.isNotEmpty) {
          names[key] = {'en': nameEn, 'ar': nameAr};
        }
      }
      setState(() => _serviceNames = names);
    } catch (e) {
      debugPrint('Error loading service names: $e');
    }
  }

  void _subscribeToActiveTechnicians() {
    _techsSubscription?.cancel();
    final searchQuery = _searchController.text.trim().toLowerCase();

    Query q = FirebaseService.firestore
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .where('available', isEqualTo: true);

    _techsSubscription = q.snapshots().listen((snapshot) {
      final allTechnicians = snapshot.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        data['id'] = d.id;
        return data;
      }).toList();

      List<Map<String, dynamic>> filteredList = allTechnicians;
      if (searchQuery.isNotEmpty) {
        filteredList = allTechnicians.where((tech) {
          final name =
              (tech['username'] ?? tech['email'] ?? '').toString().toLowerCase();
          final serviceKey = tech['service'] as String? ?? '';

          final serviceNameMap = _serviceNames[serviceKey];
          final serviceNameEn = serviceNameMap?['en']?.toLowerCase() ?? '';
          final serviceNameAr = serviceNameMap?['ar']?.toLowerCase() ?? '';
          final serviceKeyLower = serviceKey.toLowerCase();

          return name.contains(searchQuery) ||
              serviceNameEn.contains(searchQuery) ||
              serviceNameAr.contains(searchQuery) ||
              serviceKeyLower.contains(searchQuery);
        }).toList();
      }

      setState(() => _activeTechnicians = filteredList);
    }, onError: (e) {
      debugPrint('Error loading active technicians: $e');
    });
  }

  Future<void> _openChat(Map<String, dynamic> technician) async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? "Please login first" : "يرجى تسجيل الدخول أولاً"),
        ),
      );
      return;
    }

    try {
      final techId = technician['id'] as String;
      final chatId = await FirebaseService.getOrCreateChat(user.uid, techId);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: chatId, isTechnician: false),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error opening chat: $e");
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? "Error opening chat" : "خطأ في فتح الدردشة"),
          ),
        );
      }
    }
  }

  void _switchLanguage() {
    final newLocale = Localizations.localeOf(context).languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    widget.setLocale(newLocale);
  }

  void _openCategory(String serviceKey, String serviceLabel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailsScreen(
          serviceKey: serviceKey,
          serviceLabel: serviceLabel,
        ),
      ),
    );
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixIcon: const Icon(Icons.search, color: Colors.grey),
    );
  }

  void _openLocationSheet() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final addressController = TextEditingController(text: _savedLocation ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEn ? "Your location" : "موقعك",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? "Save your address so technicians can reach you faster."
                    : "احفظ عنوانك ليسهل على الفنيين الوصول إليك.",
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText:
                      isEn ? "Street, building, apartment…" : "الشارع، العمارة، الشقة...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(isEn ? "Cancel" : "إلغاء"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final txt = addressController.text.trim();
                        _savedLocation = txt.isEmpty ? null : txt;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: syanatBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isEn ? "Save" : "حفظ"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Purple top area: location + settings/lang + search
                Container(
                  color: syanatBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // location left, buttons right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _openLocationSheet,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _savedLocation == null
                                      ? (isEn ? "Set your location" : "حدد موقعك")
                                      : (_savedLocation!.length > 25
                                          ? _savedLocation!.substring(0, 25) + "..."
                                          : _savedLocation!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white, size: 18),
                              ],
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
                                icon: const Icon(Icons.settings, color: Colors.white),
                              ),
                              IconButton(
                                onPressed: _switchLanguage,
                                icon: const Icon(Icons.language, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        decoration: _searchDecoration(
                          isEn ? "Search by name or service" : "ابحث بالاسم أو الخدمة",
                        ),
                        onChanged: (_) => _subscribeToActiveTechnicians(),
                        onSubmitted: (_) => _subscribeToActiveTechnicians(),
                      ),
                    ],
                  ),
                ),

                // Content: blue band with banner, then rounded white panel
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Blue band with banner image
                        Container(
                          width: double.infinity,
                          color: syanatBlue,
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/syanat_banner.jpeg', // your JPEG banner
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // Rounded white panel pulled up over the blue band
                        Transform.translate(
                          offset: const Offset(0, -12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? "Services" : "الصيانة و التركيبات",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isEn
                                      ? "Book home maintenance in a few taps."
                                      : "احجز صيانة منزلك في خطوات بسيطة.",
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // ✅ Services grid (categories + language switch + icons)
                                Builder(
                                  builder: (context) {
                                    final services = _serviceCatalog;

                                    if (services.isEmpty) {
                                      return Center(
                                        child: Text(
                                          isEn ? "No services found" : "لا توجد خدمات متاحة",
                                          style: const TextStyle(color: Colors.black54),
                                        ),
                                      );
                                    }

                                    final rowCount = (services.length / 3).ceil();
                                    final availableWidth =
                                        MediaQuery.of(context).size.width - 32;
                                    final itemWidth = (availableWidth - 24) / 3;
                                    final cardHeight = itemWidth * 0.8;
                                    final gridHeight = (rowCount * cardHeight) +
                                        ((rowCount - 1) * 12);

                                    return SizedBox(
                                      height: gridHeight,
                                      child: GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: services.length,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          childAspectRatio: 1.2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemBuilder: (context, index) {
                                          final item = services[index];
                                          final id = item['key'] as String? ?? '';

                                          final label = (isEn ? item['name_en'] : item['name_ar'])
                                                  as String? ??
                                              (item['name_en'] as String? ?? 'Service');

                                          final iconData = item['icon'] as IconData?;

                                          return GestureDetector(
                                            onTap: () => _openCategory(id, label),
                                            child: GlassCard(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 10,
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    iconData ?? Icons.build,
                                                    size: 26,
                                                    color: Colors.black87,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    label,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  isEn ? "Active Users" : "المستخدمون النشطون",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                _activeTechnicians.isEmpty
                                    ? Center(
                                        child: Text(
                                          isEn ? "No active technicians" : "لا يوجد فنيون نشطون",
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _activeTechnicians.length,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, index) {
                                          final tech = _activeTechnicians[index];
                                          final name =
                                              tech['username'] ?? tech['email'] ?? "Tech";
                                          final city = tech['city'] ?? '';
                                          final rating = tech['rating'] ?? 0.0;
                                          final serviceKey =
                                              tech['service'] as String? ?? '';
                                          final serviceNameMap = _serviceNames[serviceKey];
                                          final serviceNameDisplay = serviceNameMap != null
                                              ? (isEn
                                                      ? serviceNameMap['en']
                                                      : serviceNameMap['ar']) ??
                                                  serviceKey
                                              : serviceKey;

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: GlassCard(
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor: Colors.grey.shade300,
                                                  backgroundImage:
                                                      (tech['photoUrl'] as String?)?.isNotEmpty ==
                                                              true
                                                          ? NetworkImage(tech['photoUrl'] as String)
                                                          : null,
                                                  child: (tech['photoUrl'] as String?)?.isNotEmpty ==
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
                                                    Text(
                                                      serviceNameDisplay,
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                    if (city.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        city,
                                                        style: const TextStyle(
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      isEn ? "Rating: $rating" : "التقييم: $rating",
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                trailing: ElevatedButton(
                                                  onPressed: () => _openChat(tech),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.white,
                                                    foregroundColor: syanatBlue,
                                                  ),
                                                  child: Text(
                                                    isEn ? "Chat" : "دردشة",
                                                  ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
