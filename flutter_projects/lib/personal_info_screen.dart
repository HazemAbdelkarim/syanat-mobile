import 'package:flutter/material.dart';
import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      setState(() {
        _error = 'not_logged_in';
        _loading = false;
      });
      return;
    }
    try {
      final data = await FirebaseService.getProfile(user.uid);
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
          backgroundColor: _syanatBlue,
          elevation: 0,
          title: Text(
            t('Personal Information', 'المعلومات الشخصية'),
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
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    if (_profile == null) {
      return Center(
        child: Text(
          t('No profile data found', 'لم يتم إيجاد بيانات'),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
      );
    }

    // Extract fields
    final user = FirebaseService.getCurrentUser();
    final name = (_profile!['username'] as String?) ?? '';
    final email = (_profile!['email'] as String?) ?? (user?.email ?? '');
    final phone = (_profile!['phone'] as String?) ?? '';
    final gender = (_profile!['gender'] as String?) ?? '';

    // Avatar initials
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // ── Avatar ──────────────────────────────────────────────
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_syanatBlue, Color(0xFF6C4FF7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _syanatBlue.withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 28),

          // ── Info cards ───────────────────────────────────────────
          _InfoCard(
            icon: Icons.person_outline,
            label: t('Name', 'الاسم'),
            value: name.isNotEmpty ? name : t('Not set', 'غير محدد'),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.email_outlined,
            label: t('Email', 'البريد الإلكتروني'),
            value: email.isNotEmpty ? email : t('Not set', 'غير محدد'),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.phone_outlined,
            label: t('Phone', 'رقم الهاتف'),
            value: phone.isNotEmpty ? phone : t('Not set', 'غير محدد'),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.wc_outlined,
            label: t('Gender', 'الجنس'),
            value: _localizedGender(gender, isEn),
          ),
        ],
      ),
    );
  }

  String _localizedGender(String raw, bool isEn) {
    switch (raw.toLowerCase()) {
      case 'male':
        return isEn ? 'Male' : 'ذكر';
      case 'female':
        return isEn ? 'Female' : 'أنثى';
      default:
        return isEn ? 'Not set' : 'غير محدد';
    }
  }
}

// ---------------------------------------------------------------------------
// Reusable info row card
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
