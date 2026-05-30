// OnboardingFlow — unified signup wizard for customers and technicians.
//
// Replaces the old CustomerSignupFlow and TechnicianSignupFlow widgets. The
// visual design is sourced from app-onboarding/ (Phone → OTP → Profile →
// [Service for technicians] → Location → Success).
//
// Demo gaps (intentional for now):
//   • OTP screen accepts ANY 6 digits — no SMS is sent. Real Firebase Phone
//     Auth wiring is left for a follow-up.
//   • Location screen renders a stylised faux-map and writes a hard-coded
//     Cairo / Zamalek GeoPoint. Real geolocation + map tiles are out of scope
//     for this UI pass.
//
// Social-sign-in (Apple/Google) flows: when the user taps a social button on
// the Phone screen, FirebaseService signs them in. If the user already has a
// complete profile, AuthGate routes them straight to the home screen. If the
// profile is incomplete, AuthGate force-signs them back out and surfaces a
// LoginScreen snackbar prompting them to sign in and finish setup — at which
// point LoginScreen's social-signin handler re-enters this flow with
// prefillUid set so we skip Phone + OTP and start at Profile.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'firebase_service.dart';
import 'tech_home_screen.dart';
import 'user_home_screen.dart';
import 'widgets/egyptian_phone_field.dart';
import 'widgets/map_picker_screen.dart';

// ─── Design tokens (mirror app-onboarding/project/lib/signup-screens.jsx) ───
const Color _sBlue = Color(0xFF6C3FA0);
const Color _sBlueTop = Color(0xFF8A5CC9);
const Color _sBlueLight = Color(0xFF7A4DB8);
const Color _sInk = Color(0xFF0B0A1F);
const Color _sMuted = Color(0xFF5B5973);
const Color _sFieldBg = Color(0xFFF4F2FA);
const Color _sFieldBorder = Color(0xFFE7E3F3);
const Color _sDividerSoft = Color(0xFFE0DDEC);

const LinearGradient _gradSoft = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.0, 0.6],
  colors: [Color(0xFFF3F1FF), Colors.white],
);

const LinearGradient _gradBtn = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: [0.0, 0.6, 1.0],
  colors: [_sBlueTop, _sBlue, _sBlueLight],
);

// Demo coordinate used until real geolocation is wired in.
const double _demoLat = 30.0626;
const double _demoLng = 31.2197;
const String _demoLocationLabel = 'Zamalek, Cairo';
const String _demoLocationSub = '26 July St · ~15 m accuracy';
const String _demoLocationLabelAr = 'الزمالك، القاهرة';
const String _demoLocationSubAr = 'شارع 26 يوليو · دقة ~15 م';

class OnboardingFlow extends StatefulWidget {
  final String role; // 'customer' | 'technician'
  final String? prefillUid;
  final String prefillEmail;
  final String prefillName;

