import 'package:flutter/material.dart';
import 'service_details_screen.dart';
import 'glass_card.dart';
import 'orders_screen.dart';
import 'more_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);
const String homeMoreLabelEn = 'More';
const String homeMoreLabelAr = 'المزيد';
const String homeMoreDescriptionEn =
    'Choose from the rest of our available services.';
const String homeMoreDescriptionAr = 'اختر من باقي الخدمات المتاحة.';
const List<String> prioritizedHomeServiceKeys = [
  'ac',
  'plumbing',
  'electricity',
  'large_appliances',
  'carpentry',
];

@immutable
class HomeServiceCatalogEntry {
  final String key;
  final String routeLabelEn;
  final String routeLabelAr;
  final String? tileLabelEn;
  final String? tileLabelAr;
  final IconData icon;

  const HomeServiceCatalogEntry({
    required this.key,
    required this.routeLabelEn,
    required this.routeLabelAr,
    required this.icon,
    this.tileLabelEn,
    this.tileLabelAr,
  });

  String label(bool isEn) => isEn
      ? (tileLabelEn ?? routeLabelEn)
      : (tileLabelAr ?? routeLabelAr);
}

const List<HomeServiceCatalogEntry> homeServiceCatalog = [
  HomeServiceCatalogEntry(
    key: 'ac',
    routeLabelEn: 'Air Conditioning',
    routeLabelAr: 'تكييف',
    icon: Icons.ac_unit,
  ),
  HomeServiceCatalogEntry(
    key: 'plumbing',
    routeLabelEn: 'Plumbing',
    routeLabelAr: 'سباكة',
    icon: Icons.plumbing,
  ),
  HomeServiceCatalogEntry(
    key: 'electricity',
    routeLabelEn: 'Electrical',
    routeLabelAr: 'كهرباء',
    tileLabelEn: 'Electricity',
    icon: Icons.electrical_services,
  ),
  HomeServiceCatalogEntry(
    key: 'security_intercom',
    routeLabelEn: 'Security & Intercom',
    routeLabelAr: 'أنظمة أمن وإنتركم',
    icon: Icons.videocam,
  ),
  HomeServiceCatalogEntry(
    key: 'large_appliances',
    routeLabelEn: 'Large Appliances',
    routeLabelAr: 'أجهزة منزلية كبيرة',
    icon: Icons.kitchen,
  ),
  HomeServiceCatalogEntry(
    key: 'small_appliances',
    routeLabelEn: 'Small Appliances',
    routeLabelAr: 'أجهزة منزلية صغيرة',
    icon: Icons.coffee,
  ),
  HomeServiceCatalogEntry(
    key: 'carpentry',
    routeLabelEn: 'Carpentry',
    routeLabelAr: 'نجارة',
    icon: Icons.carpenter,
  ),
  HomeServiceCatalogEntry(
    key: 'pest_control',
    routeLabelEn: 'Pest Control',
    routeLabelAr: 'مكافحة حشرات',
    icon: Icons.bug_report,
  ),
  HomeServiceCatalogEntry(
    key: 'aluminum',
    routeLabelEn: 'Aluminum',
    routeLabelAr: 'ألوميتال',
    icon: Icons.door_front_door,
  ),
  HomeServiceCatalogEntry(
    key: 'finishing',
    routeLabelEn: 'Finishing',
    routeLabelAr: 'تشطيبات',
    icon: Icons.format_paint,
  ),
];

List<HomeServiceCatalogEntry> buildPinnedHomeServices(
  List<HomeServiceCatalogEntry> catalog,
) {
  return prioritizedHomeServiceKeys
      .map(
        (key) => catalog.firstWhere(
          (service) => service.key == key,
          orElse: () => throw StateError(
            'Missing home service configuration for $key',
          ),
        ),
      )
      .toList(growable: false);
}

