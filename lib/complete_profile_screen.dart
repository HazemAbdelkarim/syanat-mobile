// CompleteProfileScreen — shown to a user who is SIGNED IN but whose Firestore
// profile is missing required fields (role / username / phone). This typically
// happens to a user who authenticated via Google/Apple but closed the app
// before finishing the signup form.
//
// This screen is intentionally SEPARATE from the new-user RoleSelectionScreen:
//   • The copy frames it as "finish your profile", not "create an account".
//   • It exposes a visible Log Out action so the user isn't dead-ended if they
//     landed here by mistake or want to sign in with a different account.
//   • The back button (system + AppBar) always works — Log Out takes them to
//     LoginScreen via the AuthGate reroute.
//
// Routed to exclusively by AuthGate. Never reached from LoginScreen's "Create
// an account" link (that goes to RoleSelectionScreen).

import 'package:flutter/material.dart';

import 'customer_signup_flow.dart';
import 'firebase_service.dart';
import 'main.dart' show AppLocale;
import 'technician_signup_flow.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class CompleteProfileScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String name;

  const CompleteProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.name,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  String? _selectedRole;
  bool _signingOut = false;

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  void _switchLanguage() {
    final ValueNotifier<Locale> notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await FirebaseService.auth.signOut();
      // AuthGate will observe the user==null emission and swap to LoginScreen.
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _continue() {
    if (_selectedRole == null) return;
    final MaterialPageRoute<void> route = MaterialPageRoute<void>(
      builder: (_) => _selectedRole == 'technician'
          ? TechnicianSignupFlow(
              prefillUid: widget.uid,
              prefillEmail: widget.email,
              prefillName: widget.name,
            )
          : CustomerSignupFlow(
              prefillUid: widget.uid,
              prefillEmail: widget.email,
              prefillName: widget.name,
            ),
    );
    Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _syanatBlue,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext _, BoxConstraints constraints) =>
                SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: _signingOut ? null : _signOut,
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            _t(isEn, 'Log out', 'تسجيل الخروج'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: _switchLanguage,
                          icon: const Icon(
                            Icons.language,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _t(
                                  isEn,
                                  'Finish setting up your account',
                                  'أكمل إعداد حسابك',
                                ),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _t(
                                  isEn,
                                  "We still need a few details before you can continue. Pick the account type that fits you.",
                                  "نحتاج بعض المعلومات قبل المتابعة. اختر نوع الحساب المناسب لك.",
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 28),
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
                                title: _t(
                                  isEn,
                                  'Potential Technician',
                                  'فني محتمل',
                                ),
                                subtitle: _t(
                                  isEn,
                                  'Join our network of professionals',
                                  'انضم إلى شبكة المحترفين',
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _selectedRole == null
                                      ? null
                                      : _continue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _syanatBlue,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
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
                              const SizedBox(height: 14),
                              Center(
                                child: TextButton(
                                  onPressed: _signingOut ? null : _signOut,
                                  child: Text(
                                    _t(
                                      isEn,
                                      'Not you? Sign in with a different account',
                                      'ليس أنت؟ سجّل بحساب آخر',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _syanatBlue,
                                      fontWeight: FontWeight.w600,
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
    final bool selected = _selectedRole == role;
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
            color: selected ? _syanatBlue : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _syanatBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _syanatBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? _syanatBlue : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
