import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _syanatBlue = Color(0xFF3C21C8);
const String adminWebUrl = 'https://syanat-admin.web.app';

class AdminRedirectScreen extends StatefulWidget {
  const AdminRedirectScreen({super.key});

  @override
  State<AdminRedirectScreen> createState() => _AdminRedirectScreenState();
}

class _AdminRedirectScreenState extends State<AdminRedirectScreen> {
  bool _eventEmitted = false;

  @override
  void initState() {
    super.initState();
    if (!_eventEmitted) {
      _eventEmitted = true;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uidHash = sha256
            .convert(utf8.encode(user.uid))
            .toString()
            .substring(0, 12);
        FirebaseAnalytics.instance.logEvent(
          name: 'admin_redirect_shown',
          parameters: {'uid_hash': uidHash},
        );
      }
    }
  }

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  Future<void> _copyUrl(bool isEn) async {
    await Clipboard.setData(const ClipboardData(text: adminWebUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(isEn, 'URL copied to clipboard', 'تم نسخ الرابط')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                    Icons.admin_panel_settings_outlined,
                    size: 72,
                    color: _syanatBlue,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _t(
                      isEn,
                      'Admin access has moved',
                      'تم نقل وصول المشرف',
                    ),
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
                      'Admin tools are now available on the web dashboard. '
                          'Open the URL below on a desktop or laptop browser to sign in.',
                      'أدوات الإدارة متاحة الآن على لوحة التحكم عبر الويب. '
                          'افتح الرابط أدناه على متصفح حاسوب لتسجيل الدخول.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const SelectableText(
                      adminWebUrl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _syanatBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _copyUrl(isEn),
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(
                        _t(isEn, 'Copy URL', 'نسخ الرابط'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _syanatBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }
}
