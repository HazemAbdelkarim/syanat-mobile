// RoleSelectionScreen — gateway between WelcomeScreen's "Create account"
// and the new OnboardingFlow. Lets the user pick customer vs technician,
// styled to match the design system in app-onboarding/.
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'main.dart' show AppLocale;
import 'onboarding_flow.dart';

const Color _sBlue = Color(0xFF3C21C8);
const Color _sBlueTop = Color(0xFF3832FF);
const Color _sBlueLight = Color(0xFF615DFF);
const Color _sInk = Color(0xFF0B0A1F);
const Color _sMuted = Color(0xFF5B5973);
const Color _sFieldBg = Color(0xFFF4F2FA);
const Color _sFieldBorder = Color(0xFFE7E3F3);

const LinearGradient _gradSoft = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.6],
  colors: [Color(0xFFF3F1FF), Colors.white],
);

const LinearGradient _gradBtn = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: [0.0, 0.6, 1.0],
  colors: [_sBlueTop, _sBlue, _sBlueLight],
);

class RoleSelectionScreen extends StatefulWidget {
  final String? prefillUid;
  final String prefillEmail;
  final String prefillName;

  const RoleSelectionScreen({
    super.key,
    this.prefillUid,
    this.prefillEmail = '',
    this.prefillName = '',
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  void _switchLanguage() {
    final notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  void _continue() {
    if (_selectedRole == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OnboardingFlow(
          role: _selectedRole!,
          prefillUid: widget.prefillUid,
          prefillEmail: widget.prefillEmail,
          prefillName: widget.prefillName,
        ),
      ),
    );
  }

  void _goLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final isLtr = isEn;

    return Directionality(
      textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: _gradSoft),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Icon(
                          isLtr
                              ? Icons.arrow_back_ios_new
                              : Icons.arrow_forward_ios,
                          size: 16,
                          color: _sInk,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _switchLanguage,
                        icon: const Icon(Icons.language, color: _sInk),
                        tooltip: _t(isEn, 'Language', 'اللغة'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(isEn, 'Who are you?', 'من أنت؟'),
                          style: const TextStyle(
                            color: _sInk,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _t(
                            isEn,
                            'Choose your account type to get started.',
                            'اختر نوع حسابك للبدء.',
                          ),
                          style: const TextStyle(
                            color: _sMuted,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _RoleCard(
                          role: 'customer',
                          icon: Icons.person,
                          title: _t(isEn, 'Customer', 'عميل'),
                          subtitle: _t(
                            isEn,
                            'Book services at home',
                            'احجز خدمات في المنزل',
                          ),
                          selected: _selectedRole == 'customer',
                          onTap: () =>
                              setState(() => _selectedRole = 'customer'),
                        ),
                        const SizedBox(height: 14),
                        _RoleCard(
                          role: 'technician',
                          icon: Icons.handyman,
                          title: _t(isEn, 'Technician', 'فنّي'),
                          subtitle: _t(
                            isEn,
                            'Join our network of professionals',
                            'انضم إلى شبكة المحترفين',
                          ),
                          selected: _selectedRole == 'technician',
                          onTap: () =>
                              setState(() => _selectedRole = 'technician'),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      _GradButton(
                        label: _t(isEn, 'Continue', 'متابعة'),
                        onTap: _selectedRole == null ? null : _continue,
                      ),
                      TextButton(
                        onPressed: _goLogin,
                        child: Text(
                          _t(
                            isEn,
                            'Already have an account? Log in',
                            'لديك حساب بالفعل؟ سجّل الدخول',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _sBlue,
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

class _RoleCard extends StatelessWidget {
  final String role;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : _sFieldBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? _sBlue : _sFieldBorder,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x243C21C8),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x0A110C2E),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: _gradBtn,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _sInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _sMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected ? _sBlue : const Color(0xFFB6B0CE),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: _sFieldBg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GradButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _GradButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: disabled ? null : _gradBtn,
          color: disabled ? Colors.grey.shade400 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: disabled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x593C21C8),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
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
