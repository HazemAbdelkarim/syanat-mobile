import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_service.dart';
import 'user_home_screen.dart';
import 'tech_home_screen.dart';
import 'admin_dashboard_screen.dart';      // Admin dashboard
import 'create_account_screen.dart';       // Register page

const Color syanatBlue = Color(0xFF3C21C8);

class LoginScreen extends StatefulWidget {
  final Function(Locale) setLocale;
  const LoginScreen({required this.setLocale, super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

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
    widget.setLocale(newLocale);
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    try {
      final email = _emailController.text.trim();
      final pass = _passwordController.text.trim();

      // ADMIN LOGIN - hardcoded (CHANGE THESE!)
      const adminEmail = 'admin@syanat.com';
      const adminPass = 'admin123';  // ← CHANGE THIS PASSWORD!

      if (email == adminEmail && pass == adminPass) {
        // Admin success
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
        return;
      }

      // Normal user login (Firebase)
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);

      final user = cred.user;
      if (user == null) throw 'No user';

      final profile = await FirebaseService.getProfile(user.uid);
      final role = profile?['role'] ?? 'customer';

      if (!mounted) return;

      if (role == 'technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TechHomeScreen(setLocale: widget.setLocale),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserHomeScreen(setLocale: widget.setLocale),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Login error: $e' : 'خطأ في تسجيل الدخول: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Language button
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

                // Login card
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
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
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: isEn ? "Password" : "الباسورد",
                              icon: Icons.lock,
                              obscure: true,
                            ),
                            const SizedBox(height: 24),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: _loading
                                  ? const Center(child: CircularProgressIndicator(color: syanatBlue))
                                  : ElevatedButton(
                                      onPressed: _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: syanatBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: Text(
                                        isEn ? "Login" : "دخول",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 20),

                            // Create account button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreateAccountScreen(setLocale: widget.setLocale),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: syanatBlue, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  isEn ? "Create Account" : "إنشاء حساب جديد",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: syanatBlue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
