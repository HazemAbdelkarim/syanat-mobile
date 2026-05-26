import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'firebase_service.dart';
import 'widgets/map_picker_screen.dart';
import 'widgets/pin_on_map_tile.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _locations = [];
  String? _activeLocationId;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await FirebaseService.auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (!mounted) return;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    _uid = user.uid;
    try {
      final profile = await FirebaseService.getProfile(user.uid);
      _activeLocationId = (profile?['activeLocationId'] as String?) ?? '';

      final locs = await FirebaseService.getSavedLocations(user.uid);
      setState(() {
        _locations = locs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading locations: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _addLocation() async {
    if (_uid == null) return;

    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddLocationSheet(),
    );
    if (!mounted || result == null) return;

    setState(() => _loading = true);
    try {
      final id = await FirebaseService.addSavedLocation(_uid!, {
        'label': result['label'],
        'street': result['street'],
        'city': result['city'],
        'building': result['building'],
        'notes': result['notes'],
        'address': result['address'],
        if (result['lat'] != null) 'lat': result['lat'],
        if (result['lng'] != null) 'lng': result['lng'],
      });

      if (_locations.isEmpty) {
        await FirebaseService.setActiveLocation(_uid!, id);
        _activeLocationId = id;
      }
      await _load();
    } catch (e) {
      debugPrint('Add location error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Could not save location. Please try again.' : 'تعذر حفظ الموقع. يرجى المحاولة مرة أخرى.')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _addPinToLegacy(String locationId, LatLng? initial) async {
    if (_uid == null) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initial: initial),
      ),
    );
    if (!mounted || picked == null) return;

    // Warn the user that the new pin won't reach orders that have already
    // been dispatched. By design (see project_maps_feature memory):
    // coordinates on jobs/* are write-once at create time.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        child: AlertDialog(
          title: Text(isEn ? 'Save new pin?' : 'حفظ الموقع الجديد؟'),
          content: Text(isEn
              ? 'This will only affect future orders. Orders already placed will keep the old location.'
              : 'سيؤثر هذا على الطلبات المستقبلية فقط. الطلبات التي تم إرسالها بالفعل ستحتفظ بالموقع القديم.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isEn ? 'Cancel' : 'إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _syanatBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEn ? 'Save pin' : 'حفظ الموقع'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirm != true) return;

    setState(() => _loading = true);
    try {
      await FirebaseService.updateSavedLocationPin(
          _uid!, locationId, picked.latitude, picked.longitude);
      await _load();
    } catch (e) {
      debugPrint('Update pin error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEn
            ? 'Could not save pin. Please try again.'
            : 'تعذر حفظ الموقع. يرجى المحاولة مرة أخرى.'),
      ));
      setState(() => _loading = false);
    }
  }

  Future<void> _setActive(String id) async {
    if (_uid == null) return;
    setState(() => _activeLocationId = id);
    try {
      await FirebaseService.setActiveLocation(_uid!, id);
    } catch (e) {
      debugPrint('Error setting active location: $e');
    }
  }

  Future<void> _delete(String id) async {
    if (_uid == null) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Delete Location' : 'حذف الموقع'),
        content: Text(
          isEn
              ? 'Are you sure you want to delete this location?'
              : 'هل أنت متأكد من حذف هذا الموقع؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEn ? 'Cancel' : 'إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isEn ? 'Delete' : 'حذف',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await FirebaseService.deleteSavedLocation(_uid!, id);
      if (_activeLocationId == id && _locations.length > 1) {
        final remaining = _locations.where((l) => l['id'] != id).toList();
        if (remaining.isNotEmpty) {
          await FirebaseService.setActiveLocation(_uid!, remaining.first['id']);
          _activeLocationId = remaining.first['id'];
        }
      }
      await _load();
    } catch (e) {
      debugPrint('Delete location error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Could not delete location. Please try again.' : 'تعذر حذف الموقع. يرجى المحاولة مرة أخرى.')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String t(String en, String ar) => isEn ? en : ar;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          elevation: 0,
          title: Text(
            t('Saved Locations', 'المواقع المحفوظة'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _syanatBlue,
          onPressed: _addLocation,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _syanatBlue))
            : _locations.isEmpty
                ? _buildEmptyState(t)
                : _buildList(t),
      ),
    );
  }

  Widget _buildEmptyState(String Function(String, String) t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              t('No saved locations', 'لا توجد مواقع محفوظة'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('Tap the + button to add your first location.', 'اضغط على زر + لإضافة أول موقع لك.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String Function(String, String) t) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _locations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final loc = _locations[i];
        final id = loc['id'] as String;
        final label = (loc['label'] as String?) ?? '';
        final address = (loc['address'] as String?) ?? '';
        final double? lat = (loc['lat'] as num?)?.toDouble();
        final double? lng = (loc['lng'] as num?)?.toDouble();
        final bool hasPin = lat != null && lng != null;
        final isActive = id == _activeLocationId;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? _syanatBlue : Colors.grey.shade200,
              width: isActive ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? _syanatBlue.withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_on,
                color: isActive ? _syanatBlue : Colors.grey,
                size: 24,
              ),
            ),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? _syanatBlue : Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.isNotEmpty)
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  if (!hasPin) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _addPinToLegacy(id, null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4D6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5B100)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: Color(0xFFB07A00)),
                            const SizedBox(width: 4),
                            Text(
                              t('Add precise pin', 'إضافة موقع دقيق'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB07A00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isActive)
                  TextButton(
                    onPressed: () => _setActive(id),
                    child: Text(
                      t('Select', 'اختيار'),
                      style: const TextStyle(color: _syanatBlue, fontSize: 12),
                    ),
                  ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _syanatBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t('Active', 'نشط'),
                      style: const TextStyle(
                        color: _syanatBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                  onPressed: () => _delete(id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddLocationSheet extends StatefulWidget {
  const _AddLocationSheet();

  @override
  State<_AddLocationSheet> createState() => _AddLocationSheetState();
}

class _AddLocationSheetState extends State<_AddLocationSheet> {
  final _labelCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  LatLng? _pinned;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _buildingCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initial: _pinned),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _pinned = result);
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

  Widget _fieldCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    int? maxLength,
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
            child: Icon(icon, color: _syanatBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              decoration: InputDecoration(
                counterText: '',
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

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        shouldCloseOnMinExtent: true,
        builder: (ctx, scrollController) {
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
                MediaQuery.of(context).viewInsets.bottom + 24,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEn ? 'Add Location' : 'إضافة موقع',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: isEn ? 'Close' : 'إغلاق',
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PinOnMapTile(
                  isEn: isEn,
                  pinned: _pinned,
                  onTap: _pickOnMap,
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  icon: Icons.place_outlined,
                  label: isEn ? 'Label (e.g. Home, Office)' : 'الاسم (مثال: المنزل، المكتب)',
                  controller: _labelCtrl,
                  maxLength: 50,
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  icon: Icons.signpost,
                  label: isEn ? 'Street' : 'شارع',
                  controller: _streetCtrl,
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  icon: Icons.location_city,
                  label: isEn ? 'City' : 'مدينة',
                  controller: _cityCtrl,
                  maxLength: 50,
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  icon: Icons.apartment,
                  label: isEn ? 'Building' : 'مبنى',
                  controller: _buildingCtrl,
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                _fieldCard(
                  icon: Icons.notes,
                  label: isEn ? 'Additional notes' : 'ملاحظات إضافية',
                  controller: _notesCtrl,
                  maxLength: 200,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isEn ? 'Cancel' : 'إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final label = _labelCtrl.text.trim();
                        final street = _streetCtrl.text.trim();
                        final city = _cityCtrl.text.trim();
                        final building = _buildingCtrl.text.trim();
                        final notes = _notesCtrl.text.trim();

                        if (label.isEmpty || street.isEmpty || city.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEn
                                    ? 'Please enter location name, street, and city.'
                                    : 'يرجى إدخال اسم الموقع والشارع والمدينة.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (_pinned == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEn
                                    ? 'Please pin the exact spot on the map.'
                                    : 'يرجى تحديد الموقع بدقة على الخريطة.',
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

                        Navigator.pop(context, <String, dynamic>{
                          'label': label,
                          'street': street,
                          'city': city,
                          'building': building,
                          'notes': notes,
                          'address': address,
                          'lat': _pinned!.latitude,
                          'lng': _pinned!.longitude,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _syanatBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isEn ? 'Add' : 'إضافة'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

