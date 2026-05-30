import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart' show AppLocale;
import 'login_screen.dart';
import 'personal_info_screen.dart';
import 'account_settings_screen.dart';
import 'saved_locations_screen.dart';
import 'faq_screen.dart';
import 'support_chat_screen.dart';

// ─── Theme colors — aligned with the home & orders screens (brand purple) ───
const Color kPrimary = Color(0xFF6C3FA0);
const Color kPrimaryDark = Color(0xFF211D40);
const Color kLavender = Color(0xFFEADDF9);
const Color kLavenderSoft = Color(0xFFF3EEFB);
const Color kSurfaceBg = Color(0xFFF7F6FA);
const Color kCardBorder = Color(0xFFEDEAF3);
const Color kTextMuted = Color(0xFF8B8699);

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String t(String en, String ar) => isEn ? en : ar;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kSurfaceBg,
        body: Column(
          children: [
            // Clean header — matches the home & orders surfaces (no gradient).
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    t('Account', 'الحساب'),
                    style: const TextStyle(
                      color: kPrimaryDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _ProfileCard(isEn: isEn),
                  const SizedBox(height: 24),

                  // Group 1: General Account Settings
                  _MenuGroup(
                    children: [
                      _GroupedTile(
                        icon: Icons.person_outline,
                        label: t('Personal information', 'المعلومات الشخصية'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PersonalInfoScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.settings_outlined,
                        label: t('Account settings', 'إعدادات الحساب'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AccountSettingsScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.location_on_outlined,
                        label: t('Saved locations', 'المواقع المحفوظة'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SavedLocationsScreen()),
                        ),
                      ),
                      const _GroupDivider(),
                      _GroupedTile(
                        icon: Icons.language,
                        label: t('Language', 'اللغة'),
                        trailingText: isEn ? 'EN' : 'ع',
                        hideChevron: true,
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
                    padding: const EdgeInsetsDirectional.only(start: 8, bottom: 12),
                    child: Text(
                      t('Support & Privacy', 'الدعم والخصوصية'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
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
                  const SizedBox(height: 24),

                  // Logout Group
                  _MenuGroup(
                    children: [
                      _GroupedTile(
                        icon: Icons.logout,
                        label: t('Logout', 'تسجيل الخروج'),
                        iconColor: const Color(0xFFDC2626),
                        textColor: const Color(0xFFDC2626),
                        chipColor: const Color(0xFFFDECEC),
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

/// Profile summary at the top of the Account tab — avatar (initials), the
/// signed-in name/email from FirebaseAuth, and a chevron into the editable
/// Personal information screen.
class _ProfileCard extends StatelessWidget {
  final bool isEn;
  const _ProfileCard({required this.isEn});

  String _initials(String? name, String? email) {
    final source = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (email ?? '').trim();
    if (source.isEmpty) return '·';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return source[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final title = name.isNotEmpty
        ? name
        : (isEn ? 'Your account' : 'حسابك');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: kLavender,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(name, email),
                    style: const TextStyle(
                      color: kPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: kPrimaryDark,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: const TextStyle(
                            color: kTextMuted,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFC9C4D6), size: 22),
              ],
            ),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000), // very soft premium shadow
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF1EEF7),
      indent: 68,
    );
  }
}

class _GroupedTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;
  final Color? chipColor;
  final String? trailingText;
  final bool hideChevron;

  const _GroupedTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
    this.chipColor,
    this.trailingText,
    this.hideChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chipColor ?? kLavenderSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? kPrimary, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    color: textColor ?? kPrimaryDark,
                  ),
                ),
              ),
              if (trailingText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kLavenderSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trailingText!,
                    style: const TextStyle(
                      color: kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (!hideChevron)
                const Icon(Icons.chevron_right,
                    color: Color(0xFFC9C4D6), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
