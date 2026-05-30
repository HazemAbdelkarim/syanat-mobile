// app_theme.dart — the app's Material 3 (Material Design 3) design system.
//
// One seeded ColorScheme + component themes drive every pre-login screen
// (Splash, Welcome, Login, Role selection, Onboarding) so they share the same
// brand purple, button shapes, type scale, and 8dp spacing rhythm. Built on
// Google's open-source Material 3 — no third-party design packages.
import 'package:flutter/material.dart';

/// Syanat brand purple — the single accent and the seed of the design system.
const Color brandPurple = Color(0xFF6C3FA0);

/// Neutral ink for headings on light surfaces.
const Color brandInk = Color(0xFF211D40);

/// Secondary / supporting text.
const Color brandMuted = Color(0xFF6B6B76);

/// Hairline used on cards, fields, and dividers.
const Color brandHairline = Color(0xFFE7E3F3);

/// Soft field / chip fill.
const Color brandFieldFill = Color(0xFFF6F4FA);

/// 8dp spacing scale — use these instead of ad-hoc magic numbers.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

ThemeData buildSyanatTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: brandPurple,
    brightness: Brightness.light,
  ).copyWith(
    primary: brandPurple,
    onPrimary: Colors.white,
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    splashColor: brandPurple.withValues(alpha: 0.08),
    highlightColor: brandPurple.withValues(alpha: 0.04),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFCFC7DD),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandPurple,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: brandPurple, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandPurple,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brandInk,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Brand lockup for light surfaces: the adaptive-icon mark (tinted) beside the
/// "syanat" wordmark. Shared by Splash, Welcome, and Login so the brand reads
/// identically everywhere.
class SyanatLogo extends StatelessWidget {
  final double height;
  final Color? color;
  const SyanatLogo({super.key, this.height = 60, this.color});

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? brandPurple;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/branding/icon_foreground.png',
          height: height,
          width: height,
          color: c,
          colorBlendMode: BlendMode.srcIn,
        ),
        SizedBox(width: height * 0.10),
        Text(
          'syanat',
          style: TextStyle(
            color: c,
            fontSize: height * 0.6,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
