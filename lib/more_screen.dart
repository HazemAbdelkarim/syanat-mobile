import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart' show AppLocale;
import 'login_screen.dart';
import 'personal_info_screen.dart';
import 'account_settings_screen.dart';
import 'saved_locations_screen.dart';
import 'faq_screen.dart';
import 'support_chat_screen.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String t(String en, String ar) => isEn ? en : ar;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.18,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C4DFF), Color(0xFF6C3CE1), Color(0xFF5228B5)]),
                  borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  t('Account', 'الحساب'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Group 1: General Account Settings
                  _MenuGroup(
                    children: [
                      _GroupedTile(
                        icon: Icons.person_outline,
                        label: t('Personal information', 'المعلومات الشخصية'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.settings_outlined,
                        label: t('Account settings', 'إعدادات الحساب'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.location_on_outlined,
                        label: t('Saved locations', 'المواقع المحفوظة'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SavedLocationsScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.language,
                        label: t('Language', 'اللغة'),
                        onTap: () {
                          final newLocale =
                              isEn ? const Locale('ar') : const Locale('en');
                          AppLocale.of(context).value = newLocale;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Group 2: Support & Privacy
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      t('Support & Privacy', 'الدعم والخصوصية'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MenuGroup(
                    children: [
                      _GroupedTile(
                        icon: Icons.support_agent,
                        label: t('Need help?', 'تحتاج مساعدة؟'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SupportChatScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.quiz_outlined,
                        label: t('FAQ', 'الأسئلة الشائعة'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FaqScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.privacy_tip_outlined,
                        label: t('Privacy Policy', 'سياسة الخصوصية'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('Coming soon', 'قريباً'))),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Logout Group
                  _MenuGroup(
                    children: [
                      _GroupedTile(
                        icon: Icons.logout,
                        label: t('Logout', 'تسجيل الخروج'),
                        iconColor: Colors.red.shade600,
                        textColor: Colors.red.shade700,
                        hideChevron: true,
                        onTap: () => _logout(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000), // very soft premium shadow
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();
  
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 60,
    );
  }
}

class _GroupedTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;
  final bool hideChevron;

  const _GroupedTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
    this.hideChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? _syanatBlue, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor ?? Colors.black87,
                  ),
                ),
              ),
              if (!hideChevron)
                Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

