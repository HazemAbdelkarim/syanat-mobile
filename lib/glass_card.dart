// glass_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,           // neutral light grey
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
