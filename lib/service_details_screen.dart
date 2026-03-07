import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'technicians_list_screen.dart';
import '../firebase_service.dart';
import 'services_integration.dart';
import 'models/service.dart';

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
    setState(() {
      _locale = _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    });
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
          description: 'Quick inspection request',
          price: 200.0,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_locale.languageCode == 'en' ? 'Quick order sent!' : 'الطلب السريع اتبعت!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _openServiceTechnicians(Service service) {
    final isEn = _locale.languageCode == 'en';
    final label = isEn ? service.serviceNameEn : service.serviceNameAr;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TechniciansListScreen(
          serviceKey: widget.serviceKey,
          serviceLabel: label,
          preSelectedDescription: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _locale.languageCode == 'en';

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
