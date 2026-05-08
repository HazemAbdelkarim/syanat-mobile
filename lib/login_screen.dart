import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'admin_redirect_screen.dart';
import 'firebase_service.dart';
import 'main.dart' show AppLocale;
import 'role_selection_screen.dart';
import 'tech_home_screen.dart';
import 'user_home_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

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
    if (role == 'admin') {
      dest = const AdminRedirectScreen();
    } else if (role == 'technician') {
      dest = const TechHomeScreen();
    } else {
      dest = const UserHomeScreen();
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
          _loginError = _t(isEn, 'Enter a valid email address.', 'أدخل بريداً إلكترونياً صحيحاً.');
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

  Future<void> _handleSocialSignIn(Future<UserCredential?> Function() signInFn) async {
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

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: syanatBlue,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _switchLanguage,
                          icon: const Icon(Icons.language, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Image.asset(
                        'assets/branding/lockup.png',
                        width: 280,
                        height: 84,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _t(isEn, 'Login', 'تسجيل الدخول'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _emailController,
                              label: _t(isEn, 'Email', 'البريد الإلكتروني'),
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (_) {
                                if (_loginError != null) setState(() => _loginError = null);
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _passwordController,
                              label: _t(isEn, 'Password', 'كلمة المرور'),
                              icon: Icons.lock_outline,
                              obscure: true,
                              onChanged: (_) {
                                if (_loginError != null) setState(() => _loginError = null);
                              },
                            ),
                            if (_loginError != null) ...[
                              const SizedBox(height: 12),
                              _errorBox(_loginError!),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: syanatBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _t(isEn, 'Login', 'دخول'),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    _t(isEn, 'or', 'أو'),
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _socialIconButton(
                                    enabled: !_socialLoading && !_loading,
                                    onTap: () => _handleSocialSignIn(FirebaseService.signInWithGoogle),
                                    child: _socialLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: syanatBlue),
                                          )
                                        : SizedBox(width: 28, height: 28, child: FittedBox(child: _googleIcon())),
                                  ),
                                ),
                                if (!kIsWeb && Platform.isIOS || kIsWeb) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _socialIconButton(
                                      enabled: !_socialLoading && !_loading,
                                      onTap: () => _handleSocialSignIn(FirebaseService.signInWithApple),
                                      child: _socialLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: syanatBlue),
                                            )
                                          : const Icon(Icons.apple, size: 30, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: (_loading || _socialLoading)
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: syanatBlue,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _socialIconButton({
    required Widget child,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _googleIcon() {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
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
