import 'dart:async';
import 'package:flutter/material.dart';
import 'service_details_screen.dart';
import 'orders_screen.dart';
import 'more_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);
const Color bgGrey = Color(0xFFF4F5F7); // Sahl-like light grey background

const String homeMoreLabelEn = 'More';
const String homeMoreLabelAr = 'المزيد';
const String homeMoreDescriptionEn =
    'Choose from the rest of our available services.';
const String homeMoreDescriptionAr = 'اختر من باقي الخدمات المتاحة.';
const List<String> prioritizedHomeServiceKeys = [
  'electricity',
  'ac',
  'plumbing',
  'aluminum',
  'carpentry',
  'security_intercom',
  'large_appliances',
  'small_appliances',
];

@immutable
class HomeServiceCatalogEntry {
  final String key;
  final String routeLabelEn;
  final String routeLabelAr;
  final String? tileLabelEn;
  final String? tileLabelAr;
  final IconData icon;
  final String assetName;

  const HomeServiceCatalogEntry({
    required this.key,
    required this.routeLabelEn,
    required this.routeLabelAr,
    required this.icon,
    required this.assetName,
    this.tileLabelEn,
    this.tileLabelAr,
  });

  String label(bool isEn) => isEn
      ? (tileLabelEn ?? routeLabelEn)
      : (tileLabelAr ?? routeLabelAr);
}

const List<HomeServiceCatalogEntry> homeServiceCatalog = [
  HomeServiceCatalogEntry(
    key: 'electricity',
    routeLabelEn: 'Electrical',
    routeLabelAr: 'كهرباء',
    tileLabelEn: 'Electricity',
    icon: Icons.electric_bolt_outlined,
    assetName: 'Electricity.png',
  ),
  HomeServiceCatalogEntry(
    key: 'ac',
    routeLabelEn: 'Air Conditioning',
    routeLabelAr: 'تكييف',
    icon: Icons.ac_unit,
    assetName: 'air conditioning.png',
  ),
  HomeServiceCatalogEntry(
    key: 'plumbing',
    routeLabelEn: 'Plumbing',
    routeLabelAr: 'سباكة',
    icon: Icons.water_drop_outlined,
    assetName: 'Plumbing.png',
  ),
  HomeServiceCatalogEntry(
    key: 'security_intercom',
    routeLabelEn: 'Security & Intercom',
    routeLabelAr: 'أنظمة أمن وإنتركم',
    icon: Icons.videocam_outlined,
    assetName: 'Security and intercom.png',
  ),
  HomeServiceCatalogEntry(
    key: 'large_appliances',
    routeLabelEn: 'Large Appliances',
    routeLabelAr: 'أجهزة منزلية كبيرة',
    icon: Icons.kitchen_outlined,
    assetName: 'Large appliances.png',
  ),
  HomeServiceCatalogEntry(
    key: 'small_appliances',
    routeLabelEn: 'Small Appliances',
    routeLabelAr: 'أجهزة صغيرة',
    icon: Icons.coffee_maker_outlined,
    assetName: 'Small appliances.png',
  ),
  HomeServiceCatalogEntry(
    key: 'carpentry',
    routeLabelEn: 'Carpentry',
    routeLabelAr: 'نجارة',
    icon: Icons.handyman_outlined,
    assetName: 'carpentry.png',
  ),
  HomeServiceCatalogEntry(
    key: 'pest_control',
    routeLabelEn: 'Pest Control',
    routeLabelAr: 'مكافحة حشرات',
    icon: Icons.bug_report_outlined,
    assetName: 'Pest Control.png',
  ),
  HomeServiceCatalogEntry(
    key: 'aluminum',
    routeLabelEn: 'Aluminum',
    routeLabelAr: 'ألوميتال',
    icon: Icons.window_outlined,
    assetName: 'Aluminum.png',
  ),
  HomeServiceCatalogEntry(
    key: 'finishing',
    routeLabelEn: 'Finishing',
    routeLabelAr: 'تشطيبات',
    icon: Icons.format_paint_outlined,
    assetName: 'Finishing.png',
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
  final Map<String, String>? _savedLocationData = null; 

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

  Widget _buildServiceTile({
    required HomeServiceCatalogEntry service,
    required bool isEn,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18), // Increased slightly for premium feel
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // Slightly more pronounced soft shadow
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // No circular background, raw clean icon
            Image.asset(
              'assets/Icons/${service.assetName}',
              width: 36,
              height: 36,
              color: syanatBlue,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder: (ctx, err, stack) => Icon(
                service.icon,
                size: 36,
                color: syanatBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              service.label(isEn),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w400, // Clean regular/medium weight
              ),
              maxLines: 1,
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
      child: Container(
        decoration: BoxDecoration(
           // Sahl uses a distinct light colored bg for the 'more' tile
          color: syanatBlue.withOpacity(0.08), 
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.grid_view_rounded,
              size: 34,
              color: syanatBlue,
            ),
            const SizedBox(height: 12),
            Text(
              isEn ? homeMoreLabelEn : homeMoreLabelAr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
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
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isEn = Localizations.localeOf(ctx).languageCode == 'en';
        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            expand: false,
            shouldCloseOnMinExtent: true,
            builder: (_, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: bgGrey,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEn ? homeMoreLabelEn : homeMoreLabelAr,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: isEn ? 'Close' : 'إغلاق',
                          icon: const Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.of(ctx).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: remainingServices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.95,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
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

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgGrey,
        bottomNavigationBar: SizedBox(
          height: 80,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: syanatBlue,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            elevation: 20,
            iconSize: 30,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home_rounded),
                label: isEn ? 'Home' : 'الرئيسية',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.receipt_long_outlined),
                activeIcon: const Icon(Icons.receipt_long),
                label: isEn ? 'My Orders' : 'طلباتي',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: isEn ? 'Account' : 'حسابي',
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeBody(isEn),
            const OrdersScreen(),
            const MoreScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBody(bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 20% height Clean Blue Header (increased for premium feel)
        Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.20,
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 16, 20, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C4DFF), Color(0xFF6C3CE1), Color(0xFF5228B5)]),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
          ),
          child: Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Text aligned to the left
                const Text(
                  'Syanat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                // White notification button on the right
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: syanatBlue, size: 26),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            // Reduced bottom padding to zero to close empty space above nav
            padding: const EdgeInsets.only(top: 0, bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner image — assets/placeholder.png MUST exist; no errorBuilder fallback.
                // AspectRatio matches the source's 3:1 design so it renders without crop/stretch on any device width.
                SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 3 / 1,
                    child: Image.asset(
                      'assets/placeholder.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    isEn ? 'Services' : 'الخدمات',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18, // Slightly smaller, cleaner like Sahl
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Builder(
                    builder: (context) {
                      final services = _pinnedServices;
                      final displayedItemCount = services.length + 1;
                      if (services.isEmpty) {
                        return Center(
                          child: Text(
                            isEn ? 'No services found' : 'لا توجد خدمات متاحة',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedItemCount,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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
                              service.tileLabelEn ?? service.routeLabelEn,
                              service.tileLabelAr ?? service.routeLabelAr,
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
    );
  }
}



