// gradient_background.dart
import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({
    required this.child,
    super.key,
  });

  // Main logo blue
  static const Color _primaryBlue = Color(0xFF3C21C8); // adjust if your exact hex differs

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Subtle vertical gradient around the logo blue
        gradient: LinearGradient(
          colors: [
            Color(0xFF3832FF), // slightly darker top
            _primaryBlue,
            Color(0xFF615DFF), // slightly lighter bottom
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
