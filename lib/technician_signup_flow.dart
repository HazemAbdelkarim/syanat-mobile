import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_service.dart';
import 'main.dart' show AppLocale;
import 'tech_home_screen.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class TechnicianSignupFlow extends StatefulWidget {
  final String? prefillUid;
  final String prefillEmail;
  final String prefillName;

  const TechnicianSignupFlow({
    super.key,
    this.prefillUid,
    this.prefillEmail = '',
    this.prefillName = '',
  });

  @override
  State<TechnicianSignupFlow> createState() => _TechnicianSignupFlowState();
}

class _TechnicianSignupFlowState extends State<TechnicianSignupFlow> {
  static const Map<String, String> arabicToServiceKey = {
    'فني تكييف': 'ac',
    'سباك': 'plumbing',
    'كهربائي': 'electricity',
    'نقاش': 'finishing',
    'نجار': 'carpentry',
    'تركيب ألوميتال / سلك': 'aluminum',
    'فني غسالات': 'small_appliances',
    'صيانة المسابح': 'pest_control',
    'تصليح مواتير مياه': 'plumbing',
    'صيانة خزانات المياه': 'plumbing',
    'فني رخام': 'finishing',
    'فني سخانات': 'small_appliances',
    'فني دشات': 'plumbing',
  };

  final List<String> technicianServices = [
    'سباك',
    'كهربائي',
    'نقاش',
    'نجار',
    'فني دشات',
    'فني تكييف',
    'تركيب ألوميتال / سلك',
    'فني غسالات',
    'صيانة المسابح',
    'تصليح مواتير مياه',
    'صيانة خزانات المياه',
    'فني رخام',
    'فني سخانات',
  ];

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _picker = ImagePicker();

  int _currentStep = 0;
  bool _isLoading = false;
  bool _forward = true;
  String? _service;
  XFile? _profileImage;
  Position? _currentPosition;

  String? _submissionError;
  String? _warningMessage;
  String? _nameError;
  String? _phoneError;
  String? _cityError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _serviceError;

  bool get _isSocialMode => widget.prefillUid != null;
  int get _totalSteps => _isSocialMode ? 4 : 5;

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
      if (field != 'warning') _warningMessage = null;
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
        case 'service':
          _serviceError = null;
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
      _warningMessage = null;
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
    final serviceStep = _isSocialMode ? 2 : 3;
    bool valid = true;

    setState(() {
      _submissionError = null;
      if (_currentStep != _totalSteps - 1) _warningMessage = null;

      if (_currentStep == 0) {
        _nameError = null;
        _phoneError = null;
        if (name.length < 2 || name.length > 60 || _nameController.text != name) {
          _nameError = _t(isEn, 'Enter a valid full name between 2 and 60 characters.', 'أدخل اسماً صحيحاً بين حرفين و60 حرفاً.');
          valid = false;
        }
        if (!phoneRegex.hasMatch(phone)) {
          _phoneError = _t(isEn, 'Use Egyptian format: +201XXXXXXXXX', 'استخدم الصيغة المصرية: +201XXXXXXXXX');
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
      } else if (!_isSocialMode && _currentStep == 2) {
        _passwordError = null;
        _confirmPasswordError = null;
        if (password.length < 8) {
          _passwordError = _t(isEn, 'Password must be at least 8 characters.', 'يجب أن تكون كلمة المرور 8 أحرف على الأقل.');
          valid = false;
        }
        if (confirmPassword != password) {
          _confirmPasswordError = _t(isEn, 'Passwords do not match.', 'كلمتا المرور غير متطابقتين.');
          if (_passwordError == null) _passwordError = _confirmPasswordError;
          valid = false;
        }
      } else if (_currentStep == serviceStep) {
        _serviceError = null;
        if (_service == null || _service!.trim().isEmpty) {
          _serviceError = _t(isEn, 'Select your service specialty.', 'اختر تخصصك المهني.');
          valid = false;
        }
      }
    });

    return valid;
  }

