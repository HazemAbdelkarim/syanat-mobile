// SplashScreen — the app's visual splash. Rendered by AuthGate while the auth
// and profile streams are hydrating. Contains NO routing logic: it does not
// read FirebaseAuth.currentUser, does not fetch the Firestore profile, and
// does not push to Login/Signup/Home. All of those decisions live in
// AuthGate, which swaps this widget out reactively once the streams settle.
//
// Keeping this widget stateless-at-the-logic-layer is what fixes the old
// intermittent bug where a timing-hack (Future.delayed(2s) + one-shot profile
// read + silent catch → Login) could strand a returning signed-in user on
// Login or on the new-user RoleSelectionScreen depending on which race won.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: FadeTransition(
              opacity: _scaleAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: const SyanatLogo(height: 72),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
