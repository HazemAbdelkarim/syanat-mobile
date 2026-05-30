import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'firebase_service.dart';
import 'main.dart' show AppLocale;
import 'role_selection_screen.dart';
import 'tech_home_screen.dart';
import 'unauthorized_screen.dart';
import 'user_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _socialLoading = false;
  bool _hidePassword = true;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    // Drain any one-shot snackbar queued by AuthGate (e.g. user was
    // force-signed-out for an incomplete profile).
    final String? en = FirebaseService.pendingAuthSnackEn;
    final String? ar = FirebaseService.pendingAuthSnackAr;
    FirebaseService.pendingAuthSnackEn = null;
    FirebaseService.pendingAuthSnackAr = null;
    if (en == null && ar == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool isEn =
          Localizations.localeOf(context).languageCode == 'en';
      final String msg = (isEn ? en : ar) ?? en ?? ar ?? '';
      if (msg.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  void _switchLanguage() {
    final notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  void _routeByRole(String role) {
    if (!mounted) return;
    Widget dest;
    if (role == 'customer') {
      dest = const UserHomeScreen();
    } else if (role == 'technician') {
      dest = const TechHomeScreen();
    } else {
      dest = const UnauthorizedScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
  }

  Future<void> _login() async {
    if (_socialLoading) return;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    setState(() {
      _loading = true;
      _loginError = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

      if (!emailRegex.hasMatch(email)) {
        setState(() {
          _loginError = _t(isEn, 'Enter a valid email address.',
              'أدخل بريداً إلكترونياً صحيحاً.');
        });
        return;
      }
      if (password.isEmpty) {
        setState(() {
          _loginError = _t(isEn, 'Enter your password.', 'أدخل كلمة المرور.');
        });
        return;
      }

      final cred = await FirebaseService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) throw Exception('No user');

      final profile = await FirebaseService.getProfile(user.uid);
      if (!mounted) return;
      final role = (profile?['role'] as String? ?? 'customer').trim();
      _routeByRole(role);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loginError = _t(
          isEn,
          'Login failed. Please check your credentials.',
          'فشل تسجيل الدخول. يرجى التحقق من بياناتك.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSocialSignIn(
      Future<UserCredential?> Function() signInFn) async {
    if (_loading || _socialLoading) return;
    setState(() {
      _socialLoading = true;
      _loginError = null;
    });

    try {
      final cred = await signInFn();
      if (cred == null || !mounted) return;

      final user = cred.user!;
      final profile = await FirebaseService.getProfile(user.uid);
      if (!mounted) return;

      if (FirebaseService.isProfileComplete(profile)) {
        _routeByRole((profile!['role'] as String? ?? 'customer').trim());
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleSelectionScreen(
              prefillUid: user.uid,
              prefillEmail: user.email ?? '',
              prefillName: user.displayName ?? '',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      setState(() {
        _loginError = _t(
          isEn,
          'Social sign-in failed. Please try again.',
          'فشل تسجيل الدخول الاجتماعي. حاول مرة أخرى.',
        );
      });
    } finally {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final bool showApple = (!kIsWeb && Platform.isIOS) || kIsWeb;
    final bool busy = _loading || _socialLoading;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          tooltip: _t(isEn, 'Language', 'اللغة'),
                          onPressed: _switchLanguage,
                          icon: const Icon(Icons.language, color: brandPurple),
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      const Center(child: SyanatLogo(height: 52)),
                      const SizedBox(height: Gap.xl),
                      Text(
                        _t(isEn, 'Welcome back', 'مرحباً بعودتك'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: brandInk,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: Gap.sm),
                      Text(
                        _t(
                          isEn,
                          'Sign in to continue to your account.',
                          'سجّل الدخول للمتابعة إلى حسابك.',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: brandMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_loginError != null) {
                            setState(() => _loginError = null);
                          }
                        },
                        decoration: _fieldDecoration(
                          label: _t(isEn, 'Email', 'البريد الإلكتروني'),
                          icon: Icons.alternate_email,
                        ),
                      ),
                      const SizedBox(height: Gap.md),
                      TextField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        onChanged: (_) {
                          if (_loginError != null) {
                            setState(() => _loginError = null);
                          }
                        },
                        decoration: _fieldDecoration(
                          label: _t(isEn, 'Password', 'كلمة المرور'),
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            onPressed: () => setState(
                                () => _hidePassword = !_hidePassword),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: brandMuted,
                            ),
                          ),
                        ),
                      ),
                      if (_loginError != null) ...[
                        const SizedBox(height: Gap.md),
                        _ErrorBox(message: _loginError!),
                      ],
                      const SizedBox(height: Gap.lg),
                      FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_t(isEn, 'Login', 'دخول')),
                      ),
                      const SizedBox(height: Gap.lg),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: brandHairline)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Gap.md),
                            child: Text(
                              _t(isEn, 'or', 'أو'),
                              style: const TextStyle(
                                  color: brandMuted, fontSize: 13),
                            ),
                          ),
                          const Expanded(child: Divider(color: brandHairline)),
                        ],
                      ),
                      const SizedBox(height: Gap.md),
                      Row(
                        children: [
                          Expanded(
                            child: _SocialButton(
                              label: 'Google',
                              icon: const _GoogleIcon(),
                              busy: _socialLoading,
                              onTap: busy
                                  ? null
                                  : () => _handleSocialSignIn(
                                      FirebaseService.signInWithGoogle),
                            ),
                          ),
                          if (showApple) ...[
                            const SizedBox(width: Gap.sm + 4),
                            Expanded(
                              child: _SocialButton(
                                label: 'Apple',
                                icon: const Icon(Icons.apple,
                                    color: brandInk, size: 22),
                                busy: _socialLoading,
                                onTap: busy
                                    ? null
                                    : () => _handleSocialSignIn(
                                        FirebaseService.signInWithApple),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Gap.sm),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RoleSelectionScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          _t(
                            isEn,
                            "Don't have an account? Create one",
                            'ليس لديك حساب؟ أنشئ واحداً',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: brandMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: brandFieldFill,
      labelStyle: const TextStyle(color: brandMuted),
      floatingLabelStyle: const TextStyle(color: brandPurple),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brandHairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brandHairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brandPurple, width: 2),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final bool busy;
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: brandInk,
          side: const BorderSide(color: brandHairline, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: brandPurple),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 22, height: 22, child: Center(child: icon)),
                  const SizedBox(width: Gap.sm),
                  Text(
                    label,
                    style: const TextStyle(
                      color: brandInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: brandHairline),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
