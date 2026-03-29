import 'package:flutter/material.dart';

import 'customer_signup_flow.dart';
import 'main.dart' show AppLocale;
import 'technician_signup_flow.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class RoleSelectionScreen extends StatefulWidget {
  final String? prefillUid;
  final String prefillEmail;
  final String prefillName;

  const RoleSelectionScreen({
    super.key,
    this.prefillUid,
    this.prefillEmail = '',
    this.prefillName = '',
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  void _switchLanguage() {
    final notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  void _continue() {
    if (_selectedRole == null) return;
    final route = MaterialPageRoute(
      builder: (_) => _selectedRole == 'technician'
          ? TechnicianSignupFlow(
              prefillUid: widget.prefillUid,
              prefillEmail: widget.prefillEmail,
              prefillName: widget.prefillName,
            )
          : CustomerSignupFlow(
              prefillUid: widget.prefillUid,
              prefillEmail: widget.prefillEmail,
              prefillName: widget.prefillName,
            ),
    );
    Navigator.push(context, route);
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: _switchLanguage,
                          icon: const Icon(Icons.language, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: const EdgeInsets.all(28),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(isEn, 'Who are you?', 'من أنت؟'),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _t(
                                  isEn,
                                  'Choose your account type to get started',
                                  'اختر نوع حسابك للبدء',
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _roleCard(
                                role: 'customer',
                                icon: Icons.person,
                                title: _t(isEn, 'Customer', 'عميل'),
                                subtitle: _t(
                                  isEn,
                                  'Book services at home',
                                  'احجز خدمات في المنزل',
                                ),
                              ),
                              const SizedBox(height: 16),
                              _roleCard(
                                role: 'technician',
                                icon: Icons.build,
                                title: _t(isEn, 'Potential Technician', 'فني محتمل'),
                                subtitle: _t(
                                  isEn,
                                  'Join our network of professionals',
                                  'انضم إلى شبكة المحترفين',
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _selectedRole == null ? null : _continue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: syanatBlue,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _t(isEn, 'Continue', 'متابعة'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _roleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedRole == role;

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 80,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? syanatBlue : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: syanatBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: syanatBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? syanatBlue : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
