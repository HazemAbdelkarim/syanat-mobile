import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'main.dart' show AppLocale;
import 'technician_profile_screen.dart';

const Color _blue = Color(0xFF3C21C8);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sendingReset = false;

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> _logout(BuildContext context) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t(isEn, 'Log Out', 'تسجيل الخروج')),
        content: Text(
          _t(isEn, 'Are you sure you want to log out?',
              'هل أنت متأكد أنك تريد تسجيل الخروج؟'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(isEn, 'Cancel', 'إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_t(isEn, 'Log Out', 'خروج')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── Change Password ─────────────────────────────────────────────────────────
  Future<void> _changePassword(BuildContext context) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    // Check if the user signed in with email/password
    final hasPasswordProvider = user.providerData
        .any((p) => p.providerId == 'password');

    if (!hasPasswordProvider) {
      _showInfoDialog(
        context,
        isEn,
        title: _t(isEn, 'Not Available', 'غير متاح'),
        message: _t(
          isEn,
          'You signed in with Google or Apple. Password change is not available for social accounts.',
          'لقد سجّلت الدخول باستخدام Google أو Apple. تغيير كلمة المرور غير متاح لحسابات التسجيل الاجتماعي.',
        ),
      );
      return;
    }

    final email = user.email ?? '';
    if (email.isEmpty) return;

    setState(() => _sendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showInfoDialog(
        context,
        isEn,
        title: _t(isEn, 'Email Sent', 'تم إرسال البريد'),
        message: _t(
          isEn,
          'A password reset link has been sent to $email. Check your inbox.',
          'تم إرسال رابط إعادة تعيين كلمة المرور إلى $email. تحقق من بريدك الوارد.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showInfoDialog(
        context,
        isEn,
        title: _t(isEn, 'Error', 'خطأ'),
        message: '$e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  void _showInfoDialog(
    BuildContext context,
    bool isEn, {
    required String title,
    required String message,
    bool isError = false,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? Colors.red.shade600 : _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_t(isEn, 'OK', 'حسناً')),
          ),
        ],
      ),
    );
  }

  // ── Language toggle ─────────────────────────────────────────────────────────
  void _toggleLanguage() {
    final notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7FB),
        appBar: AppBar(
          backgroundColor: _blue,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _t(isEn, 'Settings', 'الإعدادات'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section: Account ────────────────────────────────────────
              _sectionLabel(isEn ? 'Account' : 'الحساب'),
              const SizedBox(height: 10),
              _settingsTile(
                icon: Icons.person_outline,
                label: _t(isEn, 'My Profile', 'ملفي الشخصي'),
                subtitle: _t(isEn, 'Edit your name, phone and photo',
                    'عدّل اسمك ورقمك وصورتك'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TechnicianProfileScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _settingsTile(
                icon: Icons.lock_outline,
                label: _t(isEn, 'Change Password', 'تغيير كلمة المرور'),
                subtitle: _t(
                  isEn,
                  'Receive a reset link by email',
                  'استلم رابط إعادة التعيين عبر البريد',
                ),
                onTap: _sendingReset ? null : () => _changePassword(context),
                trailing: _sendingReset
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _blue),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              // ── Section: Preferences ────────────────────────────────────
              _sectionLabel(isEn ? 'Preferences' : 'التفضيلات'),
              const SizedBox(height: 10),
              _settingsTile(
                icon: Icons.language,
                label: _t(isEn, 'Language', 'اللغة'),
                subtitle: _t(isEn, 'Switch to Arabic', 'التبديل إلى الإنجليزية'),
                onTap: _toggleLanguage,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEn ? 'EN' : 'AR',
                    style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ── Section: About ───────────────────────────────────────────
              _sectionLabel(isEn ? 'About' : 'حول التطبيق'),
              const SizedBox(height: 10),
              _settingsTile(
                icon: Icons.info_outline,
                label: _t(isEn, 'About Syanat', 'عن صيانت'),
                subtitle: _t(isEn, 'Professional home services', 'خدمات منزلية احترافية'),
                onTap: () => _showInfoDialog(
                  context,
                  isEn,
                  title: _t(isEn, 'About Syanat', 'عن صيانت'),
                  message: _t(
                    isEn,
                    'Syanat connects customers with skilled technicians for fast, reliable home services.',
                    'صيانت تربط العملاء بالفنيين المهرة لخدمات منزلية سريعة وموثوقة.',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ── Logout ───────────────────────────────────────────────────
              _settingsTile(
                icon: Icons.logout,
                label: _t(isEn, 'Log Out', 'تسجيل الخروج'),
                iconColor: Colors.red.shade600,
                labelColor: Colors.red.shade600,
                onTap: () => _logout(context),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? labelColor,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (iconColor ?? _blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor ?? _blue, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: labelColor ?? Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
