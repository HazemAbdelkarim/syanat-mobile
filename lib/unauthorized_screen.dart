import 'package:flutter/material.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

/// Shown to any signed-in user whose role is not `customer` or `technician`
/// — i.e. `admin` and any unrecognized role. Static dead-end by design:
/// no URL, no actions, no network or analytics calls (Spec 006, FR-013).
class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 72,
                    color: _syanatBlue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _t(isEn, 'Access denied', 'تم رفض الوصول'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      isEn,
                      'Your account is not available on this app.',
                      'حسابك غير متاح على هذا التطبيق.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
