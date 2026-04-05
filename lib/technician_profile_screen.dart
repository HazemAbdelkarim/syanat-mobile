import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_service.dart';
import 'main.dart' show AppLocale;

const Color _blue = Color(0xFF3C21C8);

// ─── Simple file-level in-memory cache ─────────────────────────────────────
// Lives for the lifetime of the app session.  Invalidated on edit-save.
Map<String, dynamic>? _profileCache;
DateTime? _profileCacheTime;
const _cacheTtl = Duration(minutes: 10);

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({super.key});

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  String? _saveError;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  XFile? _pickedPhoto;
  String? _nameErr;
  String? _phoneErr;
  String? _emailErr;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────
  bool get _cacheValid =>
      _profileCache != null &&
      _profileCacheTime != null &&
      DateTime.now().difference(_profileCacheTime!) < _cacheTtl;

  Future<void> _loadProfile({bool force = false}) async {
    if (!force && _cacheValid) {
      if (mounted) {
        setState(() {
          _profile = _profileCache;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);
    try {
      final user = FirebaseService.getCurrentUser();
      if (user == null) return;
      final data = await FirebaseService.getProfile(user.uid);
      if (!mounted) return;
      _profileCache = data;
      _profileCacheTime = DateTime.now();
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Edit helpers ───────────────────────────────────────────────────────────
  void _startEditing() {
    final p = _profile!;
    _nameCtrl.text = (p['username'] as String? ?? '').trim();
    _phoneCtrl.text = (p['phone'] as String? ?? '').trim();
    _emailCtrl.text = (p['email'] as String? ?? '').trim();
    _pickedPhoto = null;
    _nameErr = _phoneErr = _emailErr = _saveError = null;
    setState(() => _editing = true);
  }

  void _cancelEditing() => setState(() {
        _editing = false;
        _pickedPhoto = null;
        _saveError = null;
      });

  bool _validate(bool isEn) {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    String? ne, pe, ee;

    if (name.length < 2) {
      ne = isEn
          ? 'Name must be at least 2 characters.'
          : 'الاسم يجب أن يكون حرفين على الأقل.';
    }
    if (!RegExp(r'^\+201[0125]\d{8}$').hasMatch(phone)) {
      pe = isEn
          ? 'Invalid phone. Format: +201XXXXXXXXX'
          : 'رقم الهاتف غير صحيح. الصيغة: +201XXXXXXXXX';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ee = isEn
          ? 'Enter a valid email address.'
          : 'أدخل بريداً إلكترونياً صحيحاً.';
    }

    setState(() {
      _nameErr = ne;
      _phoneErr = pe;
      _emailErr = ee;
    });
    return ne == null && pe == null && ee == null;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final xf = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xf == null || !mounted) return;
      setState(() => _pickedPhoto = xf);
    } catch (_) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      setState(() => _saveError = isEn
          ? 'Cannot access camera/gallery. Check permissions.'
          : 'تعذّر الوصول إلى الكاميرا/المعرض. تحقق من الأذونات.');
    }
  }

  void _showPhotoPicker(bool isEn) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _blue),
              title: Text(isEn ? 'Camera' : 'الكاميرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _blue),
              title: Text(isEn ? 'Gallery' : 'المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (!_validate(isEn)) return;

    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim().toLowerCase();

      // Upload new photo if chosen; failures are non-blocking.
      String? newPhotoUrl;
      if (_pickedPhoto != null) {
        try {
          newPhotoUrl = await FirebaseService.uploadPhoto(
            _pickedPhoto!,
            folder: 'techProfiles',
          );
        } catch (_) {
          // photo upload failed — continue without updating photoUrl
        }
      }

      await FirebaseService.updateTechnicianProfile(
        uid: user.uid,
        username: name,
        phone: phone,
        email: email,
        photoUrl: newPhotoUrl,
      );

      // Fire email-verification if address changed (non-blocking).
      if (email != (user.email ?? '').toLowerCase()) {
        try {
          await user.verifyBeforeUpdateEmail(email);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEn
                    ? 'Verification sent to $email. Tap the link to confirm.'
                    : 'تم إرسال التحقق إلى $email. انقر الرابط للتأكيد.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (_) {
          // Auth email update failed — Firestore is already updated.
          // Not fatal; the user can retry from settings.
        }
      }

      // Invalidate cache so next view shows fresh data.
      _profileCache = null;
      _profileCacheTime = null;

      await _loadProfile(force: true);
      if (!mounted) return;
      setState(() => _editing = false);
    } catch (e) {
      if (!mounted) return;
      final isEn2 = Localizations.localeOf(context).languageCode == 'en';
      setState(() {
      debugPrint('Profile save error: $e');
        _saveError = isEn2 ? 'Save failed. Please try again.' : 'فشل الحفظ. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String t(String en, String ar) => isEn ? en : ar;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          title: Text(t('My Profile', 'ملفي الشخصي')),
          actions: [
            if (!_loading && _profile != null && !_editing)
              TextButton.icon(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                label: Text(
                  t('Edit', 'تعديل'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            if (_editing)
              TextButton(
                onPressed: _saving ? null : _cancelEditing,
                child: Text(
                  t('Cancel', 'إلغاء'),
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : _profile == null
                ? Center(
                    child: Text(
                      t('Profile not found.', 'الملف الشخصي غير موجود.'),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : _editing
                    ? _buildEditView(isEn, t)
                    : _buildViewMode(isEn, t),
      ),
    );
  }

  // ── View mode ──────────────────────────────────────────────────────────────
  Widget _buildViewMode(bool isEn, String Function(String, String) t) {
    final p = _profile!;
    final name = (p['username'] as String? ?? '').trim();
    final email = (p['email'] as String? ?? '').trim();
    final phone = (p['phone'] as String? ?? '').trim();
    final city = (p['city'] as String? ?? '').trim();
    final service = (p['service'] as String? ?? '').trim();
    final photoUrl = (p['photoUrl'] as String? ?? '').trim();
    final earnings = (p['earnings'] as num?)?.toDouble() ?? 0.0;
    final rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
    final available = p['available'] as bool? ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: _startEditing,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: _blue.withOpacity(0.12),
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 56, color: _blue)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: _blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? t('Technician', 'الفني') : name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          if (service.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                service,
                style: const TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                available ? Icons.circle : Icons.circle_outlined,
                size: 8,
                color: available ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 5),
              Text(
                available
                    ? t('Available', 'متاح')
                    : t('Unavailable', 'غير متاح'),
                style: TextStyle(
                  fontSize: 12,
                  color: available ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // ── Stats ─────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _statCard(
                  t('Earnings', 'الأرباح'),
                  '${earnings.toStringAsFixed(0)} EGP',
                  Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  t('Rating', 'التقييم'),
                  rating > 0 ? '★ ${rating.toStringAsFixed(1)}' : '—',
                  Icons.star_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // ── Info cards ────────────────────────────────────────────────────
          _infoCard(Icons.email_outlined, t('Email', 'البريد الإلكتروني'),
              email.isEmpty ? '—' : email),
          const SizedBox(height: 12),
          _infoCard(Icons.phone_outlined, t('Phone', 'الهاتف'),
              phone.isEmpty ? '—' : phone),
          const SizedBox(height: 12),
          _infoCard(Icons.location_city_outlined, t('City', 'المدينة'),
              city.isEmpty ? '—' : city),
          const SizedBox(height: 28),
          // ── Edit button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                t('Edit Profile', 'تعديل الملف الشخصي'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────
  Widget _buildEditView(bool isEn, String Function(String, String) t) {
    final photoUrl = (_profile!['photoUrl'] as String? ?? '').trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar with tap-to-change
          GestureDetector(
            onTap: () => _showPhotoPicker(isEn),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: _blue.withOpacity(0.12),
                  backgroundImage: _pickedPhoto != null
                      ? FileImage(File(_pickedPhoto!.path)) as ImageProvider
                      : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
                  child: (_pickedPhoto == null && photoUrl.isEmpty)
                      ? const Icon(Icons.person, size: 56, color: _blue)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: _blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 15),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showPhotoPicker(isEn),
            child: Text(
              t('Change Photo', 'تغيير الصورة'),
              style: const TextStyle(color: _blue, fontSize: 13),
            ),
          ),
          if (_saveError != null) ...[
            _errorBox(_saveError!),
            const SizedBox(height: 14),
          ],
          _field(
            ctrl: _nameCtrl,
            icon: Icons.person_outline,
            label: t('Full Name', 'الاسم الكامل'),
            err: _nameErr,
            onChanged: (_) {
              if (_nameErr != null) setState(() => _nameErr = null);
            },
          ),
          const SizedBox(height: 14),
          _field(
            ctrl: _phoneCtrl,
            icon: Icons.phone_outlined,
            label: t('Phone (+201XXXXXXXXX)', 'الهاتف (+201XXXXXXXXX)'),
            type: TextInputType.phone,
            err: _phoneErr,
            onChanged: (_) {
              if (_phoneErr != null) setState(() => _phoneErr = null);
            },
          ),
          const SizedBox(height: 14),
          _field(
            ctrl: _emailCtrl,
            icon: Icons.email_outlined,
            label: t('Email', 'البريد الإلكتروني'),
            type: TextInputType.emailAddress,
            err: _emailErr,
            onChanged: (_) {
              if (_emailErr != null) setState(() => _emailErr = null);
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      t('Save Changes', 'حفظ التغييرات'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────
  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _blue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required IconData icon,
    required String label,
    TextInputType type = TextInputType.text,
    String? err,
    ValueChanged<String>? onChanged,
  }) {
    final hasErr = err != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasErr ? Colors.red.shade400 : Colors.grey.shade300,
              width: 1.5,
            ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  icon,
                  color: hasErr ? Colors.red.shade400 : _blue,
                  size: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: type,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: hasErr ? Colors.red.shade400 : Colors.black54,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasErr) ...[
          const SizedBox(height: 6),
          _errorBox(err),
        ],
      ],
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      width: double.infinity,
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
              msg,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
