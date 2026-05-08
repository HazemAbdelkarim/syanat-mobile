import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'widgets/egyptian_phone_field.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _sex = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = await FirebaseService.auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _error = 'not_logged_in';
        _loading = false;
      });
      return;
    }
    try {
      final data = await FirebaseService.getProfile(user.uid);
      if (data != null) {
        // The DB stores a single 'username' field. Split into first/last for display.
        final fullName = (data['username'] as String?) ?? '';
        final parts = fullName.trim().split(RegExp(r'\s+'));
        _firstNameCtrl.text = parts.isNotEmpty ? parts.first : '';
        _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        _emailCtrl.text = (data['email'] as String?) ?? (user.email ?? '');
        _phoneCtrl.text =
            normalizeEgyptianLocal((data['phone'] as String?) ?? '');
        _sex = (data['gender'] as String?) ?? '';
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    final phoneLocal = _phoneCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    String phoneE164 = '';
    if (phoneLocal.isNotEmpty) {
      final String? phoneErr = validateEgyptianLocal(phoneLocal, isEn: isEn);
      if (phoneErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(phoneErr)),
        );
        return;
      }
      phoneE164 = egyptianToE164(phoneLocal);
    }

    setState(() => _saving = true);
    try {
      await FirebaseService.updateProfile(user.uid, {
        'username': fullName,
        'phone': phoneE164,
        'gender': _sex,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Saved successfully' : 'تم الحفظ بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Settings save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Something went wrong. Please try again.' : 'حدث خطأ. يرجى المحاولة مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String t(String en, String ar) => isEn ? en : ar;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C4DFF), Color(0xFF6C3CE1), Color(0xFF5228B5)],
                ),
              ),
            ),
          title: Text(
            t('Account Settings', 'إعدادات الحساب'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _buildBody(isEn, t),
      ),
    );
  }

  Widget _buildBody(bool isEn, String Function(String, String) t) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _syanatBlue));
    }
    if (_error == 'not_logged_in') {
      return Center(
        child: Text(
          t('Please log in first', 'يرجى تسجيل الدخول أولاً'),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              t('Failed to load profile', 'فشل في تحميل البيانات'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldCard(
            icon: Icons.person_outline,
            label: t('First Name', 'الاسم الأول'),
            controller: _firstNameCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.person_outline,
            label: t('Last Name', 'اسم العائلة'),
            controller: _lastNameCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.email_outlined,
            label: t('Email', 'البريد الإلكتروني'),
            controller: _emailCtrl,
            readOnly: true,
          ),
          const SizedBox(height: 12),
          _fieldCard(
            icon: Icons.phone_outlined,
            label: t('Phone Number', 'رقم الهاتف'),
            controller: _phoneCtrl,
            readOnly: false,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _sexSelector(isEn),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _syanatBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isEn ? 'Save Changes' : 'حفظ التغييرات',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 40),
          _dangerZone(isEn, t),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Danger zone: in-app account deletion (Apple/Google store requirement).
  // Visually de-emphasized: red text on transparent background, separated
  // from the main settings by a divider and "Danger zone" header.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _dangerZone(bool isEn, String Function(String, String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.grey.shade300, height: 1),
        const SizedBox(height: 20),
        Text(
          t('Danger zone', 'منطقة الخطر'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : _onDeleteAccountPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.centerLeft,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                t('Delete account', 'حذف الحساب'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t(
            'Permanently remove your account and all your data. This cannot be undone.',
            'حذف حسابك وجميع بياناتك بشكل دائم. لا يمكن التراجع عن هذا.',
          ),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _onDeleteAccountPressed() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final proceed = await _showFirstConfirmDialog(isEn);
    if (proceed != true || !mounted) return;
    await _showFinalDeleteDialog(isEn);
  }

  // First dialog — explain what gets deleted; user taps Continue to proceed.
  Future<bool?> _showFirstConfirmDialog(bool isEn) {
    String t(String en, String ar) => isEn ? en : ar;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade600, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('Delete account?', 'حذف الحساب؟'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  'This action permanently deletes:',
                  'سيؤدي هذا الإجراء إلى الحذف الدائم لـ:',
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              _bullet(t(
                'Your profile information (name, email, phone)',
                'معلومات ملفك الشخصي (الاسم، البريد الإلكتروني، الهاتف)',
              )),
              _bullet(t(
                'Your saved locations',
                'مواقعك المحفوظة',
              )),
              _bullet(t(
                'Your order history will be anonymized',
                'سيتم إخفاء هوية سجل طلباتك',
              )),
              _bullet(t(
                'Your authentication account is signed out and removed',
                'سيتم تسجيل خروجك وحذف حساب المصادقة الخاص بك',
              )),
              const SizedBox(height: 12),
              Text(
                t('This cannot be undone.', 'لا يمكن التراجع عن هذا الإجراء.'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t('Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
              child: Text(
                t('Continue', 'متابعة'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Second dialog — final gate. User must type DELETE (or حذف) to enable
  // the destructive button. Calls FirebaseService.deleteAccount() inline
  // and routes to LoginScreen on success.
  Future<void> _showFinalDeleteDialog(bool isEn) async {
    String t(String en, String ar) => isEn ? en : ar;
    final controller = TextEditingController();
    bool inFlight = false;

    bool inputMatches(String value) {
      final v = value.trim().toUpperCase();
      return v == 'DELETE' || v == 'حذف';
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final canDelete = inputMatches(controller.text) && !inFlight;
            return Directionality(
              textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  t('Confirm deletion', 'تأكيد الحذف'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        'Type DELETE to confirm (or حذف).',
                        'اكتب DELETE للتأكيد (أو حذف).',
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !inFlight,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        hintText: 'DELETE',
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: inFlight
                        ? null
                        : () => Navigator.of(ctx).pop(),
                    child: Text(t('Cancel', 'إلغاء')),
                  ),
                  TextButton(
                    onPressed: !canDelete
                        ? null
                        : () async {
                            // Hard guard against a double-tap race: even
                            // though `canDelete` is false while inFlight,
                            // a tap dispatched in the same frame could
                            // slip through before setLocalState rebuilds.
                            if (inFlight) return;
                            setLocalState(() => inFlight = true);
                            await _executeDeletion(ctx, isEn);
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: inFlight
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : Text(
                            t('Delete account', 'حذف الحساب'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _executeDeletion(BuildContext dialogCtx, bool isEn) async {
    String t(String en, String ar) => isEn ? en : ar;
    // Capture navigators and messenger BEFORE the await so we don't have to
    // touch BuildContexts after the async gap.
    final dialogNav = Navigator.of(dialogCtx);
    final pageNav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseService.deleteAccount();
      if (!mounted) return;
      dialogNav.pop(); // close final dialog
      // Match the existing logout pattern (more_screen.dart): clear stack
      // and land on LoginScreen. AuthGate has already observed currentUser
      // == null so no further routing is needed.
      pageNav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('Account deleted', 'تم حذف الحساب')),
          backgroundColor: Colors.green,
        ),
      );
    } on AccountHasActiveJobsException catch (e) {
      if (!mounted) return;
      dialogNav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(t(
            'Cannot delete account: you have ${e.activeCount} active order(s). Complete or cancel them first.',
            'لا يمكن حذف الحساب: لديك ${e.activeCount} طلب(ات) نشطة. يُرجى إكمالها أو إلغاؤها أولاً.',
          )),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    } on RequiresRecentLoginException {
      // Don't try to show a snackbar here — auth.signOut() unmounts the
      // parent scaffold mid-frame and the captured `messenger` would be
      // showing a snack on a tree that's about to disappear. Use the
      // existing pendingAuthSnack pattern: AuthGate observes that a
      // pending snack is set when currentUser becomes null and routes
      // straight to LoginScreen, which renders the snack on first build
      // and clears the slot.
      FirebaseService.pendingAuthSnackEn =
          'Please sign in again to delete your account.';
      FirebaseService.pendingAuthSnackAr =
          'يرجى تسجيل الدخول مرة أخرى لحذف حسابك.';
      if (mounted && dialogNav.canPop()) {
        dialogNav.pop();
      }
      await FirebaseService.auth.signOut();
      // No further action — AuthGate handles the route swap.
    } catch (e) {
      debugPrint('Delete account error: $e');
      if (!mounted) return;
      dialogNav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(t(
            'Could not delete account. Please try again.',
            'تعذر حذف الحساب. يُرجى المحاولة مرة أخرى.',
          )),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: t('Retry', 'إعادة المحاولة'),
            textColor: Colors.white,
            onPressed: _onDeleteAccountPressed,
          ),
        ),
      );
    }
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool readOnly,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0x143C21C8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _syanatBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: keyboardType,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                suffixIcon: readOnly
                    ? Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400)
                    : Icon(Icons.edit, size: 16, color: _syanatBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sexSelector(bool isEn) {
    String t(String en, String ar) => isEn ? en : ar;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0x143C21C8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wc_outlined, color: _syanatBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Sex', 'الجنس'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _sexChip(
                      label: t('Male', 'ذكر'),
                      value: 'male',
                      selected: _sex.toLowerCase() == 'male',
                    ),
                    const SizedBox(width: 10),
                    _sexChip(
                      label: t('Female', 'أنثى'),
                      value: 'female',
                      selected: _sex.toLowerCase() == 'female',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sexChip({
    required String label,
    required String value,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _sex = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _syanatBlue.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _syanatBlue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? _syanatBlue : Colors.black54,
          ),
        ),
      ),
    );
  }
}



