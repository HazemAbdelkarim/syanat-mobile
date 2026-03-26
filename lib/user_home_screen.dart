import 'package:flutter/material.dart';
import 'service_details_screen.dart';
import 'glass_card.dart';
import 'orders_screen.dart';
import 'more_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0; // 0 = Services, 1 = My Orders, 2 = More
  String? _savedLocation;

  final List<Map<String, dynamic>> _serviceCatalog = const [
    {'key': 'ac', 'name_en': 'Air Conditioning', 'name_ar': 'تكييف', 'icon': Icons.ac_unit},
    {'key': 'plumbing', 'name_en': 'Plumbing', 'name_ar': 'سباكة', 'icon': Icons.plumbing},
    {'key': 'electricity', 'name_en': 'Electrical', 'name_ar': 'كهرباء', 'icon': Icons.electrical_services},
    {'key': 'security_intercom', 'name_en': 'Security & Intercom', 'name_ar': 'أنظمة أمن وإنتركم', 'icon': Icons.videocam},
    {'key': 'large_appliances', 'name_en': 'Large Appliances', 'name_ar': 'أجهزة منزلية كبيرة', 'icon': Icons.kitchen},
    {'key': 'small_appliances', 'name_en': 'Small Appliances', 'name_ar': 'أجهزة منزلية صغيرة', 'icon': Icons.coffee},
    {'key': 'carpentry', 'name_en': 'Carpentry', 'name_ar': 'نجارة', 'icon': Icons.carpenter},
    {'key': 'pest_control', 'name_en': 'Pest Control', 'name_ar': 'مكافحة حشرات', 'icon': Icons.bug_report},
    {'key': 'aluminum', 'name_en': 'Aluminum', 'name_ar': 'ألوميتال', 'icon': Icons.door_front_door},
    {'key': 'finishing', 'name_en': 'Finishing', 'name_ar': 'تشطيبات', 'icon': Icons.format_paint},
  ];

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
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEn ? "Your location" : "موقعك",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? "Save your address so technicians can reach you faster."
                    : "احفظ عنوانك عشان الفنيين يوصلوا إليك بسرعة.",
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: isEn ? "Street, building, apartment…" : "الشارع، العمارة، الشقة...",
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              selectedItemColor: syanatBlue,
              unselectedItemColor: Colors.grey,
              backgroundColor: Colors.white,
              elevation: 8,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_repair_service_outlined),
                  activeIcon: const Icon(Icons.home_repair_service),
                  label: isEn ? 'Services' : 'الخدمات',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: isEn ? 'My Orders' : 'طلباتي',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.more_horiz),
                  activeIcon: const Icon(Icons.more_horiz),
                  label: isEn ? 'More' : 'المزيد',
                ),
              ],
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: [
                // ── Tab 0: Services ──────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Blue top bar — location only
                    Container(
                      color: syanatBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _openLocationSheet,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _savedLocation == null
                                      ? (isEn ? "Set your location" : "حدد موقعك")
                                      : (_savedLocation!.length > 25
                                          ? '${_savedLocation!.substring(0, 25)}...'
                                          : _savedLocation!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Banner — switches by language
                            Container(
                              width: double.infinity,
                              color: syanatBlue,
                              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  isEn
                                      ? 'assets/syanat_banner.jpeg'
                                      : 'assets/syanat_banner_ar.png',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            // White rounded panel
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
                                          : "احجز صيانة بيتك في خطوات بسيطة.",
                                      style: const TextStyle(color: Colors.black54, fontSize: 14),
                                    ),
                                    const SizedBox(height: 12),

                                    // Services grid
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
                                        final availableWidth = MediaQuery.of(context).size.width - 32;
                                        final itemWidth = (availableWidth - 24) / 3;
                                        final cardHeight = itemWidth * 0.8;
                                        final gridHeight = (rowCount * cardHeight) + ((rowCount - 1) * 12);

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
                                                    horizontal: 8, vertical: 10,
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

                // ── Tab 1: My Orders ─────────────────────────────────────
                const OrdersScreen(),

                // ── Tab 2: More ───────────────────────────────────────────
                const MoreScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
