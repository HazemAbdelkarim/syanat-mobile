import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'widgets/egyptian_phone_field.dart';

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
    final user = await FirebaseService.auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (!mounted) return;
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
        _phoneCtrl.text =
            normalizeEgyptianLocal((data['phone'] as String?) ?? '');
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

    final phoneLocal = _phoneCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    String phoneE164 = '';
    if (phoneLocal.isNotEmpty) {
      final String? phoneErr = validateEgyptianLocal(phoneLocal, isEn: isEn);
      if (phoneErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(phoneErr)),
        );
        return;
      }
      phoneE164 = egyptianToE164(phoneLocal);
    }

    setState(() => _saving = true);
    try {
      await FirebaseService.updateProfile(user.uid, {
        'username': fullName,
        'phone': phoneE164,
        'gender': _sex,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Saved successfully' : 'ØªÙ… Ø§Ù„Ø­ÙØ¸ Ø¨Ù†Ø¬Ø§Ø­'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Settings save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Something went wrong. Please try again.' : 'Ø­Ø¯Ø« Ø®Ø·Ø£. ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.')),
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
          backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C4DFF), Color(0xFF6C3CE1), Color(0xFF5228B5)],
                ),
              ),
            ),
          title: Text(
            t('Account Settings', 'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ø­Ø³Ø§Ø¨'),
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
          t('Please log in first', 'ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ø£ÙˆÙ„Ø§Ù‹'),
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
              t('Failed to load profile', 'ÙØ´Ù„ ÙÙŠ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª'),
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
            label: t('First Name', 'Ø§Ù„Ø§Ø³Ù… Ø§Ù„Ø£ÙˆÙ„'),
            controller: _firstNameCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.person_outline,
            label: t('Last Name', 'Ø§Ø³Ù… Ø§Ù„Ø¹Ø§Ø¦Ù„Ø©'),
            controller: _lastNameCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.email_outlined,
            label: t('Email', 'Ø§Ù„Ø¨Ø±ÙŠØ¯ Ø§Ù„Ø¥Ù„ÙƒØªØ±ÙˆÙ†ÙŠ'),
            controller: _emailCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.phone_outlined,
            label: t('Phone Number', 'Ø±Ù‚Ù… Ø§Ù„Ù‡Ø§ØªÙ'),
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
                    isEn ? 'Save Changes' : 'Ø­ÙØ¸ Ø§Ù„ØªØºÙŠÙŠØ±Ø§Øª',
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
                  t('Sex', 'Ø§Ù„Ø¬Ù†Ø³'),
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
                      label: t('Male', 'Ø°ÙƒØ±'),
                      value: 'male',
                      selected: _sex.toLowerCase() == 'male',
                    ),
                    const SizedBox(width: 10),
                    _sexChip(
                      label: t('Female', 'Ø£Ù†Ø«Ù‰'),
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



