// WelcomeScreen — first-time-user landing page.
//
// Replaces LoginScreen as the signed-out entry point in AuthGate. Two CTAs:
//   • "Create account"            → RoleSelectionScreen (signup flow)
//   • "I already have an account" → LoginScreen
//
// Design source: app-onboarding/project/lib/signup-screens.jsx → ScreenWelcome.
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'main.dart' show AppLocale;
import 'role_selection_screen.dart';

const Color _sBlue = Color(0xFF3C21C8);
const Color _sBlueTop = Color(0xFF3832FF);
const Color _sBlueLight = Color(0xFF615DFF);

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
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.55, 1.0],
              colors: [_sBlueTop, _sBlue, _sBlueLight],
            ),
          ),
          child: Stack(
            children: [
              // Decorative orbs (match GradOrbs from the design).
              Positioned(
                top: -80,
                right: -60,
                child: _orb(260, const Color(0x38FFFFFF)),
              ),
              Positioned(
                top: 120,
                left: -120,
                child: _orb(320, _sBlueLight.withOpacity(0.55)),
              ),
              Positioned(
                bottom: -100,
                right: -80,
                child: _orb(300, _sBlueTop.withOpacity(0.45)),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar — language toggle on the trailing edge.
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 8,
                        end: 8,
                        top: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          IconButton(
                            tooltip: _t(isEn, 'Language', 'اللغة'),
                            onPressed: () => _switchLanguage(context),
                            icon: const Icon(
                              Icons.language,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Logo mark — top-leading, glass tile.
                    const Padding(
                      padding: EdgeInsetsDirectional.only(start: 28),
                      child: _LogoMark(size: 68),
                    ),
                    // Bottom-anchored headline + copy.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(
                                isEn,
                                'Home fixes,\na tap away.',
                                'إصلاحات منزلك،\nبضغطة واحدة.',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                height: 1.03,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                _t(
                                  isEn,
                                  'Book vetted technicians for AC, plumbing, '
                                  'electrical and more — right from your phone.',
                                  'احجز فنيين موثوقين للتكييف والسباكة '
                                  'والكهرباء والمزيد — مباشرةً من هاتفك.',
                                ),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  fontSize: 17,
                                  height: 1.45,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // CTAs + terms.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Primary: white pill on gradient.
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () => _goCreateAccount(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _sBlue,
                                elevation: 0,
                                shadowColor: const Color(0x2E000000),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _t(isEn, 'Create account', 'إنشاء حساب'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Secondary: glass pill.
                          _GlassButton(
                            label: _t(
                              isEn,
                              'I already have an account',
                              'لدي حساب بالفعل',
                            ),
                            onTap: () => _goLogin(context),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                            child: Text(
                              _t(
                                isEn,
                                'By continuing you agree to our Terms and '
                                'Privacy Policy.',
                                'بمتابعتك فإنك توافق على الشروط وسياسة '
                                'الخصوصية.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}

// Glass logo tile (matches SyanatLogoMark with onDark=true). Wraps the brand
// asset so users still see the recognizable logo, while the surround matches
// the design.
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({this.size = 68});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset('assets/logo.jpeg', fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GlassButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.30)),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
