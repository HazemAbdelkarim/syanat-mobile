import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_service.dart';
import 'main.dart' show AppLocale;
import 'user_home_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class CustomerSignupFlow extends StatefulWidget {
  final String? prefillUid;
  final String prefillEmail;
  final String prefillName;

  const CustomerSignupFlow({
    super.key,
    this.prefillUid,
    this.prefillEmail = '',
    this.prefillName = '',
  });

  @override
  State<CustomerSignupFlow> createState() => _CustomerSignupFlowState();
}

class _CustomerSignupFlowState extends State<CustomerSignupFlow> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  bool _forward = true;
  String? _submissionError;

  String? _nameError;
  String? _phoneError;
  String? _cityError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool get _isSocialMode => widget.prefillUid != null;
  int get _totalSteps => _isSocialMode ? 2 : 3;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.prefillName;
    _emailController.text = widget.prefillEmail;
    _nameController.addListener(() => _clearError('name'));
    _phoneController.addListener(() => _clearError('phone'));
    _cityController.addListener(() => _clearError('city'));
    _emailController.addListener(() => _clearError('email'));
    _passwordController.addListener(() => _clearError('password'));
    _confirmPasswordController.addListener(() => _clearError('confirm'));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _t(bool isEn, String en, String ar) => isEn ? en : ar;

  void _switchLanguage() {
    final notifier = AppLocale.of(context);
    notifier.value = notifier.value.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  }

  void _clearError(String field) {
    if (!mounted) return;
    setState(() {
      _submissionError = null;
      switch (field) {
        case 'name':
          _nameError = null;
          break;
        case 'phone':
          _phoneError = null;
          break;
        case 'city':
          _cityError = null;
          break;
        case 'email':
          _emailError = null;
          break;
        case 'password':
          _passwordError = null;
          break;
        case 'confirm':
          _confirmPasswordError = null;
          break;
      }
    });
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _forward = false;
      _currentStep -= 1;
      _submissionError = null;
    });
  }

  bool _validateCurrentStep(bool isEn) {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final phoneRegex = RegExp(r'^\+201[0125]\d{8}$');
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    bool valid = true;

    setState(() {
      _submissionError = null;
      if (_currentStep == 0) {
        _nameError = null;
        _phoneError = null;

        if (name.length < 2 || name.length > 60 || _nameController.text != name) {
          _nameError = _t(
            isEn,
            'Enter a valid full name between 2 and 60 characters.',
            'أدخل اسماً صحيحاً بين حرفين و60 حرفاً.',
          );
          valid = false;
        }
        if (!phoneRegex.hasMatch(phone)) {
          _phoneError = _t(
            isEn,
            'Use Egyptian format: +201XXXXXXXXX',
            'استخدم الصيغة المصرية: +201XXXXXXXXX',
          );
          valid = false;
        }
      } else if (_currentStep == 1) {
        _cityError = null;
        _emailError = null;

        if (city.length < 2) {
          _cityError = _t(isEn, 'Enter a valid city name.', 'أدخل اسم مدينة صحيح.');
          valid = false;
        }
        if (!_isSocialMode && !emailRegex.hasMatch(email)) {
          _emailError = _t(isEn, 'Enter a valid email address.', 'أدخل بريداً إلكترونياً صحيحاً.');
          valid = false;
        }
      } else {
        _passwordError = null;
        _confirmPasswordError = null;

        if (password.length < 8) {
          _passwordError = _t(
            isEn,
            'Password must be at least 8 characters.',
            'يجب أن تكون كلمة المرور 8 أحرف على الأقل.',
          );
          valid = false;
        }
        if (confirmPassword != password) {
          _confirmPasswordError = _t(isEn, 'Passwords do not match.', 'كلمتا المرور غير متطابقتين.');
          if (_passwordError == null) {
            _passwordError = _confirmPasswordError;
          }
          valid = false;
        }
      }
    });

    return valid;
  }

  Future<void> _nextOrSubmit() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (!_validateCurrentStep(isEn)) return;

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _forward = true;
        _currentStep += 1;
      });
      return;
    }

    await _submit(isEn);
  }

  Future<void> _submit(bool isEn) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _submissionError = null;
    });

    User? createdAuthUser;

    try {
      final username = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final city = _cityController.text.trim();
      final lang = isEn ? 'en' : 'ar';
      final String uid;
      final String email;

      if (_isSocialMode) {
        uid = widget.prefillUid!;
        email = widget.prefillEmail.trim().toLowerCase();
      } else {
        final credential = await FirebaseService.auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
        );
        final user = credential.user;
        if (user == null) throw Exception(_t(isEn, 'Unable to create account.', 'تعذر إنشاء الحساب.'));
        createdAuthUser = user;
        uid = user.uid;
        email = _emailController.text.trim().toLowerCase();
      }

      await FirebaseService.createUser(
        uid: uid,
        email: email,
        username: username,
        role: 'customer',
        phone: phone,
        city: city,
        language: lang,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserHomeScreen()),
      );
    } catch (e) {
      if (createdAuthUser != null) {
        try {
          await createdAuthUser!.delete();
        } catch (_) {
          await FirebaseService.auth.signOut();
        }
      }
      if (!mounted) return;
      debugPrint('Customer signup error: $e');
      setState(() {
        _submissionError = _t(
          isEn,
          'Could not create your account. Please try again.',
          'تعذر إنشاء الحساب. يرجى المحاولة مرة أخرى.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final progress = (_currentStep + 1) / _totalSteps;

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
                      children: [
                        IconButton(
                          onPressed: _isLoading ? null : _goBack,
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        Expanded(
                          child: Text(
                            _t(isEn, 'Step ${_currentStep + 1} of $_totalSteps', 'الخطوة ${_currentStep + 1} من $_totalSteps'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: _switchLanguage,
                          icon: const Icon(Icons.language, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
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
                              LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                color: syanatBlue,
                                backgroundColor: syanatBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  _t(isEn, 'Step ${_currentStep + 1} of $_totalSteps', 'الخطوة ${_currentStep + 1} من $_totalSteps'),
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _stepTitle(isEn),
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _stepSubtitle(isEn),
                                style: const TextStyle(fontSize: 14, color: Colors.black54),
                              ),
                              if (_submissionError != null) ...[
                                const SizedBox(height: 20),
                                _messageBox(_submissionError!),
                              ],
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                transitionBuilder: (child, animation) {
                                  final begin = Offset(_forward ? 0.12 : -0.12, 0);
                                  return SlideTransition(
                                    position: Tween<Offset>(begin: begin, end: Offset.zero).animate(animation),
                                    child: FadeTransition(opacity: animation, child: child),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey(_currentStep),
                                  child: _buildStep(isEn),
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _nextOrSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: syanatBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _currentStep == _totalSteps - 1
                                              ? _t(isEn, 'Create Account', 'إنشاء الحساب')
                                              : _t(isEn, 'Next', 'التالي'),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  String _stepTitle(bool isEn) {
    if (_currentStep == 0) return _t(isEn, 'Your basic details', 'بياناتك الأساسية');
    if (_currentStep == 1) return _t(isEn, 'Contact and city', 'التواصل والمدينة');
    return _t(isEn, 'Secure your account', 'تأمين الحساب');
  }

  String _stepSubtitle(bool isEn) {
    if (_currentStep == 0) {
      return _t(isEn, 'Start with your full name and phone number.', 'ابدأ باسمك الكامل ورقم هاتفك.');
    }
    if (_currentStep == 1) {
      return _isSocialMode
          ? _t(isEn, 'Add your city and review your social email.', 'أضف مدينتك وراجع بريدك الاجتماعي.')
          : _t(isEn, 'Tell us where you are and how to reach you.', 'أخبرنا أين أنت وكيف يمكن الوصول إليك.');
    }
    return _t(isEn, 'Choose a password for your new account.', 'اختر كلمة مرور لحسابك الجديد.');
  }

  Widget _buildStep(bool isEn) {
    if (_currentStep == 0) {
      return Column(
        children: [
          _buildModernTextField(
            controller: _nameController,
            label: _t(isEn, 'Full Name', 'الاسم الكامل'),
            icon: Icons.person,
            errorText: _nameError,
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _phoneController,
            label: _t(isEn, 'Phone Number', 'رقم الهاتف'),
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            errorText: _phoneError,
          ),
        ],
      );
    }

    if (_currentStep == 1) {
      return Column(
        children: [
          _buildModernTextField(
            controller: _cityController,
            label: _t(isEn, 'City', 'المدينة'),
            icon: Icons.location_city,
            errorText: _cityError,
          ),
          const SizedBox(height: 16),
          _isSocialMode
              ? _readOnlyEmailChip(isEn)
              : _buildModernTextField(
                  controller: _emailController,
                  label: _t(isEn, 'Email', 'البريد الإلكتروني'),
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),
        ],
      );
    }

    return Column(
      children: [
        _buildModernTextField(
          controller: _passwordController,
          label: _t(isEn, 'Password', 'كلمة المرور'),
          icon: Icons.lock,
          obscure: true,
          errorText: _passwordError,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _confirmPasswordController,
          label: _t(isEn, 'Confirm Password', 'تأكيد كلمة المرور'),
          icon: Icons.lock_outline,
          obscure: true,
          errorText: _confirmPasswordError,
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: hasError ? Colors.red.shade400 : Colors.grey.shade300,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
              prefixIcon: Icon(icon, color: Colors.black54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
        if (errorText != null) _messageBox(errorText, topMargin: 6),
      ],
    );
  }

  Widget _readOnlyEmailChip(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(isEn, 'Social Email', 'البريد الاجتماعي'),
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.prefillEmail,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBox(String message, {double topMargin = 0}) {
    return Container(
      margin: EdgeInsets.only(top: topMargin),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300),
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
