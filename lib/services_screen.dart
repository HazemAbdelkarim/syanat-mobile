import 'package:flutter/material.dart';
import 'models/service.dart';
import 'repositories/service_repository.dart';

const Color syanatBlue = Color(0xFF3C21C8);
const Color syanatGrey = Color(0xFFF5F5F5);

class ServicesScreen extends StatefulWidget {
  final Function(Locale) setLocale;

  const ServicesScreen({required this.setLocale, super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late ServiceRepository _serviceRepository;
  String? _selectedCategory;
  String? _selectedSubcategory;
  List<String> _categories = [];
  List<String> _subcategories = [];
  List<Service> _services = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _serviceRepository = ServiceRepository();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _serviceRepository.getCategories();
      setState(() {
        _categories = categories;
        _selectedCategory = categories.isNotEmpty ? categories.first : null;
        _isLoading = false;
      });
      if (_selectedCategory != null) {
        _loadSubcategories(_selectedCategory!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading categories. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubcategories(String category) async {
    try {
      final subcats = await _serviceRepository.getSubcategories(category);
      setState(() {
        _subcategories = subcats;
        _selectedSubcategory = subcats.isNotEmpty ? subcats.first : null;
      });
      if (_selectedSubcategory != null) {
        _loadServices(category, _selectedSubcategory!);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error loading subcategories. Please try again.');
    }
  }

  Future<void> _loadServices(String category, String subcategory) async {
    setState(() => _isLoading = true);
    try {
      final services =
          await _serviceRepository.getServicesBySubcategory(category, subcategory);
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading services. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: syanatBlue,
          title: Text(
            isRTL ? 'الخدمات' : 'Services',
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          centerTitle: true,
        ),
        body: _isLoading && _categories.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        color: Colors.red.shade100,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),

                    // Category Selector
                    if (_categories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRTL ? 'الفئة' : 'Category',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedCategory,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                      () => _selectedCategory = value);
                                  _loadSubcategories(value);
                                }
                              },
                              items: _categories
                                  .map((cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),

                    // Subcategory Selector
                    if (_subcategories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRTL ? 'الفئة الفرعية' : 'Subcategory',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedSubcategory,
                              onChanged: (value) {
                                if (value != null && _selectedCategory != null) {
                                  setState(
                                      () => _selectedSubcategory = value);
                                  _loadServices(_selectedCategory!, value);
                                }
                              },
                              items: _subcategories
                                  .map((subcat) => DropdownMenuItem(
                                        value: subcat,
                                        child: Text(subcat),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),

                    // Services List
                    if (_isLoading && _services.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )
                    else if (_services.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          isRTL
                              ? 'لا توجد خدمات'
                              : 'No services available',
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return _buildServiceCard(service, isRTL);
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildServiceCard(Service service, bool isRTL) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Service Name (bilingual)
            Text(
              isRTL ? service.serviceNameAr : service.serviceNameEn,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: syanatBlue,
              ),
            ),
            const SizedBox(height: 8),

            // Service Details
            Text(
              '${isRTL ? 'الفئة:' : 'Category:'} ${isRTL ? service.categoryAr : service.categoryEn}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              '${isRTL ? 'الفئة الفرعية:' : 'Subcategory:'} ${isRTL ? service.subcategoryAr : service.subcategoryEn}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),

            // Price (if available)
            if (service.price != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${isRTL ? 'السعر:' : 'Price:'} ${service.price?.toStringAsFixed(2)} EGP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),

            // Service ID for reference
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'ID: ${service.id ?? 'N/A'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
