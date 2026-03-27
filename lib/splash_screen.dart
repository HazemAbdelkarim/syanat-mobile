import 'package:flutter/material.dart';
import '../firebase_service.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';
import 'tech_home_screen.dart';
import 'user_home_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800), // faster animation
      vsync: this,
    );

    // Start already large and grow quickly
    _scaleAnimation = Tween<double>(begin: 1.15, end: 1.4).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    // Keep splash about 2 seconds total
    Future.delayed(const Duration(seconds: 2), _checkUser);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkUser() async {
    if (!mounted) return;

    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      _goToLogin();
      return;
    }

    try {
      final profile = await FirebaseService.getProfile(user.uid);
      if (!mounted) return;

      // Firebase Auth session exists but Firestore profile is missing or
      // incomplete — this happens when a social sign-in user closes the app
      // before finishing the onboarding form. Route them back to complete it.
      if (!FirebaseService.isProfileComplete(profile)) {
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
        return;
      }

      final role = (profile!['role'] as String? ?? 'customer').trim();
      if (role == 'technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TechHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
        );
      }
    } catch (_) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: syanatBlue,
        body: Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/logo.jpeg',   // your logo file
                    width: 260,          // larger base size
                    height: 260,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}