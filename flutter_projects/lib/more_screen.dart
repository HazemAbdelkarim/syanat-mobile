import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'personal_info_screen.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class MoreScreen extends StatelessWidget {
  final Function(Locale) setLocale;
  const MoreScreen({required this.setLocale, super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String t(String en, String ar) => isEn ? en : ar;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            t('Account', 'الحساب'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                t('Wallet: EGP', 'المحفظة: جنيه'),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MoreTile(
              icon: Icons.person_outline,
              label: t('Personal information', 'المعلومات الشخصية'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _MoreTile(
              icon: Icons.settings_outlined,
              label: t('Account settings', 'إعدادات الحساب'),
              onTap: () => _openPlaceholder(context, t('Account settings', 'إعدادات الحساب')),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _MoreTile(
              icon: Icons.location_on_outlined,
              label: t('Saved locations', 'المواقع المحفوظة'),
              onTap: () => _openPlaceholder(context, t('Saved locations', 'المواقع المحفوظة')),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _MoreTile(
              icon: Icons.help_outline,
              label: t('Need help?', 'تحتاج مساعدة؟'),
              onTap: () => _openPlaceholder(context, t('Need help?', 'تحتاج مساعدة؟')),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _MoreTile(
              icon: Icons.quiz_outlined,
              label: t('FAQ', 'الأسئلة الشائعة'),
              onTap: () => _openPlaceholder(context, t('FAQ', 'الأسئلة الشائعة')),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _MoreTile(
              icon: Icons.language,
              label: t('Language', 'اللغة'),
              onTap: () {
                final newLocale = isEn ? const Locale('ar') : const Locale('en');
                Future.microtask(() => setLocale(newLocale));
              },
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _logout(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text(
                    t('Logout', 'تسجيل الخروج'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EmptySectionScreen(title: title),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          setLocale: setLocale,
        ),
      ),
      (route) => false,
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _syanatBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _syanatBlue, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    );
  }
}

class _EmptySectionScreen extends StatelessWidget {
  final String title;
  const _EmptySectionScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _syanatBlue,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const SizedBox.shrink(),
      ),
    );
  }
}
