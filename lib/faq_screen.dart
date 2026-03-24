import 'package:flutter/material.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How do I book a technician?',
      'a': 'Open the app and select the service you need from the home screen. Browse available technicians in your area, view their profiles and prices, then tap "Request" to submit your booking. You will be connected with the technician via chat once your request is confirmed.',
    },
    {
      'q': 'Can I cancel an order?',
      'a': 'Yes. You can cancel an order while its status is still "Requested" or "Accepted." Open your orders, find the active order, and tap "Cancel Order." Once a technician has started the job, cancellation may not be available.',
    },
    {
      'q': 'What payment methods are accepted?',
      'a': 'Syanat currently accepts three payment methods: cash paid directly to the technician upon service completion, Vodafone Cash transfer, and InstaPay transfer. Select your preferred method during the booking confirmation step.',
    },
    {
      'q': 'How do I pay via Vodafone Cash or InstaPay?',
      'a': 'After selecting Vodafone Cash or InstaPay as your payment method, you will see the transfer details on screen. Complete the transfer from your banking or wallet app, then enter the transaction reference number and upload a screenshot of your payment receipt. Our team will verify and confirm your payment.',
    },
    {
      'q': 'What happens to my payment if I cancel?',
      'a': 'If you cancel before payment is confirmed, no charge is applied. If payment was already submitted and verified, please contact our support team directly to request a review. Refund decisions are handled on a case-by-case basis.',
    },
    {
      'q': 'Are technicians verified?',
      'a': 'All technicians on Syanat register with their professional details and service specialty. We review registrations before activating accounts. However, we recommend reviewing a technician\'s rating and reviews before booking, and always confirm the scope of work before service begins.',
    },
    {
      'q': 'How do I rate a technician?',
      'a': 'After your job is marked as completed, you will have the option to leave a rating for the technician. Ratings help other customers make informed decisions and help us maintain service quality on the platform.',
    },
    {
      'q': 'How do I delete my account?',
      'a': 'You can request account deletion from the Account section in the app. Tap "Delete Account" and follow the confirmation steps. All your personal data will be permanently removed within 30 days of your request. This action cannot be undone.',
    },
    {
      'q': 'How do I reset my password?',
      'a': 'On the login screen, tap "Forgot Password" and enter your registered email address. You will receive a password reset link by email. If you do not receive the email within a few minutes, check your spam folder or contact support.',
    },
    {
      'q': 'How do I contact support?',
      'a': 'You can reach our support team by emailing support@syanat.app or through the "Need Help?" section in the app. We aim to respond to all inquiries within 24 hours.',
    },
  ];

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
            t('FAQ', 'الأسئلة الشائعة'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: _faqs.length,
          itemBuilder: (context, index) {
            final faq = _faqs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqTile(
                question: faq['q']!,
                answer: faq['a']!,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _syanatBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _expanded ? Icons.remove : Icons.add,
              color: _syanatBlue,
              size: 20,
            ),
          ),
          title: Text(
            widget.question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _expanded ? _syanatBlue : Colors.black87,
            ),
          ),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            Text(
              widget.answer,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
