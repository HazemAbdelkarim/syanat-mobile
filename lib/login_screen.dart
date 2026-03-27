import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_service.dart';
import 'main.dart' show AppLocale;
import 'user_home_screen.dart';
import 'tech_home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'create_account_screen.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchLanguage() {
    final newLocale = Localizations.localeOf(context).languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    AppLocale.of(context).value = newLocale;
  }

  // ── Routing ──────────────────────────────────────────────────────────────

  void _routeByRole(String role) {
    if (!mounted) return;
    Widget dest;
    if (role == 'admin') {
      dest = const AdminDashboardScreen();
    } else if (role == 'technician') {
      dest = const TechHomeScreen();
    } else {
      dest = const UserHomeScreen();
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => dest));
  }

  // ── Email / Password login ────────────────────────────────────────────────

  Future<void> _login() async {
    if (_socialLoading) return;
    setState(() => _loading = true);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = cred.user;
      if (user == null) throw 'No user';

      final profile = await FirebaseService.getProfile(user.uid);
      final role = (profile?['role'] as String? ?? 'customer').trim();
      _routeByRole(role);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            isEn ? 'Login error: $e' : 'خطأ في تسجيل الدخول: $e'),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Social sign-in (Google / Apple) ──────────────────────────────────────

  /// Runs [signInFn], then routes the user based on profile completeness.
  /// Incomplete/new users are sent to CreateAccountScreen for profile
  /// completion — reusing the exact same onboarding form.
  Future<void> _handleSocialSignIn(
      Future<UserCredential?> Function() signInFn) async {
    if (_loading || _socialLoading) return;
    setState(() => _socialLoading = true);
    try {
      final cred = await signInFn();
      if (cred == null || !mounted) return; // user cancelled or widget gone

      final user = cred.user!;
      // Single O(1) read — determines full routing with one doc fetch.
      final profile = await FirebaseService.getProfile(user.uid);
      if (!mounted) return;

      if (FirebaseService.isProfileComplete(profile)) {
        _routeByRole((profile!['role'] as String? ?? 'customer').trim());
      } else {
        // New or incomplete profile — send to onboarding completion.
        // Pre-fill whatever the provider gave us; the form still requires
        // phone, role (and service if technician) before submission.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreateAccountScreen(
              prefillUid: user.uid,
              prefillEmail: user.email ?? '',
              prefillName: user.displayName ?? '',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEn
            ? 'Sign-in failed. Please try again.'
            : 'فشل تسجيل الدخول. حاول مجدداً.'),
      ));
    } finally {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    // Show Apple Sign-In only where it is natively available.
    final showApple = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: syanatBlue,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // Language button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _switchLanguage,
                          icon: const Icon(Icons.language,
                              color: Colors.white),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Logo
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/logo.jpeg',
                          width: 260,
                          height: 260,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Auth card
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isEn ? "Login" : "تسجيل الدخول",
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 32),

                            _buildTextField(
                              controller: _emailController,
                              label: isEn ? "Email" : "الإيميل",
                              icon: Icons.email,
                              keyboardType:
                                  TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: isEn
                                  ? "Password"
                                  : "الباسورد",
                              icon: Icons.lock,
                              obscure: true,
                            ),
                            const SizedBox(height: 24),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: _loading
                                  ? const Center(
                                      child:
                                          CircularProgressIndicator(
                                              color: syanatBlue))
                                  : ElevatedButton(
                                      onPressed: _login,
                                      style:
                                          ElevatedButton.styleFrom(
                                        backgroundColor:
                                            syanatBlue,
                                        foregroundColor:
                                            Colors.white,
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  14),
                                        ),
                                      ),
                                      child: Text(
                                        isEn ? "Login" : "دخول",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),

                            // Create account button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CreateAccountScreen(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: syanatBlue, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  isEn
                                      ? "Create Account"
                                      : "إنشاء حساب جديد",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: syanatBlue,
                                  ),
                                ),
                              ),
                            ),

                            // ── Social sign-in section ─────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Divider(
                                          color: Colors
                                              .grey.shade300)),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12),
                                    child: Text(
                                      isEn
                                          ? 'or continue with'
                                          : 'أو تابع عبر',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                      child: Divider(
                                          color: Colors
                                              .grey.shade300)),
                                ],
                              ),
                            ),

                            // Google button
                            _socialButton(
                              onPressed: _socialLoading
                                  ? null
                                  : () => _handleSocialSignIn(
                                      FirebaseService.signInWithGoogle),
                              label: isEn
                                  ? 'Continue with Google'
                                  : 'الدخول بـ Google',
                              icon: _googleIcon(),
                            ),

                            // Apple button — iOS / macOS only
                            if (showApple) ...[
                              const SizedBox(height: 12),
                              _socialButton(
                                onPressed: _socialLoading
                                    ? null
                                    : () => _handleSocialSignIn(
                                        FirebaseService.signInWithApple),
                                label: isEn
                                    ? 'Continue with Apple'
                                    : 'الدخول بـ Apple',
                                icon: const Icon(Icons.apple,
                                    color: Colors.black87, size: 20),
                              ),
                            ],

                            if (_socialLoading)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: syanatBlue),
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _socialButton({
    required VoidCallback? onPressed,
    required String label,
    required Widget icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Minimal branded 'G' badge — no external asset required.
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
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