  const OnboardingFlow({
    super.key,
    required this.role,
    this.prefillUid,
    this.prefillEmail = '',
    this.prefillName = '',
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Step { phone, otp, profile, service, location, success }

class _OnboardingFlowState extends State<OnboardingFlow> {
  // ── Collected values ─────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _service = ''; // technician only
  bool _hasLocation = false;
  LatLng? _pickedLatLng;

  // ── Submission state ─────────────────────────────────────────────────────
  bool _busy = false;
  String? _error;

  // ── Navigation state ─────────────────────────────────────────────────────
  late _Step _step;

  bool get _isSocial => widget.prefillUid != null;
  bool get _isTech => widget.role == 'technician';

  /// Step dot index for the current screen (Success = last).
  int get _dotIndex {
    switch (_step) {
      case _Step.phone:
        return 0;
      case _Step.otp:
        return 1;
      case _Step.profile:
        return _isSocial ? 0 : 2;
      case _Step.service:
        return _isSocial ? 1 : 3;
      case _Step.location:
        return _socialOffset(3);
      case _Step.success:
        return _totalDots - 1;
    }
  }

  int _socialOffset(int normal) {
    if (!_isSocial) return normal;
    return normal - 2;
  }

  int get _totalDots {
    // Customers: phone+otp+profile+location+success (or profile+location+success if social).
    // Technicians: phone+otp+profile+service+success (or profile+service+success if social) —
    // technicians do NOT pin during onboarding (see project_maps_feature memory).
    return _isSocial ? 3 : 5;
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.prefillName;
    _emailController.text = widget.prefillEmail;
    _step = _isSocial ? _Step.profile : _Step.phone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  // ── Step transitions ─────────────────────────────────────────────────────
  void _goBack() {
    setState(() => _error = null);
    switch (_step) {
      case _Step.phone:
        Navigator.of(context).maybePop();
        return;
      case _Step.otp:
        setState(() => _step = _Step.phone);
        return;
      case _Step.profile:
        if (_isSocial) {
          Navigator.of(context).maybePop();
        } else {
          setState(() => _step = _Step.otp);
        }
        return;
      case _Step.service:
        setState(() => _step = _Step.profile);
        return;
      case _Step.location:
        setState(() => _step = _isTech ? _Step.service : _Step.profile);
        return;
      case _Step.success:
        // Account already created — back is a no-op.
        return;
    }
  }

  void _advanceFrom(_Step from) {
    switch (from) {
      case _Step.phone:
        setState(() => _step = _Step.otp);
        return;
      case _Step.otp:
        setState(() => _step = _Step.profile);
        return;
      case _Step.profile:
        setState(() => _step = _isTech ? _Step.service : _Step.location);
        return;
      case _Step.service:
        // Technicians skip the location step — submit directly. The submit
        // call is wired at the _ServiceScreen onContinue site (see build()),
        // not here, because it needs the current locale.
        return;
      case _Step.location:
      case _Step.success:
        return;
    }
  }

  // ── Submission ───────────────────────────────────────────────────────────
  Future<void> _submitAndShowSuccess(bool isEn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    // Mark signup as in-flight so AuthGate's profile-incomplete detection
    // doesn't race the Firestore write below. The flag covers both the
    // email/password path (Auth user created mid-await on line 224 below)
    // AND the social-prefill path (Auth user already exists, but the
    // users/{uid} doc is briefly absent on first profile completion).
    // Reset in `finally` so a thrown exception cannot leave the flag
    // stuck `true` for the rest of the process lifetime.
    FirebaseService.signupInProgress = true;

    User? created;
    try {
      final String username = _nameController.text.trim();
      final String email = _emailController.text.trim().toLowerCase();
      final String phone = _isSocial
          ? ''
          : egyptianToE164(_phoneController.text.trim());
      final String lang = isEn ? 'en' : 'ar';

      String uid;
      if (_isSocial) {
        uid = widget.prefillUid!;
      } else {
        final cred = await FirebaseService.auth.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        final user = cred.user;
        if (user == null) {
          throw Exception(
            _t(isEn, 'Unable to create account.', 'تعذر إنشاء الحساب.'),
          );
        }
        created = user;
        uid = user.uid;
      }

      // Technicians don't pin during onboarding. Customers may have skipped
      // the pin step ("Skip for now") — in that case we leave location/city
      // empty rather than lying with hardcoded Cairo defaults. The order
      // flow will prompt for a precise pin on first use.
      final GeoPoint? pickedPoint = _pickedLatLng != null
          ? GeoPoint(_pickedLatLng!.latitude, _pickedLatLng!.longitude)
          : null;

      await FirebaseService.createUser(
        uid: uid,
        email: email,
        username: username,
        role: widget.role,
        phone: phone,
        city: '',
        service: _isTech ? _service : '',
        language: lang,
        location: pickedPoint,
      );

      // Customers get a default saved location seeded from the onboarding
      // pin so they can place an order immediately without re-pinning.
      // Skipped when the user took the manual-skip path (no pin) — they'll
      // be prompted to add one from the order flow.
      if (!_isTech && _pickedLatLng != null) {
        try {
          final id = await FirebaseService.addSavedLocation(uid, {
            'label': isEn ? 'Home' : 'المنزل',
            'lat': _pickedLatLng!.latitude,
            'lng': _pickedLatLng!.longitude,
            // No address text — the user pinned a coordinate but never typed
            // street/city. They can add detail later from Saved Locations.
          });
          await FirebaseService.setActiveLocation(uid, id);
        } catch (e) {
          // Non-fatal: account is created; user can add a location later.
          // Logged so QA/Crashlytics can spot rule failures during rollout.
          debugPrint('[onboarding] seed saved-location failed: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.success;
      });
    } catch (e) {
      if (created != null) {
        try {
          await created.delete();
        } catch (_) {
          await FirebaseService.auth.signOut();
        }
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _t(
          isEn,
          'Could not create your account. Please try again.',
          'تعذر إنشاء الحساب. يرجى المحاولة مرة أخرى.',
        );
      });
    } finally {
      FirebaseService.signupInProgress = false;
    }
  }

  void _routeHome() {
    final dest = _isTech ? const TechHomeScreen() : const UserHomeScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => dest),
      (_) => false,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: PopScope(
        canPop: _step == _Step.success || _step == _Step.phone,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _goBack();
        },
        child: Scaffold(
          body: switch (_step) {
            _Step.phone => _PhoneScreen(
                isEn: isEn,
                phoneCtrl: _phoneController,
                dot: _dotIndex,
                totalDots: _totalDots,
                error: _error,
                onBack: _goBack,
                onContinue: () {
                  final err = validateEgyptianLocal(
                    _phoneController.text.trim(),
                    isEn: isEn,
                  );
                  if (err != null) {
                    setState(() => _error = err);
                    return;
                  }
                  setState(() => _error = null);
                  _advanceFrom(_Step.phone);
                },
                onSocialGoogle: () => _socialSignIn(
                  isEn: isEn,
                  signIn: FirebaseService.signInWithGoogle,
                ),
                onSocialApple: () => _socialSignIn(
                  isEn: isEn,
                  signIn: FirebaseService.signInWithApple,
                ),
                busy: _busy,
              ),
            _Step.otp => _OtpScreen(
                isEn: isEn,
                phoneE164: egyptianToE164(_phoneController.text.trim()),
                dot: _dotIndex,
                totalDots: _totalDots,
                onBack: _goBack,
                onVerify: (code) {
                  if (code.length != 6) {
                    setState(() => _error = _t(
                          isEn,
                          'Enter the 6-digit code.',
                          'أدخل الرمز المكوّن من 6 أرقام.',
                        ));
                    return;
                  }
                  setState(() => _error = null);
                  _advanceFrom(_Step.otp);
                },
                error: _error,
              ),
            _Step.profile => _ProfileScreen(
                isEn: isEn,
                isSocial: _isSocial,
                nameCtrl: _nameController,
                emailCtrl: _emailController,
                passwordCtrl: _passwordController,
                dot: _dotIndex,
                totalDots: _totalDots,
                error: _error,
                onBack: _goBack,
                onContinue: () {
                  final err = _validateProfile(isEn);
                  if (err != null) {
                    setState(() => _error = err);
                    return;
                  }
                  setState(() => _error = null);
                  _advanceFrom(_Step.profile);
                },
              ),
            _Step.service => _ServiceScreen(
                isEn: isEn,
                selected: _service,
                dot: _dotIndex,
                totalDots: _totalDots,
                error: _error,
                onBack: _goBack,
                onSelect: (s) => setState(() {
                  _service = s;
                  _error = null;
                }),
                onContinue: () {
                  if (_service.isEmpty) {
                    setState(() => _error = _t(
                          isEn,
                          'Pick the service you offer.',
                          'اختر الخدمة التي تقدّمها.',
                        ));
                    return;
                  }
                  setState(() => _error = null);
                  // Technicians skip the customer-only pin step and submit
                  // straight from here (see project_maps_feature memory).
                  _submitAndShowSuccess(isEn);
                },
              ),
            _Step.location => _LocationScreen(
                isEn: isEn,
                hasLocation: _hasLocation,
                busy: _busy,
                dot: _dotIndex,
                totalDots: _totalDots,
                error: _error,
                onBack: _goBack,
                onUseMyLocation: () async {
                  final result =
                      await Navigator.of(context).push<LatLng>(
                    MaterialPageRoute(
                      builder: (_) =>
                          MapPickerScreen(initial: _pickedLatLng),
                    ),
                  );
                  if (result == null || !mounted) return;
                  setState(() {
                    _pickedLatLng = result;
                    _hasLocation = true;
                  });
                  await _submitAndShowSuccess(isEn);
                },
                onManual: () {
                  // Skip path: account proceeds with the default Cairo coord
                  // and no seeded saved-location. User pins their real spot
                  // the first time they place an order.
                  setState(() => _hasLocation = true);
                  _submitAndShowSuccess(isEn);
                },
              ),
            _Step.success => _SuccessScreen(
                isEn: isEn,
                name: _nameController.text.trim(),
                onBrowse: _routeHome,
                isTech: _isTech,
              ),
          },
        ),
      ),
    );
  }

  String? _validateProfile(bool isEn) {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (name.length < 2 || name.length > 60) {
      return _t(
        isEn,
        'Enter a valid full name between 2 and 60 characters.',
        'أدخل اسماً صحيحاً بين حرفين و60 حرفاً.',
      );
    }
    if (!_isSocial && !emailRegex.hasMatch(email)) {
      return _t(
        isEn,
        'Enter a valid email address.',
        'أدخل بريداً إلكترونياً صحيحاً.',
      );
    }
    if (!_isSocial && password.length < 8) {
      return _t(
        isEn,
        'Password must be at least 8 characters.',
        'يجب أن تكون كلمة المرور 8 أحرف على الأقل.',
      );
    }
    return null;
  }

  Future<void> _socialSignIn({
    required bool isEn,
    required Future<UserCredential?> Function() signIn,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cred = await signIn();
      if (cred == null) {
        // User cancelled.
        if (mounted) setState(() => _busy = false);
        return;
      }
      // AuthGate listens to authStateChanges(). If the social account already
      // has a complete profile, it routes to the home screen; otherwise it
      // force-signs-out and queues a LoginScreen snackbar — the user then
      // re-enters via LoginScreen's social-signin handler with prefillUid set.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t(
          isEn,
          'Social sign-in failed. Please try again.',
          'فشل تسجيل الدخول الاجتماعي. حاول مرة أخرى.',
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Shared chrome
// ───────────────────────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int current;
  final int total;
  final bool dark;
  const _StepDots({
    required this.current,
    required this.total,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(total, (i) {
        final active = i == current;
        final done = i < current;
        final Color color;
        if (done) {
          color = dark ? Colors.white.withOpacity(0.9) : _sBlue;
        } else if (active) {
          color = dark ? Colors.white : _sBlue;
        } else {
          color = dark ? Colors.white.withOpacity(0.3) : _sDividerSoft;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsetsDirectional.only(end: i == total - 1 ? 0 : 6),
          width: active ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _FlowTop extends StatelessWidget {
  final VoidCallback? onBack;
  final int dot;
  final int totalDots;
  const _FlowTop({
    required this.onBack,
    required this.dot,
    required this.totalDots,
  });

  @override
  Widget build(BuildContext context) {
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(
        children: [
          _RoundIconButton(
            onTap: onBack,
            child: Icon(
              isLtr ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
              size: 16,
              color: _sInk,
            ),
          ),
          const Spacer(),
          _StepDots(current: dot, total: totalDots),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: _sFieldBg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GradButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final double height;
  final double fontSize;
  const _GradButton({
    required this.label,
    required this.onTap,
    this.busy = false,
    this.height = 54,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap == null && !busy ? null : _gradBtn,
          color: onTap == null && !busy ? Colors.grey.shade400 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x596C3FA0),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  final Widget child;
  const _Medallion({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x2E6C3FA0), Color(0x006C3FA0)],
                stops: [0.0, 0.7],
              ),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: _gradBtn,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x596C3FA0),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Phone screen
// ───────────────────────────────────────────────────────────────────────────

class _PhoneScreen extends StatelessWidget {
  final bool isEn;
  final TextEditingController phoneCtrl;
  final int dot;
  final int totalDots;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSocialGoogle;
  final VoidCallback onSocialApple;
  final bool busy;

  const _PhoneScreen({
    required this.isEn,
    required this.phoneCtrl,
    required this.dot,
    required this.totalDots,
    required this.error,
    required this.onBack,
    required this.onContinue,
    required this.onSocialGoogle,
    required this.onSocialApple,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final showApple = kIsWeb || Platform.isIOS;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _gradSoft),
      child: SafeArea(
        child: Column(
          children: [
            _FlowTop(onBack: onBack, dot: dot, totalDots: totalDots),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    _Medallion(
                      child: Icon(Icons.phone_iphone,
                          color: Colors.white, size: 38),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _t('What\'s your\nphone number?',
                          'ما هو رقم\nهاتفك؟'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _sInk,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _t(
                        'We\'ll text you a 6-digit code to verify it\'s really you.',
                        'سنرسل لك رمزاً مكوّناً من 6 أرقام للتحقق من هويتك.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _sMuted,
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _PhoneRow(controller: phoneCtrl),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  _GradButton(
                    label: _t('Continue', 'متابعة'),
                    onTap: onContinue,
                    busy: false,
                    height: 58,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: _sDividerSoft)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          _t('OR', 'أو'),
                          style: const TextStyle(
                            color: Color(0xFF9A97AE),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: _sDividerSoft)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (showApple) ...[
                        Expanded(
                          child: _SocialBtn(
                            label: 'Apple',
                            icon: const Icon(Icons.apple, color: _sInk),
                            onTap: busy ? null : onSocialApple,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: _SocialBtn(
                          label: 'Google',
                          icon: const _GoogleIcon(),
                          onTap: busy ? null : onSocialGoogle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _t(String en, String ar) => isEn ? en : ar;
}

class _PhoneRow extends StatefulWidget {
  final TextEditingController controller;
  const _PhoneRow({required this.controller});

  @override
  State<_PhoneRow> createState() => _PhoneRowState();
}

class _PhoneRowState extends State<_PhoneRow> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Country pill.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _sFieldBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D110C2E),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇪🇬', style: TextStyle(fontSize: 22, height: 1)),
              SizedBox(width: 8),
              Text(
                '+20',
                style: TextStyle(
                  color: _sInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                  size: 18, color: _sMuted),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Phone field.
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _sBlue, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x246C3FA0),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              cursorColor: _sBlue,
              cursorWidth: 2,
              style: const TextStyle(
                color: _sInk,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              decoration: const InputDecoration(
                hintText: '100 234 5678',
                hintStyle: TextStyle(
                  color: Color(0xFF9A97AE),
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: _sFieldBorder),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A110C2E),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 20, height: 20, child: Center(child: icon)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: _sInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _sFieldBorder),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// OTP screen
// ───────────────────────────────────────────────────────────────────────────

class _OtpScreen extends StatefulWidget {
  final bool isEn;
  final String phoneE164;
  final int dot;
  final int totalDots;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<String> onVerify;

  const _OtpScreen({
    required this.isEn,
    required this.phoneE164,
    required this.dot,
    required this.totalDots,
    required this.error,
    required this.onBack,
    required this.onVerify,
  });

  @override
  State<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<_OtpScreen> {
  late final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  late final List<FocusNode> _focus =
      List.generate(6, (_) => FocusNode());

  int _resendIn = 24;
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream<int>.periodic(const Duration(seconds: 1), (i) => i + 1);
    _ticker.listen((_) {
      if (!mounted) return;
      if (_resendIn > 0) setState(() => _resendIn -= 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();
  int get _filled => _ctrls.where((c) => c.text.isNotEmpty).length;

  void _onChanged(int i, String value) {
    if (value.isEmpty) {
      setState(() {});
      return;
    }
    if (value.length > 1) {
      // Pasted multi-char — distribute starting from i.
      for (int k = 0; k < value.length && i + k < _ctrls.length; k++) {
        _ctrls[i + k].text = value[k];
      }
      final last = (i + value.length - 1).clamp(0, _ctrls.length - 1);
      if (last + 1 < _ctrls.length) {
        _focus[last + 1].requestFocus();
      } else {
        _focus[last].unfocus();
      }
      setState(() {});
      return;
    }
    if (i + 1 < _ctrls.length) _focus[i + 1].requestFocus();
    setState(() {});
  }

  void _onBackspace(int i) {
    if (_ctrls[i].text.isEmpty && i > 0) {
      _focus[i - 1].requestFocus();
      _ctrls[i - 1].clear();
      setState(() {});
    }
  }

  String _t(String en, String ar) => widget.isEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _gradSoft),
      child: SafeArea(
        child: Column(
          children: [
            _FlowTop(
              onBack: widget.onBack,
              dot: widget.dot,
              totalDots: widget.totalDots,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    const _Medallion(
                      child: Icon(Icons.verified_user_rounded,
                          color: Colors.white, size: 42),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _t('Enter the code', 'أدخل الرمز'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _sInk,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text.rich(
                      TextSpan(
                        text: _t(
                          'We sent a 6-digit code to\n',
                          'أرسلنا رمزاً مكوّناً من 6 أرقام إلى\n',
                        ),
                        style: const TextStyle(
                          color: _sMuted,
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: -0.1,
                        ),
                        children: [
                          TextSpan(
                            text: widget.phoneE164,
                            style: const TextStyle(
                              color: _sInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _OtpRow(
                      ctrls: _ctrls,
                      focus: _focus,
                      activeIndex: _filled,
                      onChanged: _onChanged,
                      onBackspace: _onBackspace,
                    ),
                    const SizedBox(height: 28),
                    _ResendRow(
                      isEn: widget.isEn,
                      seconds: _resendIn,
                      onResend: _resendIn == 0
                          ? () => setState(() => _resendIn = 24)
                          : null,
                    ),
                    if (widget.error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: widget.error!),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _GradButton(
                label: _t('Verify', 'تحقّق'),
                onTap: () => widget.onVerify(_code),
                height: 58,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpRow extends StatelessWidget {
  final List<TextEditingController> ctrls;
  final List<FocusNode> focus;
  final int activeIndex;
  final void Function(int) onBackspace;
  final void Function(int, String) onChanged;
  const _OtpRow({
    required this.ctrls,
    required this.focus,
    required this.activeIndex,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final filled = ctrls[i].text.isNotEmpty;
        final active = i == activeIndex;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 5 ? 0 : 8),
            child: AspectRatio(
              aspectRatio: 1,
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace) {
                    onBackspace(i);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: filled ? Colors.white : _sFieldBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: active ? _sBlue : _sFieldBorder,
                      width: active ? 2 : 1,
                    ),
                    boxShadow: [
                      if (active)
                        const BoxShadow(
                          color: Color(0x2E6C3FA0),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        )
                      else if (filled)
                        const BoxShadow(
                          color: Color(0x0F110C2E),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                    ],
                  ),
                  child: TextField(
                    controller: ctrls[i],
                    focusNode: focus[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    cursorColor: _sBlue,
                    style: const TextStyle(
                      color: _sInk,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) {
                      if (v.length > 1) {
                        onChanged(i, v);
                      } else {
                        onChanged(i, v);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ResendRow extends StatelessWidget {
  final bool isEn;
  final int seconds;
  final VoidCallback? onResend;
  const _ResendRow({
    required this.isEn,
    required this.seconds,
    required this.onResend,
  });

  String _label() {
    final mm = (seconds ~/ 60).toString();
    final ss = (seconds % 60).toString().padLeft(2, '0');
    if (seconds == 0) return isEn ? 'Resend code' : 'إعادة الإرسال';
    return isEn ? 'Resend in $mm:$ss' : 'إعادة بعد $mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isEn ? 'Didn\'t get it?  ' : 'لم تستلمه؟  ',
          style: const TextStyle(color: _sMuted, fontSize: 15),
        ),
        TextButton(
          onPressed: onResend,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _label(),
            style: const TextStyle(
              color: _sBlue,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Profile screen
// ───────────────────────────────────────────────────────────────────────────

class _ProfileScreen extends StatefulWidget {
  final bool isEn;
  final bool isSocial;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final int dot;
  final int totalDots;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _ProfileScreen({
    required this.isEn,
    required this.isSocial,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.dot,
    required this.totalDots,
    required this.error,
    required this.onBack,
    required this.onContinue,
  });

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  bool _hidePassword = true;

  String _t(String en, String ar) => widget.isEn ? en : ar;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '·';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  int _strength(String pwd) {
    if (pwd.isEmpty) return 0;
    int s = 0;
    if (pwd.length >= 8) s += 1;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) s += 1;
    if (RegExp(r'[0-9]').hasMatch(pwd)) s += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) s += 1;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength(widget.passwordCtrl.text);
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _gradSoft),
      child: SafeArea(
        child: Column(
          children: [
            _FlowTop(
              onBack: widget.onBack,
              dot: widget.dot,
              totalDots: widget.totalDots,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Tell us about\nyourself', 'حدّثنا عن\nنفسك'),
                      style: const TextStyle(
                        color: _sInk,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t(
                        'So technicians know who they\'re serving.',
                        'حتى يعرف الفنيّون من يخدمون.',
                      ),
                      style: const TextStyle(
                        color: _sMuted,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(child: _avatar(strength)),
                    const SizedBox(height: 24),
                    _LabeledField(
                      label: _t('FULL NAME', 'الاسم الكامل'),
                      child: TextField(
                        controller: widget.nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: _sInk, fontSize: 16),
                        decoration: _innerDecoration(
                          icon: Icons.person_outline,
                          hint: _t('Layla Hassan', 'ليلى حسن'),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    _LabeledField(
                      label: _t('EMAIL', 'البريد الإلكتروني'),
                      child: TextField(
                        controller: widget.emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !widget.isSocial,
                        style: const TextStyle(color: _sInk, fontSize: 16),
                        decoration: _innerDecoration(
                          icon: Icons.alternate_email,
                          hint: 'layla@example.com',
                        ),
                      ),
                    ),
                    if (!widget.isSocial)
                      _LabeledField(
                        label: _t('PASSWORD', 'كلمة المرور'),
                        child: TextField(
                          controller: widget.passwordCtrl,
                          obscureText: _hidePassword,
                          style: const TextStyle(color: _sInk, fontSize: 16),
                          decoration: _innerDecoration(
                            icon: Icons.lock_outline,
                            hint: '••••••••',
                            suffix: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _sMuted,
                                size: 18,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    if (!widget.isSocial)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(4, (i) {
                                Color c;
                                if (i + 1 > strength) {
                                  c = _sFieldBorder;
                                } else if (strength <= 2) {
                                  c = const Color(0xFF15803D);
                                } else if (strength == 3) {
                                  c = _sBlueLight;
                                } else {
                                  c = _sBlue;
                                }
                                return Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: EdgeInsetsDirectional.only(
                                        end: i == 3 ? 0 : 6),
                                    decoration: BoxDecoration(
                                      color: c,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _strengthLabel(strength),
                              style: const TextStyle(
                                color: _sMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: widget.error!),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _GradButton(
                label: _t('Continue', 'متابعة'),
                onTap: widget.onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _strengthLabel(int s) {
    switch (s) {
      case 0:
        return _t('Pick a password.', 'اختر كلمة مرور.');
      case 1:
        return _t('Weak — keep going.', 'ضعيفة — استمر.');
      case 2:
        return _t('Decent — could be stronger.', 'مقبولة — يمكن أن تكون أقوى.');
      case 3:
        return _t('Good.', 'جيدة.');
      default:
        return _t('Strong — you\'re good to go.', 'قوية — جاهز للمتابعة.');
    }
  }

  Widget _avatar(int strength) {
    final initials = _initials(widget.nameCtrl.text);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _gradBtn,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4C6C3FA0),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -2,
            end: -2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                color: _sBlue,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _innerDecoration({
  required IconData icon,
  required String hint,
  Widget? suffix,
}) {
  return InputDecoration(
    isCollapsed: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
    border: InputBorder.none,
    icon: Icon(icon, color: _sMuted, size: 18),
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9A97AE), fontSize: 16),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
  );
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B6880),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _sFieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _sFieldBorder),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Service screen (technician only)
// ───────────────────────────────────────────────────────────────────────────

class _ServiceScreen extends StatelessWidget {
  final bool isEn;
  final String selected;
  final int dot;
  final int totalDots;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<String> onSelect;
  final VoidCallback onContinue;

  const _ServiceScreen({
    required this.isEn,
    required this.selected,
    required this.dot,
    required this.totalDots,
    required this.error,
    required this.onBack,
    required this.onSelect,
    required this.onContinue,
  });

  static const List<({String key, String en, String ar, IconData icon})>
      _services = [
    (key: 'plumbing', en: 'Plumbing', ar: 'سباكة', icon: Icons.plumbing),
    (
      key: 'electricity',
      en: 'Electrical',
      ar: 'كهرباء',
      icon: Icons.electrical_services
    ),
    (key: 'ac', en: 'AC', ar: 'تكييف', icon: Icons.ac_unit),
    (key: 'carpentry', en: 'Carpentry', ar: 'نجارة', icon: Icons.handyman),
    (
      key: 'finishing',
      en: 'Finishing',
      ar: 'تشطيبات',
      icon: Icons.format_paint
    ),
    (
      key: 'aluminum',
      en: 'Aluminum',
      ar: 'ألوميتال',
      icon: Icons.window
    ),
    (
      key: 'small_appliances',
      en: 'Appliances',
      ar: 'الأجهزة المنزلية',
      icon: Icons.kitchen
    ),
    (
      key: 'pest_control',
      en: 'Pest control',
      ar: 'مكافحة حشرات',
      icon: Icons.pest_control
    ),
  ];

  String _t(String en, String ar) => isEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _gradSoft),
      child: SafeArea(
        child: Column(
          children: [
            _FlowTop(onBack: onBack, dot: dot, totalDots: totalDots),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Pick your\nservice', 'اختر\nخدمتك'),
                      style: const TextStyle(
                        color: _sInk,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t(
                        'Customers will see this on your profile. You can add more later.',
                        'سيراها العملاء في ملفّك. يمكنك إضافة المزيد لاحقاً.',
                      ),
                      style: const TextStyle(
                        color: _sMuted,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _services.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.7,
                      ),
                      itemBuilder: (_, i) {
                        final s = _services[i];
                        final isSelected = selected == s.key;
                        return _ServiceTile(
                          icon: s.icon,
                          label: _t(s.en, s.ar),
                          selected: isSelected,
                          onTap: () => onSelect(s.key),
                        );
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _GradButton(
                label: _t('Continue', 'متابعة'),
                onTap: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : _sFieldBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? _sBlue : _sFieldBorder,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x246C3FA0),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: _gradBtn,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _sInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Location screen (demo coordinates)
// ───────────────────────────────────────────────────────────────────────────

class _LocationScreen extends StatelessWidget {
  final bool isEn;
  final bool hasLocation;
  final bool busy;
  final int dot;
  final int totalDots;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onUseMyLocation;
  final VoidCallback onManual;

  const _LocationScreen({
    required this.isEn,
    required this.hasLocation,
    required this.busy,
    required this.dot,
    required this.totalDots,
    required this.error,
    required this.onBack,
    required this.onUseMyLocation,
    required this.onManual,
  });

  String _t(String en, String ar) => isEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Faux map background.
        const _FauxMap(),
        // Bottom-fade so the sheet reads cleanly.
        const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Colors.white],
                  stops: [0.0, 0.6],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _FlowTop(onBack: onBack, dot: dot, totalDots: totalDots),
              const Spacer(),
              // Bottom sheet.
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 40,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: _sDividerSoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Text(
                      _t(
                        'Where should we send\nthe technician?',
                        'إلى أين يتجه الفنيّ؟',
                      ),
                      style: const TextStyle(
                        color: _sInk,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'Turn on location so we can match you with nearby '
                        'technicians in minutes.',
                        'فعّل الموقع حتى نوصلك بفنّيين قريبين خلال دقائق.',
                      ),
                      style: const TextStyle(
                        color: _sMuted,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LocationRow(
                      isEn: isEn,
                      selected: hasLocation,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 18),
                    _GradButton(
                      label: _t('Pin on map', 'حدد على الخريطة'),
                      onTap: onUseMyLocation,
                      busy: busy,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: TextButton(
                        onPressed: busy ? null : onManual,
                        child: Text(
                          _t('Skip for now', 'تخطّ الآن'),
                          style: const TextStyle(
                            color: _sMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  final bool isEn;
  final bool selected;
  const _LocationRow({required this.isEn, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _sFieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _sFieldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: _gradBtn,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? _demoLocationLabel : _demoLocationLabelAr,
                  style: const TextStyle(
                    color: _sInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEn ? _demoLocationSub : _demoLocationSubAr,
                  style: const TextStyle(color: _sMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selected ? _sBlue : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _sBlue : const Color(0xFFB6B0CE),
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
        ],
      ),
    );
  }
}

class _FauxMap extends StatelessWidget {
  const _FauxMap();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEEF0F7), Color(0xFFE3E7F2)],
            ),
          ),
        ),
        CustomPaint(painter: _MapPainter(), size: Size.infinite),
        // Pulse pin centered upper portion.
        Align(
          alignment: const Alignment(0, -0.25),
          child: SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x2E6C3FA0), Color(0x006C3FA0)],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
                _Pin(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          gradient: _gradBtn,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(23),
            topRight: Radius.circular(23),
            bottomLeft: Radius.circular(23),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x666C3FA0),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Roads (white base + lavender stroke).
    void road(Path p, double white, double lav, Color c) {
      canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white
          ..strokeWidth = white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        p,
        Paint()
          ..color = c
          ..strokeWidth = lav
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final road1 = Path()
      ..moveTo(-20, h * 0.22)
      ..quadraticBezierTo(w * 0.3, h * 0.17, w * 0.65, h * 0.27)
      ..quadraticBezierTo(w * 0.85, h * 0.32, w + 40, h * 0.32);
    road(road1, 14, 12, const Color(0xFFD9DEED));

    final road2 = Path()
      ..moveTo(w * 0.15, -20)
      ..quadraticBezierTo(w * 0.2, h * 0.25, w * 0.5, h * 0.42)
      ..quadraticBezierTo(w * 0.75, h * 0.6, w * 0.95, h + 20);
    road(road2, 16, 14, const Color(0xFFD9DEED));

    final road3 = Path()
      ..moveTo(-20, h * 0.65)
      ..quadraticBezierTo(w * 0.5, h * 0.6, w + 40, h * 0.7);
    road(road3, 10, 8, const Color(0xFFD9DEED));

    // City blocks.
    final blockPaint = Paint()..color = const Color(0xFFDDE2EF);
    final List<Rect> blocks = [
      Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.2, h * 0.07),
      Rect.fromLTWH(w * 0.4, h * 0.07, w * 0.18, h * 0.06),
      Rect.fromLTWH(w * 0.72, h * 0.05, w * 0.25, h * 0.1),
      Rect.fromLTWH(w * 0.07, h * 0.34, w * 0.25, h * 0.15),
      Rect.fromLTWH(w * 0.65, h * 0.46, w * 0.3, h * 0.11),
      Rect.fromLTWH(w * 0.05, h * 0.7, w * 0.3, h * 0.09),
    ];
    for (final r in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        blockPaint,
      );
    }

    // Park.
    final park = Paint()..color = const Color(0xFFC9E4CD);
    canvas.drawCircle(Offset(w * 0.32, h * 0.55), 44, park);
    canvas.drawCircle(Offset(w * 0.42, h * 0.6), 30, park);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ───────────────────────────────────────────────────────────────────────────
// Success screen
// ───────────────────────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  final bool isEn;
  final String name;
  final bool isTech;
  final VoidCallback onBrowse;

  const _SuccessScreen({
    required this.isEn,
    required this.name,
    required this.isTech,
    required this.onBrowse,
  });

  String _t(String en, String ar) => isEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    final perks = isTech
        ? const [
            (
              en: ('Steady jobs nearby', 'Nearby customers, ranked by need'),
              ar: ('فرص عمل قريبة', 'عملاء بالقرب منك مرتّبين حسب الأولوية'),
            ),
            (
              en: ('Fast payouts', 'Get paid right after each job is closed'),
              ar: ('مدفوعات سريعة', 'تتقاضى أتعابك فور إنهاء كل مهمة'),
            ),
          ]
        : const [
            (
              en: ('Vetted technicians', 'Background-checked, rated 4.7+'),
              ar: ('فنيّون موثوقون', 'تم التحقق منهم وتقييمهم +4.7'),
            ),
            (
              en: ('Transparent pricing', 'Inspection from 200 EGP'),
              ar: ('أسعار شفافة', 'كشف من 200 جنيه'),
            ),
          ];

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _gradBtn),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepDots(current: 4, total: 5, dark: true),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SuccessMedallion(),
                    const SizedBox(height: 32),
                    Text(
                      _t(
                        'You\'re all set,\n${firstName.isEmpty ? 'friend' : firstName}.',
                        'كل شيء جاهز،\n${firstName.isEmpty ? 'صديقي' : firstName}.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        isTech
                            ? _t(
                                'Your account is ready. Let\'s get you your first job.',
                                'حسابك جاهز. لنحصل لك على أول مهمة.',
                              )
                            : _t(
                                'Your account is ready. Let\'s get your first service booked.',
                                'حسابك جاهز. لنحجز لك أول خدمة.',
                              ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        for (final p in perks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PerkRow(
                              title: isEn ? p.en.$1 : p.ar.$1,
                              subtitle: isEn ? p.en.$2 : p.ar.$2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: onBrowse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _sBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isTech
                        ? _t('Open dashboard', 'افتح لوحتي')
                        : _t('Browse services', 'تصفّح الخدمات'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessMedallion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.22),
                  Colors.white.withOpacity(0),
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.14),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _sBlue,
                  size: 44,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PerkRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
