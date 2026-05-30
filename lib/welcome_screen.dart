// WelcomeScreen — first-time-user landing page.
//
// Replaces LoginScreen as the signed-out entry point in AuthGate. Two CTAs:
//   • "Create account"            → RoleSelectionScreen (signup flow)
//   • "I already have an account" → LoginScreen
//
// Material 3 design system (see app_theme.dart): white surface, brand purple
// as the single accent, FilledButton primary + OutlinedButton secondary.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'login_screen.dart';
import 'main.dart' show AppLocale;
import 'role_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  void _switchLanguage(BuildContext context) {
    final notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  void _goCreateAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
    );
  }

  void _goLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar — language toggle on the trailing edge.
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: Gap.sm,
                    end: Gap.sm,
                    top: Gap.xs,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: _t(isEn, 'Language', 'اللغة'),
                      onPressed: () => _switchLanguage(context),
                      icon: const Icon(Icons.language, color: brandPurple),
                    ),
                  ),
                ),
                // Logo centered in the available middle space, with the hero
                // headline + copy anchored to its bottom edge.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg + 4, 0, Gap.lg + 4, Gap.lg),
                    child: Stack(
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: SyanatLogo(height: 64),
                        ),
                        Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  isEn,
                                  'Home fixes,\na tap away.',
                                  'إصلاحات منزلك،\nبضغطة واحدة.',
                                ),
                                style: const TextStyle(
                                  color: brandInk,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  height: 1.03,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              const SizedBox(height: Gap.md),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                child: Text(
                                  _t(
                                    isEn,
                                    'Book vetted technicians for AC, plumbing, '
                                    'electrical and more — right from your phone.',
                                    'احجز فنيين موثوقين للتكييف والسباكة '
                                    'والكهرباء والمزيد — مباشرةً من هاتفك.',
                                  ),
                                  style: const TextStyle(
                                    color: brandMuted,
                                    fontSize: 17,
                                    height: 1.45,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // CTAs + terms.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, 0, Gap.lg, Gap.sm + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () => _goCreateAccount(context),
                        child: Text(_t(isEn, 'Create account', 'إنشاء حساب')),
                      ),
                      const SizedBox(height: Gap.sm + 4),
                      OutlinedButton(
                        onPressed: () => _goLogin(context),
                        child: Text(
                          _t(
                            isEn,
                            'I already have an account',
                            'لدي حساب بالفعل',
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.sm + 2, Gap.md, Gap.sm + 2, Gap.xs),
                        child: Text(
                          _t(
                            isEn,
                            'By continuing you agree to our Terms and '
                            'Privacy Policy.',
                            'بمتابعتك فإنك توافق على الشروط وسياسة '
                            'الخصوصية.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: brandMuted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