List<HomeServiceCatalogEntry> buildRemainingHomeServices(
  List<HomeServiceCatalogEntry> catalog,
) {
  final prioritizedKeys = prioritizedHomeServiceKeys.toSet();
  return catalog
      .where((service) => !prioritizedKeys.contains(service.key))
      .toList(growable: false);
}

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0; // 0 = Services, 1 = My Orders, 2 = More
  Map<String, String>? _savedLocationData;

  List<HomeServiceCatalogEntry> get _pinnedServices =>
      buildPinnedHomeServices(homeServiceCatalog);

  List<HomeServiceCatalogEntry> get _remainingServices =>
      buildRemainingHomeServices(homeServiceCatalog);

  void _openCategory(String serviceKey, String labelEn, String labelAr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailsScreen(
          serviceKey: serviceKey,
          labelEn: labelEn,
          labelAr: labelAr,
        ),
      ),
    );
  }

  String _buildAddressString({
    required String street,
    required String city,
    required String building,
    required String notes,
  }) {
    final parts = <String>[];
    if (street.isNotEmpty) parts.add(street);
    if (building.isNotEmpty) parts.add(building);
    if (city.isNotEmpty) parts.add(city);
    if (notes.isNotEmpty) parts.add(notes);
    return parts.join(', ');
  }

  Widget _buildServiceTile({
    required HomeServiceCatalogEntry service,
    required bool isEn,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              service.icon,
              size: 26,
              color: syanatBlue,
            ),
            const SizedBox(height: 6),
            Text(
              service.label(isEn),
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
  }

  Widget _buildMoreTile(bool isEn) {
    return GestureDetector(
      onTap: _showMoreServicesSheet,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x143C21C8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.apps_rounded,
                size: 22,
                color: syanatBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isEn ? homeMoreLabelEn : homeMoreLabelAr,
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
  }

  Future<void> _showMoreServicesSheet() async {
    final remainingServices = _remainingServices;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isEn = Localizations.localeOf(ctx).languageCode == 'en';
        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEn ? homeMoreLabelEn : homeMoreLabelAr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEn
                          ? homeMoreDescriptionEn
                          : homeMoreDescriptionAr,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: remainingServices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final service = remainingServices[index];
                        return _buildServiceTile(
                          service: service,
                          isEn: isEn,
                          onTap: () {
                            Navigator.pop(ctx);
                            _openCategory(
                              service.key,
                              service.tileLabelEn ?? service.routeLabelEn,
                              service.tileLabelAr ?? service.routeLabelAr,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _locationFieldCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0x143C21C8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: syanatBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLocationSheet() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final streetController = TextEditingController(
      text: _savedLocationData?['street'] ?? '',
    );
    final cityController = TextEditingController(
      text: _savedLocationData?['city'] ?? '',
    );
    final buildingController = TextEditingController(
      text: _savedLocationData?['building'] ?? '',
    );
    final notesController = TextEditingController(
      text: _savedLocationData?['notes'] ?? '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEn ? 'Your location' : 'موقعك',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEn
                          ? 'Save your address so technicians can reach you faster.'
                          : 'احفظ عنوانك عشان الفنيين يوصلوا إليك بسرعة.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _locationFieldCard(
                      icon: Icons.signpost,
                      label: isEn ? 'Street' : 'شارع',
                      controller: streetController,
                    ),
                    const SizedBox(height: 12),
                    _locationFieldCard(
                      icon: Icons.location_city,
                      label: isEn ? 'City' : 'مدينة',
                      controller: cityController,
                    ),
                    const SizedBox(height: 12),
                    _locationFieldCard(
                      icon: Icons.apartment,
                      label: isEn ? 'Building' : 'مبنى',
                      controller: buildingController,
                    ),
                    const SizedBox(height: 12),
                    _locationFieldCard(
                      icon: Icons.notes,
                      label: isEn ? 'Additional notes' : 'ملاحظات إضافية',
                      controller: notesController,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(isEn ? 'Cancel' : 'إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final street = streetController.text.trim();
                            final city = cityController.text.trim();
                            final building = buildingController.text.trim();
                            final notes = notesController.text.trim();

                            if (street.isEmpty || city.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEn
                                        ? 'Please enter street and city.'
                                        : 'يرجى إدخال الشارع والمدينة.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final address = _buildAddressString(
                              street: street,
                              city: city,
                              building: building,
                              notes: notes,
                            );

                            setState(() {
                              _savedLocationData = {
                                'street': street,
                                'city': city,
                                'building': building,
                                'notes': notes,
                                'address': address,
                              };
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: syanatBlue,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isEn ? 'Save' : 'حفظ'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    streetController.dispose();
    cityController.dispose();
    buildingController.dispose();
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final savedAddress = _savedLocationData?['address'];

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: syanatBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _openLocationSheet,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  savedAddress == null
                                      ? (isEn
                                          ? 'Set your location'
                                          : 'حدد موقعك')
                                      : (savedAddress.length > 25
                                          ? '${savedAddress.substring(0, 25)}...'
                                          : savedAddress),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  height: 190,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
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
                                      isEn
                                          ? 'Services'
                                          : 'الصيانة و التركيبات',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isEn
                                          ? 'Book home maintenance in a few taps.'
                                          : 'احجز صيانة بيتك في خطوات بسيطة.',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Builder(
                                      builder: (context) {
                                        final services = _pinnedServices;
                                        final displayedItemCount =
                                            services.length + 1;
                                        if (services.isEmpty) {
                                          return Center(
                                            child: Text(
                                              isEn
                                                  ? 'No services found'
                                                  : 'لا توجد خدمات متاحة',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          );
                                        }
                                        final rowCount =
                                            (displayedItemCount / 3).ceil();
                                        final availableWidth =
                                            MediaQuery.of(context).size.width -
                                                32;
                                        final itemWidth =
                                            (availableWidth - 24) / 3;
                                        final cardHeight = itemWidth * 0.8;
                                        final gridHeight =
                                            (rowCount * cardHeight) +
                                                ((rowCount - 1) * 12);

                                        return SizedBox(
                                          height: gridHeight,
                                          child: GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: displayedItemCount,
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              childAspectRatio: 1.2,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                            ),
                                            itemBuilder: (context, index) {
                                              if (index == services.length) {
                                                return _buildMoreTile(isEn);
                                              }

                                              final service = services[index];
                                              return _buildServiceTile(
                                                service: service,
                                                isEn: isEn,
                                                onTap: () => _openCategory(
                                                  service.key,
                                                  service.tileLabelEn ??
                                                      service.routeLabelEn,
                                                  service.tileLabelAr ??
                                                      service.routeLabelAr,
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
                const OrdersScreen(),
                const MoreScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