  Future<void> _nextOrSubmit() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (_currentStep != _totalSteps - 1 && !_validateCurrentStep(isEn)) return;

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _forward = true;
        _currentStep += 1;
      });
      return;
    }

    await _submit(isEn);
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null || !mounted) return;
      setState(() {
        _profileImage = picked;
        _warningMessage = null;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _warningMessage = _t(
          isEn,
          'Camera access denied. Please allow it in settings.',
          'تم رفض الوصول إلى الكاميرا. يرجى السماح به في الإعدادات.',
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _warningMessage = _t(
          isEn,
          'Photo selection failed. Please try again.',
          'فشل اختيار الصورة. حاول مرة أخرى.',
        );
      });
    }
  }

  Future<void> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }
    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _submit(bool isEn) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _submissionError = null;
    });

    User? createdAuthUser;

    try {
      await _getLocation();
      if (!mounted) return;

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

      String photoUrl = '';
      if (_profileImage != null) {
        try {
          photoUrl = await FirebaseService.uploadPhoto(
            _profileImage!,
            folder: 'techProfiles',
          ).timeout(const Duration(seconds: 20));
        } catch (_) {
          if (mounted) {
            setState(() {
              _warningMessage = _t(
                isEn,
                'Photo could not be uploaded. You can update it later.',
                'تعذّر رفع الصورة. يمكنك تحديثها لاحقاً.',
              );
            });
          }
        }
      }

      final serviceKey = arabicToServiceKey[_service!] ?? _service!;
      await FirebaseService.createTechnician(
        uid: uid,
        email: email,
        username: username,
        phone: phone,
        serviceId: serviceKey,
        city: city,
        language: lang,
        photoUrl: photoUrl,
      );

      if (_currentPosition != null) {
        await FirebaseService.firestore.collection('users').doc(uid).set({
          'location': GeoPoint(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TechHomeScreen()),
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
      setState(() {
      debugPrint('Technician signup error: $e');
        _submissionError = _t(isEn, 'Could not create your technician account. Please try again.', 'تعذر إنشاء حساب الفني. يرجى المحاولة مرة أخرى.');
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
                                _messageBox(_submissionError!, isWarning: false),
                              ],
                              if (_warningMessage != null) ...[
                                const SizedBox(height: 12),
                                _messageBox(_warningMessage!, isWarning: true),
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
                              Row(
                                children: [
                                  if (_currentStep == _totalSteps - 1) ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () async {
                                                setState(() => _warningMessage = null);
                                                await _submit(isEn);
                                              },
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(52),
                                          side: BorderSide(color: Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: Text(
                                          _t(isEn, 'Skip', 'تخطي'),
                                          style: const TextStyle(color: syanatBlue, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: SizedBox(
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
                                  ),
                                ],
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
    final serviceStep = _isSocialMode ? 2 : 3;
    if (_currentStep == 0) return _t(isEn, 'Your basic details', 'بياناتك الأساسية');
    if (_currentStep == 1) return _t(isEn, 'Contact and city', 'التواصل والمدينة');
    if (!_isSocialMode && _currentStep == 2) return _t(isEn, 'Secure your account', 'تأمين الحساب');
    if (_currentStep == serviceStep) return _t(isEn, 'Choose your specialty', 'اختر تخصصك');
    return _t(isEn, 'Add a Profile Photo', 'أضف صورة شخصية');
  }

  String _stepSubtitle(bool isEn) {
    final serviceStep = _isSocialMode ? 2 : 3;
    if (_currentStep == 0) {
      return _t(isEn, 'Start with your full name and phone number.', 'ابدأ باسمك الكامل ورقم هاتفك.');
    }
    if (_currentStep == 1) {
      return _isSocialMode
          ? _t(isEn, 'Add your city and review your social email.', 'أضف مدينتك وراجع بريدك الاجتماعي.')
          : _t(isEn, 'Tell us where you work and how clients reach you.', 'أخبرنا أين تعمل وكيف يتواصل العملاء معك.');
    }
    if (!_isSocialMode && _currentStep == 2) {
      return _t(isEn, 'Choose a password for your technician account.', 'اختر كلمة مرور لحساب الفني.');
    }
    if (_currentStep == serviceStep) {
      return _t(isEn, 'Your specialty determines which jobs you receive.', 'تخصصك يحدد الوظائف التي تصلك.');
    }
    return _t(
      isEn,
      'Help customers recognize you. You can add a photo now or skip.',
      'ساعد العملاء على التعرف عليك. يمكنك إضافة صورة الآن أو التخطي.',
    );
  }

  Widget _buildStep(bool isEn) {
    final serviceStep = _isSocialMode ? 2 : 3;

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

    if (!_isSocialMode && _currentStep == 2) {
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

    if (_currentStep == serviceStep) {
      return Column(
        children: [
          _buildModernDropdown(
            value: _service,
            label: _t(isEn, 'Service Specialty', 'التخصص'),
            icon: Icons.build,
            errorText: _serviceError,
            items: technicianServices
                .map((service) => DropdownMenuItem<String>(
                      value: service,
                      child: Text(service),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _service = value;
                _serviceError = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _t(isEn, 'Your specialty determines which jobs you receive.', 'تخصصك يحدد الوظائف التي تصلك.'),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    ImageProvider? preview;
    if (_profileImage != null) {
      preview = kIsWeb ? NetworkImage(_profileImage!.path) : FileImage(File(_profileImage!.path));
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: preview,
          child: preview == null ? Icon(Icons.person, size: 60, color: Colors.grey.shade600) : null,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _pickProfileImage(ImageSource.camera),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.camera_alt, color: Colors.black87),
                label: Text(_t(isEn, 'Camera', 'الكاميرا'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _pickProfileImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.photo_library_outlined, color: Colors.black87),
                label: Text(_t(isEn, 'Gallery', 'المعرض'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
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
            border: Border.all(color: hasError ? Colors.red.shade400 : Colors.grey.shade300),
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
        if (errorText != null) _messageBox(errorText, isWarning: false, topMargin: 6),
      ],
    );
  }

  Widget _buildModernDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? errorText,
  }) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: hasError ? Colors.red.shade400 : Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 13, color: Colors.black54),
              prefixIcon: Icon(icon, color: Colors.black54),
              border: InputBorder.none,
            ),
            dropdownColor: Colors.white,
            items: items,
            onChanged: onChanged,
          ),
        ),
        if (errorText != null) _messageBox(errorText, isWarning: false, topMargin: 6),
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
                Text(_t(isEn, 'Social Email', 'البريد الاجتماعي'), style: const TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(widget.prefillEmail, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBox(String message, {required bool isWarning, double topMargin = 0}) {
    final bgColor = isWarning ? const Color(0xFFFFF7E8) : const Color(0xFFFFEBEB);
    final borderColor = isWarning ? Colors.amber.shade300 : Colors.red.shade300;
    final textColor = isWarning ? Colors.amber.shade900 : Colors.red.shade800;
    final iconColor = isWarning ? Colors.amber.shade800 : Colors.red;

    return Container(
      margin: EdgeInsets.only(top: topMargin),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(isWarning ? Icons.warning_amber_rounded : Icons.error_outline, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: textColor, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
