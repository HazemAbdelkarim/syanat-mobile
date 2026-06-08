import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'service_details_screen.dart';
import 'orders_screen.dart';
import 'more_screen.dart';

// ---------------------------------------------------------------------------
// Palette — Behance reference "Home Maintenance Platform in Saudi Arabia".
// Clean purple + lavender on an off-white page; no heavy colored header.
// These tokens are local to the Home screen (each screen keeps its own copy)
// so this redesign does not recolor the rest of the app — the migration to
// this palette is happening step by step, one screen at a time.
// ---------------------------------------------------------------------------
const Color syanatBlue = Color(0xFF6C3FA0); // brand purple (kept name: local)
const Color kPrimary = Color(0xFF6C3FA0); // brand purple
const Color kPrimaryDark = Color(0xFF211D40); // headings / dark navy text
const Color kLavender = Color(0xFFEADDF9); // hero / accent surface
const Color kLavenderSoft = Color(0xFFF3EEFB); // soft tint (more tile, chips)
const Color bgGrey = Color(0xFFF7F6FA); // page background (off-white)
const Color kCardBorder = Color(0xFFEDEAF3); // hairline card border
const Color kTextMuted = Color(0xFF8B8699); // secondary text

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
  int _currentIndex = 0; // 0 = Home, 1 = My Orders, 2 = Account

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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kCardBorder),
            boxShadow: [
              BoxShadow(
                color: kPrimaryDark.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/Icons/${service.assetName}',
                width: 32,
                height: 32,
                color: kPrimary,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (ctx, err, stack) => Icon(
                  service.icon,
                  size: 32,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                service.label(isEn),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kPrimaryDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: kCardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEn ? 'All services' : 'كل الخدمات',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryDark,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: isEn ? 'Close' : 'إغلاق',
                          icon: const Icon(Icons.close_rounded,
                              color: kPrimaryDark),
                          onPressed: () => Navigator.of(ctx).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: remainingServices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.92,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: bgGrey,
          bottomNavigationBar: _buildBottomNav(isEn),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeBody(isEn),
              const OrdersScreen(),
              const MoreScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isEn) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: kPrimaryDark.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: kPrimary,
        unselectedItemColor: kTextMuted,
        backgroundColor: Colors.white,
        elevation: 0,
        iconSize: 26,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12.5,
        unselectedFontSize: 12.5,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
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
    );
  }

  Widget _buildHomeBody(bool isEn) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildTopBar(isEn),
                const SizedBox(height: 18),
                _buildSearchBar(isEn),
                const SizedBox(height: 22),
                _buildHeroCard(isEn),
                const SizedBox(height: 28),
                _buildSectionHeader(isEn),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.92,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final service = _pinnedServices[index];
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
                childCount: _pinnedServices.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Location selector + notification bell — sits on the clean off-white page.
  Widget _buildTopBar(bool isEn) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: kLavenderSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: kPrimary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEn ? 'Your location' : 'موقعك',
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isEn ? 'Set your location' : 'حدّد موقعك',
                              style: const TextStyle(
                                color: kPrimaryDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: kPrimaryDark, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kCardBorder),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: kPrimaryDark, size: 22),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isEn) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kCardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: kTextMuted, size: 22),
            const SizedBox(width: 10),
            Text(
              isEn ? 'Search for a service' : 'ابحث عن خدمة',
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB), // blue hero surface
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEn ? 'The nearest technician to you' : 'أقرب فني لموقعك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isEn
                      ? 'We connect you with the closest available technician — no waiting, no appointments.'
                      : 'نوصلك بأقرب فني متاح بدون انتظار أو مواعيد.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.engineering_rounded,
                color: kPrimary, size: 38),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isEn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isEn ? 'Everything you need' : 'كل اللي تحتاجه هنا',
          style: const TextStyle(
            color: kPrimaryDark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        InkWell(
          onTap: _showMoreServicesSheet,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Text(
                  isEn ? 'View all' : 'عرض الكل',
                  style: const TextStyle(
                    color: kPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  isEn
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_rounded,
                  color: kPrimary,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
