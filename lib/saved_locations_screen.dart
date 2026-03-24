import 'package:flutter/material.dart';
import 'firebase_service.dart';

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
    final user = FirebaseService.getCurrentUser();
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

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _AddLocationDialog(),
    );
    if (result == null) return;

    setState(() => _loading = true);
    try {
      final id = await FirebaseService.addSavedLocation(_uid!, {
        'label': result['label'],
        'address': result['address'],
      });

      // If this is the first location, make it active automatically.
      if (_locations.isEmpty) {
        await FirebaseService.setActiveLocation(_uid!, id);
        _activeLocationId = id;
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
        content: Text(isEn
            ? 'Are you sure you want to delete this location?'
            : 'هل أنت متأكد من حذف هذا الموقع؟'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
              t('Tap the + button to add your first location.',
                  'اضغط على زر + لإضافة أول موقع لك.'),
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
        final isActive = id == _activeLocationId;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? _syanatBlue : Colors.grey.shade200,
              width: isActive ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x0F000000),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? _syanatBlue.withOpacity(0.1)
                    : Colors.grey.shade100,
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
            subtitle: address.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  )
                : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// Add Location Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AddLocationDialog extends StatefulWidget {
  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  final _labelCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String t(String en, String ar) => isEn ? en : ar;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(t('Add Location', 'إضافة موقع')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelCtrl,
            decoration: InputDecoration(
              labelText: t('Label (e.g. Home, Office)', 'الاسم (مثال: المنزل، المكتب)'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: t('Address', 'العنوان'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancel', 'إلغاء')),
        ),
        ElevatedButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            final address = _addressCtrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(context, {'label': label, 'address': address});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _syanatBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(t('Add', 'إضافة')),
        ),
      ],
    );
  }
}
