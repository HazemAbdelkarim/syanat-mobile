import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../glass_card.dart';
import '../firebase_service.dart';
import 'services_integration.dart';
import 'models/service.dart';
import 'main.dart' show AppLocale;
import 'widgets/egyptian_phone_field.dart';
import 'widgets/map_picker_screen.dart';
import 'widgets/pin_on_map_tile.dart';
import 'job_status.dart' show inspectServiceKey;

const Color syanatBlue = Color(0xFF3C21C8);

class ServiceDetailsScreen extends StatefulWidget {
  final String serviceKey;
  final String labelEn;
  final String labelAr;

  const ServiceDetailsScreen({
    super.key,
    required this.serviceKey,
    required this.labelEn,
    required this.labelAr,
  });

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  late ServiceIntegration _serviceIntegration;
  List<Service> _services = [];
  List<String> _subcategories = [];
  bool _isLoading = true;
  bool _sheetOpen = false;
  String? _selectedSubcategory;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _serviceIntegration = ServiceIntegration();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final services = await _serviceIntegration.getServicesByKey(widget.serviceKey);
      // Collect unique subcategory English keys (stable internal keys regardless of locale)
      final subcatsSet = <String>{};
      for (final service in services) {
        if (service.subcategoryEn.trim().isNotEmpty) {
          subcatsSet.add(service.subcategoryEn);
        }
      }
      
