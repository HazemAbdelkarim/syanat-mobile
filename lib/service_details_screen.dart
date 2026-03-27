import 'package:flutter/material.dart';
import '../glass_card.dart';
import '../firebase_service.dart';
import 'services_integration.dart';
import 'models/service.dart';
import 'main.dart' show AppLocale;

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

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen>
    with TickerProviderStateMixin {
  late ServiceIntegration _serviceIntegration;
  List<Service> _services = [];
  List<String> _subcategories = [];
  bool _isLoading = true;
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
        _errorMessage = 'Error loading services: $e';
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

  Future<void> _showQuickOrderSheet() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    final results = await Future.wait([
      FirebaseService.getProfile(user.uid),
      FirebaseService.getSavedLocations(user.uid),
    ]);

    if (!mounted) return;

    final profile = results[0] as Map<String, dynamic>?;
    final locations = results[1] as List<Map<String, dynamic>>;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      transitionAnimationController: ctrl,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _OrderRequestSheet(
        uid: user.uid,
        customerName: profile?['username'] as String? ??
            profile?['email'] as String? ?? '',
        serviceKey: widget.serviceKey,
        serviceCategory: isEn ? widget.labelEn : widget.labelAr,
        subservice: '',
        savedLocations: locations,
        initialPhone: profile?['phone'] as String? ?? '',
        isEn: isEn,
        isQuickOrder: true,
      ),
    );
    ctrl.dispose();
  }

  void _openServiceTechnicians(Service service) {
    _showOrderRequestSheet(service);
  }

  Future<void> _showOrderRequestSheet(Service service) async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    // Load profile + saved locations before showing the sheet.
    final results = await Future.wait([
      FirebaseService.getProfile(user.uid),
      FirebaseService.getSavedLocations(user.uid),
    ]);

    if (!mounted) return;

    final profile = results[0] as Map<String, dynamic>?;
    final locations = results[1] as List<Map<String, dynamic>>;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final subservice =
        isEn ? service.serviceNameEn : service.serviceNameAr;

    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      transitionAnimationController: ctrl,
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
    ctrl.dispose();
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
                              onPressed: _showQuickOrderSheet,
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
                                    onTap: () => _openServiceTechnicians(service),
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
  final bool isQuickOrder;

  const _OrderRequestSheet({
    required this.uid,
    required this.customerName,
    required this.serviceKey,
    required this.serviceCategory,
    required this.subservice,
    required this.savedLocations,
    required this.initialPhone,
    required this.isEn,
    this.isQuickOrder = false,
  });

  @override
  State<_OrderRequestSheet> createState() => _OrderRequestSheetState();
}

