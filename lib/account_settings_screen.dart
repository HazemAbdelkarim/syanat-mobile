import 'package:flutter/material.dart';
import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _sex = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      setState(() {
        _error = 'not_logged_in';
        _loading = false;
      });
      return;
    }
    try {
      final data = await FirebaseService.getProfile(user.uid);
      if (data != null) {
        // The DB stores a single 'username' field. Split into first/last for display.
        final fullName = (data['username'] as String?) ?? '';
        final parts = fullName.trim().split(RegExp(r'\s+'));
        _firstNameCtrl.text = parts.isNotEmpty ? parts.first : '';
        _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        _emailCtrl.text = (data['email'] as String?) ?? (user.email ?? '');
        _phoneCtrl.text = (data['phone'] as String?) ?? '';
        _sex = (data['gender'] as String?) ?? '';
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    final phone = _phoneCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final fullName = '$firstName $lastName'.trim();

    if (phone.isNotEmpty) {
      final regex = RegExp(r'^\+201[0125]\d{8}$');
      if (!regex.hasMatch(phone)) {
        final isEn = Localizations.localeOf(context).languageCode == 'en';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn
                ? 'Invalid phone number. Use format: +201XXXXXXXXX'
                : 'رقم الهاتف غير صحيح. استخدم الصيغة: +201XXXXXXXXX'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await FirebaseService.updateProfile(user.uid, {
        'username': fullName,
        'phone': phone,
        'gender': _sex,
      });
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Saved successfully' : 'تم الحفظ بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
            t('Account Settings', 'إعدادات الحساب'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _buildBody(isEn, t),
      ),
    );
  }

  Widget _buildBody(bool isEn, String Function(String, String) t) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _syanatBlue));
    }
    if (_error == 'not_logged_in') {
      return Center(
        child: Text(
          t('Please log in first', 'يرجى تسجيل الدخول أولاً'),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              t('Failed to load profile', 'فشل في تحميل البيانات'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldCard(
            icon: Icons.person_outline,
            label: t('First Name', 'الاسم الأول'),
            controller: _firstNameCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.person_outline,
            label: t('Last Name', 'اسم العائلة'),
            controller: _lastNameCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.email_outlined,
            label: t('Email', 'البريد الإلكتروني'),
            controller: _emailCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.phone_outlined,
            label: t('Phone Number', 'رقم الهاتف'),
            controller: _phoneCtrl,
            readOnly: false,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _sexSelector(isEn),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _syanatBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isEn ? 'Save Changes' : 'حفظ التغييرات',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fieldCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool readOnly,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
              readOnly: readOnly,
              keyboardType: keyboardType,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                suffixIcon: readOnly
                    ? Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400)
                    : Icon(Icons.edit, size: 16, color: _syanatBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sexSelector(bool isEn) {
    String t(String en, String ar) => isEn ? en : ar;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
            child: const Icon(Icons.wc_outlined, color: _syanatBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Sex', 'الجنس'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _sexChip(
                      label: t('Male', 'ذكر'),
                      value: 'male',
                      selected: _sex.toLowerCase() == 'male',
                    ),
                    const SizedBox(width: 10),
                    _sexChip(
                      label: t('Female', 'أنثى'),
                      value: 'female',
                      selected: _sex.toLowerCase() == 'female',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sexChip({
    required String label,
    required String value,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _sex = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _syanatBlue.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _syanatBlue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? _syanatBlue : Colors.black54,
          ),
        ),
      ),
    );
  }
}