      setState(() {
        _services = services;
        _subcategories = subcatsSet.toList()..sort((a, b) {
          // "Other / Others" always goes last
          final aIsOther = a.trim().toLowerCase().contains('other');
          final bIsOther = b.trim().toLowerCase().contains('other');
          if (aIsOther && !bIsOther) return 1;
          if (!aIsOther && bIsOther) return -1;
          return a.compareTo(b);
        });
        _selectedSubcategory = _subcategories.isNotEmpty ? _subcategories.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading services. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _switchLanguage() {
    // Update the single global app locale — the same notifier used by every
    // other screen. Never touch local state for language.
    final notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  /// Always filters by the English key, which is the stable internal identifier.
  List<Service> _getServicesForSubcategory(String subcategoryEnKey) {
    return _services.where((s) => s.subcategoryEn == subcategoryEnKey).toList();
  }

  /// Returns the display label for a subcategory English key based on current locale.
  String _subcategoryLabel(String subcategoryEnKey, bool isEn) {
    if (isEn) return subcategoryEnKey;
    // Find matching Arabic label from services data
    final match = _services.firstWhere(
      (s) => s.subcategoryEn == subcategoryEnKey,
      orElse: () => Service(
        categoryEn: '', categoryAr: '',
        subcategoryEn: subcategoryEnKey, subcategoryAr: subcategoryEnKey,
        serviceNameEn: '', serviceNameAr: '',
      ),
    );
    final ar = match.subcategoryAr.trim();
    return ar.isNotEmpty ? ar : subcategoryEnKey;
  }

  Future<void> _showInspectSheet() async {
    if (_sheetOpen) return;

    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    setState(() => _sheetOpen = true);

    try {
      final results = await Future.wait([
        FirebaseService.getProfile(user.uid),
        FirebaseService.getSavedLocations(user.uid),
      ]).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final profile = results[0] as Map<String, dynamic>?;
      final locations = results[1] as List<Map<String, dynamic>>;
      final isEn = Localizations.localeOf(context).languageCode == 'en';

      final result = await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        // Inspect orders are category-agnostic — both serviceKey and
        // serviceCategory are pinned to the canonical `inspect` marker so
        // every reader (admin web, tech app, stats) can classify the order
        // without inspecting the description payload.
        builder: (ctx) => _OrderRequestSheet(
          uid: user.uid,
          customerName: profile?['username'] as String? ??
              profile?['email'] as String? ?? '',
          serviceKey: inspectServiceKey,
          serviceCategory: inspectServiceKey,
          subservice: '',
          savedLocations: locations,
          initialPhone: profile?['phone'] as String? ?? '',
          isEn: isEn,
          isInspect: true,
        ),
      );
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn
                ? 'Request timed out. Please try again.'
                : 'انتهت مهلة الطلب. حاول مرة أخرى.'),
          ),
        );
      }


    } catch (e) {
      debugPrint('Inspect order error: $e');
      if (mounted) {
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Something went wrong. Please try again.' : 'حدث خطأ. يرجى المحاولة مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sheetOpen = false);
      }
    }
  }

  void _openServiceTechnicians(Service service) {
    _showOrderRequestSheet(service);
  }

  Future<void> _showOrderRequestSheet(Service service) async {
    if (_sheetOpen) return;

    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    setState(() => _sheetOpen = true);

    try {
      final results = await Future.wait([
        FirebaseService.getProfile(user.uid),
        FirebaseService.getSavedLocations(user.uid),
      ]).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final profile = results[0] as Map<String, dynamic>?;
      final locations = results[1] as List<Map<String, dynamic>>;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      final subservice = isEn ? service.serviceNameEn : service.serviceNameAr;

      final result = await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _OrderRequestSheet(
          uid: user.uid,
          customerName: profile?['username'] as String? ??
              profile?['email'] as String? ?? '',
          serviceKey: widget.serviceKey,
          serviceCategory: isEn ? widget.labelEn : widget.labelAr,
          subservice: subservice,
          savedLocations: locations,
          initialPhone: profile?['phone'] as String? ?? '',
          isEn: isEn,
        ),
      );
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn
                ? 'Request timed out. Please try again.'
                : 'انتهت مهلة الطلب. حاول مرة أخرى.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Order sheet error: $e');
      if (mounted) {
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Something went wrong. Please try again.' : 'حدث خطأ. يرجى المحاولة مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sheetOpen = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

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
                      isEn ? widget.labelEn : widget.labelAr,
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
                    // Inspect button — category-agnostic order with a free-text
                    // problem description and a scheduled time. The 200 EGP
                    // is a placeholder; the actual amount due is the receipt's
                    // grandTotal once the technician submits it on-site.
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Inspect' : 'فحص',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isEn
                                ? "Don't see your service? Describe the problem and pick a time — a technician will come inspect it."
                                : 'مش لاقي خدمتك؟ اوصف المشكلة واختار وقت — هيجي فني يكشف عليها.',
                            style: const TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _sheetOpen ? null : _showInspectSheet,
                              icon: _sheetOpen
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: syanatBlue,
                                      ),
                                    )
                                  : const Icon(Icons.search, color: Colors.white),
                              label: Text(
                                isEn ? 'Inspect — 200 EGP' : 'فحص — ٢٠٠ جنيه',
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

                    // Services/Subcategories section
                    if (!_isLoading)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_subcategories.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? 'Service Types' : 'أنواع الخدمة',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _subcategories.map((subcatKey) {
                                    final isSelected = subcatKey == _selectedSubcategory;
                                    return FilterChip(
                                      // Display label is locale-aware; internal key is always English
                                      label: Text(_subcategoryLabel(subcatKey, isEn)),
                                      selected: isSelected,
                                      onSelected: (_) {
                                        // Store the English key as the selected value
                                        setState(() => _selectedSubcategory = subcatKey);
                                      },
                                      backgroundColor: Colors.grey.shade100,
                                      selectedColor: syanatBlue.withOpacity(0.3),
                                      side: BorderSide(
                                        color: isSelected ? syanatBlue : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          // Available services
                          Row(
                            children: [
                              Icon(Icons.build, color: syanatBlue, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEn ? 'Available Services' : 'الخدمات المتاحة',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      isEn
                                          ? 'Choose a service to find the right technician'
                                          : 'اختر خدمة وجد الفني المناسب',
                                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Services list filtered by subcategory
                          if (_selectedSubcategory != null)
                            ..._getServicesForSubcategory(_selectedSubcategory!).map(
                              (service) {
                                final label = isEn ? service.serviceNameEn : service.serviceNameAr;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: GestureDetector(
                                    onTap: _sheetOpen
                                        ? null
                                        : () => _openServiceTechnicians(service),
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
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  label,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (service.price != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text(
                                                      '${isEn ? 'Price: ' : 'السعر: '}${service.price?.toStringAsFixed(2)} EGP',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.green,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                            )
                          else
                            Center(
                              child: Text(
                                isEn ? 'No services available' : 'لا توجد خدمات متاحة',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                        ],
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                    
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade900),
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _OrderRequestSheet — Customer creates a managed order request
// ═════════════════════════════════════════════════════════════════════════════

class _OrderRequestSheet extends StatefulWidget {
  final String uid;
  final String customerName;
  final String serviceKey;
  final String serviceCategory;
  final String subservice;
  final List<Map<String, dynamic>> savedLocations;
  final String initialPhone;
  final bool isEn;
  final bool isInspect;

  const _OrderRequestSheet({
    required this.uid,
    required this.customerName,
    required this.serviceKey,
    required this.serviceCategory,
    required this.subservice,
    required this.savedLocations,
    required this.initialPhone,
    required this.isEn,
    this.isInspect = false,
  });

  @override
  State<_OrderRequestSheet> createState() => _OrderRequestSheetState();
}

class _OrderRequestSheetState extends State<_OrderRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newLocLabelCtrl = TextEditingController();
  final _newLocStreetCtrl = TextEditingController();
  final _newLocCityCtrl = TextEditingController();
  final _newLocBuildingCtrl = TextEditingController();
  final _newLocNotesCtrl = TextEditingController();
  LatLng? _newLocPinned;
  bool _addingLocation = false;

  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic>? _selectedLocation;
  // Inspect orders are always 'scheduled' (description + scheduledTime). For
  // normal orders the toggle defaults to 'urgent' and lets the customer
  // switch to 'scheduled'.
  String _urgencyType = 'urgent';
  DateTime? _scheduledTime;
  bool _submitting = false;
  bool _submitted = false; // duplicate-submit guard
  String? _inlineError;
  String? _locationError;
  String? _scheduleError;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.savedLocations);
    _phoneController.text = normalizeEgyptianLocal(widget.initialPhone);
    if (_locations.isNotEmpty) _selectedLocation = _locations.first;
    if (widget.isInspect) {
      // Inspect orders ship as scheduled — pin the urgency immediately so the
      // submit branch validates against scheduledTime instead of urgentNow.
      _urgencyType = 'scheduled';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _phoneController.dispose();
    _newLocLabelCtrl.dispose();
    _newLocStreetCtrl.dispose();
    _newLocCityCtrl.dispose();
    _newLocBuildingCtrl.dispose();
    _newLocNotesCtrl.dispose();
    super.dispose();
  }

  String _t(String en, String ar) => widget.isEn ? en : ar;

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

  /// Converts an exception into a user-visible message. Each distinct failure
  /// mode gets its own, specific message — never mash unrelated causes into
  /// one banner.
  String _friendlyErrorMessage(Object error) {
    if (kDebugMode) {
      debugPrint('[_submit] mapping error: runtimeType=${error.runtimeType} '
          'value=$error');
    }
    if (error is OrderCooldownException) {
      return _t(
        'Please wait ${error.remainingSeconds} seconds before placing another order.',
        'يرجى الانتظار ${error.remainingSeconds} ثانية قبل تقديم طلب آخر.',
      );
    }
    if (error is StoredPhoneInvalidException) {
      return _t(
        'Your profile phone number is not in a valid Egyptian format. Please update it in Account Settings and try again.',
        'رقم الهاتف في ملفك الشخصي ليس بصيغة صحيحة. يرجى تحديثه من إعدادات الحساب ثم المحاولة مرة أخرى.',
      );
    }
    if (error is MissingUserProfileException) {
      return _t(
        'We could not find your account profile. Please sign out and sign in again.',
        'تعذر العثور على ملفك الشخصي. يرجى تسجيل الخروج ثم تسجيل الدخول مرة أخرى.',
      );
    }
    if (error is TimeoutException) {
      return _t(
        'The server took too long to respond. Please check your connection and try again.',
        'استغرق الخادم وقتاً طويلاً. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
      );
    }
    if (error is FirebaseAuthException) {
      return _t(
        'Your session has expired. Please sign in again.',
        'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.',
      );
    }
    if (error is FirebaseException) {
      final String code = error.code;
      if (code == 'unauthenticated' || code == 'permission-denied' &&
          (error.message ?? '').toLowerCase().contains('unauthenticated')) {
        return _t(
          'Your session has expired. Please sign in again.',
          'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.',
        );
      }
      if (code == 'permission-denied') {
        // Pre-flight validation catches the common user-actionable causes
        // (cooldown, stored-phone-invalid, missing user doc). Anything that
        // reaches this branch is a server-configuration problem the customer
        // has no way to fix — so we never leak the raw "Missing or
        // insufficient permissions" string. The full error is logged for
        // debugging; the user sees an actionable support prompt.
        if (kDebugMode) {
          debugPrint(
              '[_submit] permission-denied leaked to UI (bug): ${error.message}');
        }
        return _t(
          "We couldn't place your order right now. Please try again in a moment, or contact support if the issue continues.",
          'تعذر تقديم طلبك في الوقت الحالي. يرجى المحاولة بعد قليل أو التواصل مع الدعم إذا استمر الخطأ.',
        );
      }
      if (code == 'unavailable' || code == 'deadline-exceeded') {
        return _t(
          'Network problem. Please check your connection and try again.',
          'مشكلة في الاتصال. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
        );
      }
      final String detail = (error.message ?? '').trim();
      if (detail.isNotEmpty) {
        return _t('Submit failed: $detail', 'فشل الإرسال: $detail');
      }
      return _t(
        'Submit failed ($code).',
        'فشل الإرسال ($code).',
      );
    }
    if (error is ArgumentError) {
      final String msg = (error.message ?? '').toString();
      return msg.isNotEmpty
          ? msg
          : _t('Invalid request data.', 'بيانات الطلب غير صالحة.');
    }
    return _t(
      'Something went wrong. Please try again.',
      'حدث خطأ. يرجى المحاولة مرة أخرى.',
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

  Future<void> _pickScheduledTime() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledTime = DateTime(
          picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _addNewLocation() async {
    // Re-entrancy guard: parent-state `_newLocPinned` would be clobbered if
    // a rapid double-tap opened the dialog twice. The check + flag pattern
    // is sufficient because all entry points run on the same UI isolate.
    if (_addingLocation) return;
    _addingLocation = true;
    try {
      await _addNewLocationInner();
    } finally {
      _addingLocation = false;
    }
  }

  Future<void> _addNewLocationInner() async {
    _newLocLabelCtrl.clear();
    _newLocStreetCtrl.clear();
    _newLocCityCtrl.clear();
    _newLocBuildingCtrl.clear();
    _newLocNotesCtrl.clear();
    _newLocPinned = null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: widget.isEn ? TextDirection.ltr : TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(_t('Add Location', '\u0625\u0636\u0627\u0641\u0629 \u0645\u0648\u0642\u0639')),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PinOnMapTile(
                  isEn: widget.isEn,
                  pinned: _newLocPinned,
                  compact: true,
                  onTap: () async {
                    final result = await Navigator.of(ctx).push<LatLng>(
                      MaterialPageRoute(
                        builder: (_) =>
                            MapPickerScreen(initial: _newLocPinned),
                      ),
                    );
                    if (result == null) return;
                    setDialogState(() => _newLocPinned = result);
                  },
                ),
                const SizedBox(height: 12),
                _locationFieldCard(
                  icon: Icons.place_outlined,
                  label: _t('Label (e.g. Home)', '\u0627\u0644\u062a\u0633\u0645\u064a\u0629 (\u0645\u062b\u0627\u0644: \u0627\u0644\u0645\u0646\u0632\u0644)'),
                  controller: _newLocLabelCtrl,
                ),
                const SizedBox(height: 12),
                _locationFieldCard(
                  icon: Icons.signpost,
                  label: _t('Street', 'الشارع'),
                  controller: _newLocStreetCtrl,
                ),
                const SizedBox(height: 12),
                _locationFieldCard(
                  icon: Icons.location_city,
                  label: _t('City', 'المدينة'),
                  controller: _newLocCityCtrl,
                ),
                const SizedBox(height: 12),
                _locationFieldCard(
                  icon: Icons.apartment,
                  label: _t('Building', 'المبنى'),
                  controller: _newLocBuildingCtrl,
                ),
                const SizedBox(height: 12),
                _locationFieldCard(
                  icon: Icons.notes,
                  label: _t('Additional notes', 'ملاحظات إضافية'),
                  controller: _newLocNotesCtrl,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('Cancel', '\u0625\u0644\u063a\u0627\u0621')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: syanatBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(_t('Save', '\u062d\u0641\u0638')),
            ),
          ],
        ),
        ),
      ),
    );

    if (!mounted || confirmed != true) return;
    final label = _newLocLabelCtrl.text.trim();
    final street = _newLocStreetCtrl.text.trim();
    final city = _newLocCityCtrl.text.trim();
    final building = _newLocBuildingCtrl.text.trim();
    final notes = _newLocNotesCtrl.text.trim();
    if (label.isEmpty || street.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Please enter location name, street, and city.',
              '\u064a\u0631\u062c\u0649 \u0625\u062f\u062e\u0627\u0644 \u0627\u0633\u0645 \u0627\u0644\u0645\u0648\u0642\u0639 \u0648\u0627\u0644\u0634\u0627\u0631\u0639 \u0648\u0627\u0644\u0645\u062f\u064a\u0646\u0629.',
            ),
          ),
        ),
      );
      return;
    }
    if (_newLocPinned == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            'Please pin the exact spot on the map.',
            'يرجى تحديد الموقع بدقة على الخريطة.',
          )),
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

    try {
      await FirebaseService.addSavedLocation(widget.uid, {
        'label': label,
        'street': street,
        'city': city,
        'building': building,
        'notes': notes,
        'address': address,
        'lat': _newLocPinned!.latitude,
        'lng': _newLocPinned!.longitude,
      });
      final updated = await FirebaseService.getSavedLocations(widget.uid);
      if (!mounted) return;
      setState(() {
        _locations = updated;
        if (_locations.isNotEmpty) _selectedLocation = _locations.first;
      });
    } catch (e) {
      debugPrint('Add location error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_t('Could not save location. Please try again.', 'تعذر حفظ الموقع. يرجى المحاولة مرة أخرى.'))));
    }
  }

  Future<void> _submit() async {
    if (_submitted || _submitting) return; // duplicate-submit guard

    final String? locationError = _selectedLocation == null
        ? _t('Please select a location', 'اختر موقعاً أولاً')
        : null;
    // Inspect orders pin `_urgencyType = 'scheduled'` in initState, so this
    // single check covers both the normal scheduled flow and the inspect
    // flow. Messaging is inspect-aware to match the surrounding copy.
    final String? scheduleError =
        (_urgencyType == 'scheduled' && _scheduledTime == null)
            ? (widget.isInspect
                ? _t('Please pick a date and time for the inspection',
                    'الرجاء اختيار تاريخ ووقت للفحص')
                : _t('Please pick a scheduled time', 'اختر الوقت المناسب'))
            : null;

    final bool formValid = _formKey.currentState?.validate() ?? false;

    if (!formValid || locationError != null || scheduleError != null) {
      setState(() {
        _autovalidate = AutovalidateMode.onUserInteraction;
        _locationError = locationError;
        _scheduleError = scheduleError;
      });
      return;
    }

    setState(() {
      _locationError = null;
      _scheduleError = null;
    });

    final description = _descController.text.trim();
    final String phoneRaw = _phoneController.text.trim();
    final String phoneE164 = egyptianToE164(phoneRaw);
    if (kDebugMode) {
      debugPrint('[_submit] raw phone input="$phoneRaw" '
          '-> normalized E.164="$phoneE164"');
    }

    setState(() {
      _submitting = true;
      _submitted = true;
      _inlineError = null;
    });

    try {
      final locationLabel =
          _selectedLocation!['label'] as String? ?? '';
      final locationAddress =
          _selectedLocation!['address'] as String? ?? '';
      final double? locationLat =
          (_selectedLocation!['lat'] as num?)?.toDouble();
      final double? locationLng =
          (_selectedLocation!['lng'] as num?)?.toDouble();

      final jobId = await FirebaseService.createOrderRequest(
        customerId: widget.uid,
        customerName: widget.customerName,
        serviceKey: widget.serviceKey,
        serviceCategory: widget.serviceCategory,
        subservice: widget.subservice,
        description: description,
        phoneNumber: phoneE164,
        locationLabel: locationLabel,
        locationAddress: locationAddress,
        locationLat: locationLat,
        locationLng: locationLng,
        // Inspect orders always ship scheduled (urgencyType: 'scheduled')
        // with a non-null scheduledTime and the 200 EGP placeholder. The
        // technician's receipt grandTotal becomes the actual amount due
        // — same flow as normal orders.
        urgencyType: widget.isInspect ? 'scheduled' : _urgencyType,
        scheduledTime: _scheduledTime,
        price: widget.isInspect ? 200.0 : 0.0,
      ).timeout(const Duration(seconds: 15));

      // Fire-and-forget: notify available technicians (never blocks submit).
      // `customerId` (Spec W3) closes the privacy gap H-1 — it links each
      // fanned-out notification to the customer who placed the order so
      // deleteAccount() can scrub them. Without it, customerName +
      // locationAddress would persist on technician notifications after
      // the customer deletes their account.
      FirebaseService.notifyAvailableTechnicians(
        jobId: jobId,
        serviceKey: widget.serviceKey,
        serviceCategory: widget.serviceCategory,
        customerId: widget.uid,
        customerName: widget.customerName,
        locationAddress: locationAddress,
        urgencyType: widget.isInspect ? 'scheduled' : _urgencyType,
      ).catchError((_) {});

      if (!mounted) return;
      Navigator.pop(
        context,
        widget.isInspect
            ? _t(
                'Inspection requested! We will assign a technician shortly.',
                'تم طلب الفحص! سنقوم بتعيين فني قريباً.',
              )
            : _t(
                'Request submitted! We will assign a technician shortly.',
                'تم إرسال الطلب! سنقوم بتعيين فني قريباً.',
              ),
      );



    } catch (e, st) {
      debugPrint('Order submit failed: $e\n$st');
      if (mounted) {
        setState(() {
          _submitted = false;
          _inlineError = _friendlyErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      shouldCloseOnMinExtent: true,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isInspect
                            ? _t('Request Inspection', 'طلب فحص')
                            : _t('Request Service', 'طلب خدمة'),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.isInspect
                            ? _t(
                                'Describe the problem · 200 EGP placeholder',
                                'اوصف المشكلة · ٢٠٠ جنيه مبدئي',
                              )
                            : widget.serviceCategory +
                                (widget.subservice.isNotEmpty
                                    ? ' · ${widget.subservice}'
                                    : ''),
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _t('Close', 'إغلاق'),
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: _submitting
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).maybePop();
                        },
                ),
              ],
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Saved Locations ────────────────────────────────────────────
            _sectionLabel(Icons.location_on,
                _t('Service Location', 'موقع الخدمة')),
            const SizedBox(height: 8),
            if (_locations.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t('No saved locations. Add one below.',
                            'لا توجد مواقع محفوظة. أضف موقعاً أدناه.'),
                        style:
                            const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_locations.map((loc) {
                final locId = loc['id'] as String? ?? '';
                final label = loc['label'] as String? ?? '';
                final address = loc['address'] as String? ?? '';
                final isSelected =
                    _selectedLocation?['id'] == locId;

                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedLocation = loc;
                    _locationError = null;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? syanatBlue.withOpacity(0.07)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? syanatBlue
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? syanatBlue
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (label.isNotEmpty)
                                Text(label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              Text(address,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList()),
            TextButton.icon(
              onPressed: _addNewLocation,
              icon: const Icon(Icons.add_location_alt, color: syanatBlue),
              label: Text(_t('Add New Location', 'إضافة موقع جديد'),
                  style: const TextStyle(color: syanatBlue)),
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  _locationError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────────────────────
            _sectionLabel(
                Icons.description,
                widget.isInspect
                    ? _t('Describe the Problem', 'اوصف المشكلة')
                    : _t('Describe Your Request', 'اوصف طلبك')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              // Inspect orders are description-driven, so we surface a
              // taller field (4 lines) and a 500-char cap matching the
              // server-side validator in `createOrderRequest`. Normal orders
              // keep the original 3-line / 300-char shape.
              minLines: widget.isInspect ? 4 : 3,
              maxLines: widget.isInspect ? 6 : 3,
              maxLength: widget.isInspect ? 500 : 300,
              validator: (String? v) {
                if ((v ?? '').trim().isEmpty) {
                  return widget.isInspect
                      ? _t('Please describe the problem',
                          'يرجى وصف المشكلة')
                      : _t('Please describe your request', 'يرجى وصف طلبك');
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: widget.isInspect
                    ? _t(
                        'Describe the problem you need inspected',
                        'صف المشكلة التي تحتاج فحصها',
                      )
                    : _t(
                        'What needs to be fixed / installed / serviced?',
                        'ما الذي يحتاج إصلاح / تركيب / صيانة؟'),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Phone ──────────────────────────────────────────────────────
            _sectionLabel(Icons.phone, _t('Phone Number', 'رقم الهاتف')),
            const SizedBox(height: 8),
            EgyptianPhoneField(
              controller: _phoneController,
              isEn: widget.isEn,
            ),
            const SizedBox(height: 16),

            // ── Timing (always scheduled for inspect; urgent/scheduled
            //   toggle for normal orders) ─────────────────────────────────
            if (widget.isInspect) ...[
              _sectionLabel(Icons.schedule,
                  _t('Inspection Time', 'موعد الفحص')),
              const SizedBox(height: 8),
              _scheduledTimePickerCard(),
              if (_scheduleError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(
                    _scheduleError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ),
            ] else ...[
              _sectionLabel(Icons.schedule, _t('Timing', 'الوقت')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _urgencyType = 'urgent'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _urgencyType == 'urgent'
                              ? syanatBlue
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _urgencyType == 'urgent'
                                ? syanatBlue
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.flash_on,
                                color: _urgencyType == 'urgent'
                                    ? Colors.white
                                    : Colors.orange,
                                size: 22),
                            const SizedBox(height: 4),
                            Text(
                              _t('Now / Urgent', 'الآن / عاجل'),
                              style: TextStyle(
                                color: _urgencyType == 'urgent'
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _urgencyType = 'scheduled');
                        await _pickScheduledTime();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _urgencyType == 'scheduled'
                              ? syanatBlue
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _urgencyType == 'scheduled'
                                ? syanatBlue
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.calendar_today,
                                color: _urgencyType == 'scheduled'
                                    ? Colors.white
                                    : Colors.blue,
                                size: 22),
                            const SizedBox(height: 4),
                            Text(
                              _t('Schedule', 'جدولة'),
                              style: TextStyle(
                                color: _urgencyType == 'scheduled'
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_urgencyType == 'scheduled') ...[
                const SizedBox(height: 10),
                _scheduledTimePickerCard(),
                if (_scheduleError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(
                      _scheduleError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12),
                    ),
                  ),
              ],
            ],
            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: syanatBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(
                        widget.isInspect
                            ? _t('Confirm Inspection', 'تأكيد الفحص')
                            : _t('Submit Request', 'إرسال الطلب'),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tap-target card that opens the date+time picker. Shared between the
  /// inspect-only timing block (always visible) and the normal-order
  /// scheduled branch (visible only when `_urgencyType == 'scheduled'`).
  /// Reads/writes the same `_scheduledTime` state for both flows so the
  /// existing submit validator covers them uniformly.
  Widget _scheduledTimePickerCard() {
    return GestureDetector(
      onTap: () async {
        await _pickScheduledTime();
        if (mounted && _scheduledTime != null) {
          setState(() => _scheduleError = null);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: syanatBlue.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: syanatBlue.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: syanatBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _scheduledTime == null
                    ? _t('Tap to pick date & time', 'اضغط لاختيار الموعد')
                    : '${_scheduledTime!.day}/${_scheduledTime!.month}/${_scheduledTime!.year}  '
                        '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color:
                      _scheduledTime == null ? Colors.grey : syanatBlue,
                  fontWeight: _scheduledTime != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.edit, color: syanatBlue, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: syanatBlue),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