class _OrderRequestSheetState extends State<_OrderRequestSheet> {
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newLocLabelCtrl = TextEditingController();
  final _newLocAddressCtrl = TextEditingController();

  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic>? _selectedLocation;
  String _urgencyType = 'urgent'; // 'urgent' | 'scheduled'
  DateTime? _scheduledTime;
  bool _submitting = false;
  bool _submitted = false; // duplicate-submit guard

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.savedLocations);
    _phoneController.text = widget.initialPhone;
    if (_locations.isNotEmpty) _selectedLocation = _locations.first;
    if (widget.isQuickOrder) {
      _descController.text = widget.isEn
          ? 'Quick inspection request'
          : 'طلب كشف سريع';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _phoneController.dispose();
    _newLocLabelCtrl.dispose();
    _newLocAddressCtrl.dispose();
    super.dispose();
  }

  String _t(String en, String ar) => widget.isEn ? en : ar;

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
    _newLocLabelCtrl.clear();
    _newLocAddressCtrl.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Add Location', 'إضافة موقع')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newLocLabelCtrl,
              decoration: InputDecoration(
                labelText: _t('Label (e.g. Home)', 'التسمية (مثال: المنزل)'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newLocAddressCtrl,
              decoration: InputDecoration(
                labelText: _t('Full Address', 'العنوان الكامل'),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('Cancel', 'إلغاء'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: syanatBlue, foregroundColor: Colors.white),
            child: Text(_t('Save', 'حفظ')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final label = _newLocLabelCtrl.text.trim();
    final address = _newLocAddressCtrl.text.trim();
    if (address.isEmpty) return;

    try {
      await FirebaseService.addSavedLocation(widget.uid, {
        'label': label,
        'address': address,
      });
      // Refresh locations list
      final updated = await FirebaseService.getSavedLocations(widget.uid);
      if (mounted) {
        setState(() {
          _locations = updated;
          // Select the newly added location (first in DESC order)
          if (_locations.isNotEmpty) _selectedLocation = _locations.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (_submitted || _submitting) return; // duplicate-submit guard

    final description = _descController.text.trim();
    final phone = _phoneController.text.trim();

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('Please select a location', 'اختر موقعاً أولاً'))));
      return;
    }
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('Please describe your request',
              'يرجى وصف طلبك أولاً'))));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(_t('Please enter a phone number', 'أدخل رقم هاتفك أولاً'))));
      return;
    }
    if (_urgencyType == 'scheduled' && _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _t('Please pick a scheduled time', 'اختر الوقت المناسب'))));
      return;
    }

    setState(() { _submitting = true; _submitted = true; });

    try {
      final locationLabel =
          _selectedLocation!['label'] as String? ?? '';
      final locationAddress =
          _selectedLocation!['address'] as String? ?? '';

      final jobId = await FirebaseService.createOrderRequest(
        customerId: widget.uid,
        customerName: widget.customerName,
        serviceKey: widget.serviceKey,
        serviceCategory: widget.serviceCategory,
        subservice: widget.subservice,
        description: description,
        phoneNumber: phone,
        locationLabel: locationLabel,
        locationAddress: locationAddress,
        urgencyType: widget.isQuickOrder ? 'urgent' : _urgencyType,
        scheduledTime: widget.isQuickOrder ? null : _scheduledTime,
        price: widget.isQuickOrder ? 200.0 : 0.0,
      );

      // Fire-and-forget: notify available technicians (never blocks submit).
      FirebaseService.notifyAvailableTechnicians(
        jobId: jobId,
        serviceKey: widget.serviceKey,
        serviceCategory: widget.serviceCategory,
        customerName: widget.customerName,
        locationAddress: locationAddress,
        urgencyType: _urgencyType,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isQuickOrder
            ? _t('Quick order confirmed! A technician will be dispatched shortly.',
                'تم تأكيد الطلب السريع! سيتم إرسال فني قريباً.')
            : _t('Request submitted! We will assign a technician shortly.',
                'تم إرسال الطلب! سنقوم بتعيين فني قريباً.')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (mounted) {
        setState(() { _submitting = false; _submitted = false; });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            Text(
              widget.isQuickOrder
                  ? _t('Quick Order — 200 EGP', 'طلب سريع — ٢٠٠ جنيه')
                  : _t('Request Service', 'طلب خدمة'),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.serviceCategory +
                  (widget.subservice.isNotEmpty
                      ? ' · ${widget.subservice}'
                      : ''),
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600),
            ),
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
                  onTap: () =>
                      setState(() => _selectedLocation = loc),
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
            const SizedBox(height: 16),

            // ── Description ────────────────────────────────────────────────
            _sectionLabel(Icons.description,
                _t('Describe Your Request', 'اوصف طلبك')),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: _t(
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
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: _t('01XXXXXXXXX', '01XXXXXXXXX'),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Timing (hidden for quick order — always urgent) ───────────
            if (!widget.isQuickOrder) ...[
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
                GestureDetector(
                  onTap: _pickScheduledTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: syanatBlue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: syanatBlue.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: syanatBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _scheduledTime == null
                                ? _t('Tap to pick date & time',
                                    'اضغط لاختيار الموعد')
                                : '${_scheduledTime!.day}/${_scheduledTime!.month}/${_scheduledTime!.year}  '
                                    '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: _scheduledTime == null
                                  ? Colors.grey
                                  : syanatBlue,
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
                        widget.isQuickOrder
                            ? _t('Confirm Quick Order', 'تأكيد الطلب السريع')
                            : _t('Submit Request', 'إرسال الطلب'),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
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
