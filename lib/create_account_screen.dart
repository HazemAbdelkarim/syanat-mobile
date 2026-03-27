import 'dart:io' show File;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../firebase_service.dart';
import 'main.dart' show AppLocale;
import 'tech_home_screen.dart';
import 'user_home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class CreateAccountScreen extends StatefulWidget {
  /// When set, a Firebase Auth account already exists (social sign-in).
  /// The screen skips email/password creation and goes straight to
  /// profile completion, pre-filling whatever the provider supplied.
  final String? prefillUid;
  final String prefillEmail;
  final String prefillName;

  const CreateAccountScreen({
    super.key,
    this.prefillUid,
    this.prefillEmail = '',
    this.prefillName = '',
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _picker = ImagePicker();

  String _role = 'customer';
  String? _service;
  bool _isLoading = false;
  Position? _currentPosition;
  XFile? _profileImage;

  /// Maps Arabic service names to internal service keys for database queries
  static const Map<String, String> arabicToServiceKey = {
    'فني تكييف': 'ac',
    'سباك': 'plumbing',
    'كهربائي': 'electricity',
    'نقاش': 'finishing',
    'نجار': 'carpentry',
    'تركيب ألوميتال / سلك': 'aluminum',
    'فني غسلات': 'small_appliances',
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
    'فني غسلات',
    'صيانة المسابح',
    'تصليح مواتير مياه',
    'صيانة خزانات المياه',
    'فني رخام',
    'فني سخانات',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill available data from the social provider.
    if (widget.prefillUid != null) {
      _emailController.text = widget.prefillEmail;
      _usernameController.text = widget.prefillName;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      return;
    }
    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _pickProfileImage() async {
    // No imageQuality here — compression is applied in FirebaseService.uploadPhoto()
    // (max 512 px · JPEG quality 70) so we pick at full quality for best source data.
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked != null) {
      setState(() => _profileImage = picked);
    }
  }

  Future<void> _signup() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final isSocialMode = widget.prefillUid != null;
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final lang = isEn ? 'en' : 'ar';

    // Validate required fields.
    // Email/password are only required in the standard (non-social) flow.
    final bool missingFields = username.isEmpty ||
        phone.isEmpty ||
        city.isEmpty ||
        (!isSocialMode &&
            (_emailController.text.trim().isEmpty ||
                _passwordController.text.trim().isEmpty));

    if (missingFields) {
      _showSnack(
          isEn ? "Please fill all fields" : "يرجى ملء جميع الحقول");
      setState(() => _isLoading = false);
      return;
    }

    final egyptPhoneRegex = RegExp(r'^\+201[0125]\d{8}$');
    if (!egyptPhoneRegex.hasMatch(phone)) {
      _showSnack(
        isEn
            ? "Invalid phone number. Use format: +201XXXXXXXXX"
            : "رقم الهاتف غير صحيح. استخدم الصيغة: +201XXXXXXXXX",
      );
      setState(() => _isLoading = false);
      return;
    }

    if (_role == 'technician' && _service == null) {
      _showSnack(isEn ? "Please select your service" : "اختر مجال عملك");
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (_role == 'technician') {
        await _getLocation();
      }

      // ── Obtain UID + email ──────────────────────────────────────────────
      final String uid;
      final String email;

      if (isSocialMode) {
        // Firebase Auth account already exists — skip email/password creation.
        uid = widget.prefillUid!;
        email = widget.prefillEmail;
      } else {
        final credential =
            await FirebaseService.auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = credential.user;
        if (user == null) throw "Unable to create user";
        uid = user.uid;
        email = _emailController.text.trim();
      }

      // ── Upload photo (technicians only) ─────────────────────────────────
      String? photoUrl;
      if (_role == 'technician' && _profileImage != null) {
        photoUrl = await FirebaseService.uploadPhoto(
          _profileImage!,
          folder: 'techProfiles',
        );
      }

      // ── Write Firestore profile ──────────────────────────────────────────
      if (_role == 'technician') {
        final serviceKey = arabicToServiceKey[_service!] ?? _service!;
        await FirebaseService.createTechnician(
          uid: uid,
          email: email,
          username: username,
          phone: phone,
          serviceId: serviceKey,
          city: city,
          language: lang,
          photoUrl: photoUrl ?? '',
        );
        if (_currentPosition != null) {
          await FirebaseService.firestore
              .collection('users')
              .doc(uid)
              .set(
            {
              'location': GeoPoint(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
            },
            SetOptions(merge: true),
          );
        }
      } else {
        await FirebaseService.createUser(
          uid: uid,
          email: email,
          username: username,
          role: 'customer',
          phone: phone,
          city: city,
          language: lang,
          photoUrl: photoUrl ?? '',
        );
      }

      if (!mounted) return;

      if (_role == 'technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TechHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(isEn ? "Error: $e" : "خطأ: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _switchLanguage() {
    final newLocale =
        Localizations.localeOf(context).languageCode == 'en'
            ? const Locale('ar')
            : const Locale('en');
    AppLocale.of(context).value = newLocale;
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final isSocialMode = widget.prefillUid != null;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        color: syanatBlue,
        child: SafeArea(
          child: Scaffold(
            backgroundColor: syanatBlue,
            body: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        tooltip: isEn ? 'Back' : 'رجوع',
                      ),
                      IconButton(
                        onPressed: _switchLanguage,
                        icon: const Icon(Icons.language, color: Colors.white),
                        tooltip: isEn ? 'Language' : 'اللغة',
                      ),
                    ],
                  ),

                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border:
                                Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isEn
                                    ? (isSocialMode
                                        ? "Complete Profile"
                                        : "Create Account")
                                    : (isSocialMode
                                        ? "أكمل ملفك الشخصي"
                                        : "إنشاء حساب"),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildModernTextField(
                                _usernameController,
                                isEn ? "Full Name" : "الاسم الكامل",
                                Icons.person,
                              ),
                              const SizedBox(height: 16),
                              _buildModernTextField(
                                _phoneController,
                                isEn ? "Phone Number" : "رقم الهاتف",
                                Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              _buildModernTextField(
                                _cityController,
                                isEn ? "City" : "المدينة",
                                Icons.location_city,
                              ),
                              // Email + password are only needed for the
                              // standard sign-up flow. Social sign-in users
                              // already have a Firebase Auth account.
                              if (!isSocialMode) ...[
                                const SizedBox(height: 16),
                                _buildModernTextField(
                                  _emailController,
                                  isEn
                                      ? "Email"
                                      : "البريد الإلكتروني",
                                  Icons.email,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                _buildModernTextField(
                                  _passwordController,
                                  isEn ? "Password" : "كلمة المرور",
                                  Icons.lock,
                                  obscure: true,
                                ),
                              ],
                              const SizedBox(height: 16),
                              _buildModernDropdown(
                                value: _role,
                                label: isEn ? "Role" : "الدور",
                                icon: Icons.work,
                                items: [
                                  DropdownMenuItem(
                                    value: "customer",
                                    child: Text(
                                        isEn ? "Customer" : "عميل"),
                                  ),
                                  DropdownMenuItem(
                                    value: "technician",
                                    child: Text(
                                        isEn ? "Technician" : "فني"),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _role = v!),
                              ),
                              const SizedBox(height: 16),
                              if (_role == "technician")
                                _buildModernDropdown(
                                  value: _service,
                                  label: isEn
                                      ? "Select Service"
                                      : "اختر المجال",
                                  icon: Icons.build,
                                  items: technicianServices
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _service = v),
                                ),
                              if (_role == "technician") ...[
                                const SizedBox(height: 16),
                                _buildPhotoPicker(isEn),
                              ],
                              const SizedBox(height: 32),
                              _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        color: syanatBlue,
                                      ),
                                    )
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 60,
                                      child: ElevatedButton(
                                        onPressed: _signup,
                                        style:
                                            ElevatedButton.styleFrom(
                                          backgroundColor: syanatBlue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    15),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          isEn
                                              ? "Sign Up"
                                              : "إنشاء حساب",
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight:
                                                FontWeight.bold,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          border: InputBorder.none,
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(color: Colors.black),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPhotoPicker(bool isEn) {
    ImageProvider? preview;
    if (_profileImage != null) {
      if (kIsWeb) {
        preview = NetworkImage(_profileImage!.path);
      } else {
        preview = FileImage(File(_profileImage!.path));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn ? "Profile Photo" : "الصورة الشخصية",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 35,
                backgroundColor: Colors.transparent,
                backgroundImage: preview,
                child: preview == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 35,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ElevatedButton.icon(
                  onPressed: _pickProfileImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.upload_file,
                      color: Colors.black),
                  label: Text(
                    isEn ? "Choose Photo" : "اختر صورة",
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
