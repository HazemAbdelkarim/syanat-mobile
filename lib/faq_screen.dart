import 'package:flutter/material.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'q_en': 'How do I book a technician?',
      'q_ar': 'كيف أحجز فني؟',
      'a_en': 'Open the app and select the service you need from the home screen. Browse available technicians in your area, view their profiles and prices, then tap "Request" to submit your booking. You will be connected with the technician via chat once your request is confirmed.',
      'a_ar': 'افتح التطبيق واختر الخدمة التي تحتاجها من الصفحة الرئيسية. تصفح الفنيين المتاحين في منطقتك، واطلع على ملفاتهم وأسعارهم، ثم اضغط على "طلب" لإرسال الحجز. سيتم ربطك بالفني عبر المحادثة بعد تأكيد الطلب.',
    },
    {
      'q_en': 'Can I cancel an order?',
      'q_ar': 'هل يمكنني إلغاء الطلب؟',
      'a_en': 'Yes. You can cancel an order while its status is still "Requested" or "Accepted." Open your orders, find the active order, and tap "Cancel Order." Once a technician has started the job, cancellation may not be available.',
      'a_ar': 'نعم. يمكنك إلغاء الطلب ما دامت حالته "مطلوب" أو "مقبول". افتح صفحة الطلبات، وابحث عن الطلب النشط، ثم اضغط على "إلغاء الطلب". بعد أن يبدأ الفني العمل قد لا يكون الإلغاء متاحاً.',
    },
    {
      'q_en': 'What payment methods are accepted?',
      'q_ar': 'ما طرق الدفع المقبولة؟',
      'a_en': 'Syanat currently accepts three payment methods: cash paid directly to the technician upon service completion, Vodafone Cash transfer, and InstaPay transfer. Select your preferred method during the booking confirmation step.',
      'a_ar': 'تطبيق صيانات يقبل حالياً ثلاث طرق للدفع: الدفع النقدي مباشرة للفني بعد إتمام الخدمة، والتحويل عبر فودافون كاش، والتحويل عبر إنستا باي. اختر الطريقة المناسبة لك أثناء تأكيد الحجز.',
    },
    {
      'q_en': 'How do I pay via Vodafone Cash or InstaPay?',
      'q_ar': 'كيف أدفع عبر فودافون كاش أو إنستا باي؟',
      'a_en': 'After selecting Vodafone Cash or InstaPay as your payment method, you will see the transfer details on screen. Complete the transfer from your banking or wallet app, then enter the transaction reference number and upload a screenshot of your payment receipt. Our team will verify and confirm your payment.',
      'a_ar': 'بعد اختيار فودافون كاش أو إنستا باي كطريقة للدفع، ستظهر لك بيانات التحويل على الشاشة. أكمل التحويل من تطبيق البنك أو المحفظة، ثم أدخل رقم العملية وارفع صورة إيصال الدفع. سيقوم فريقنا بمراجعة الدفع وتأكيده.',
    },
    {
      'q_en': 'What happens to my payment if I cancel?',
      'q_ar': 'ماذا يحدث للدفع إذا قمت بإلغاء الطلب؟',
      'a_en': 'If you cancel before payment is confirmed, no charge is applied. If payment was already submitted and verified, please contact our support team directly to request a review. Refund decisions are handled on a case-by-case basis.',
      'a_ar': 'إذا ألغيت قبل تأكيد الدفع فلن يتم احتساب أي مبلغ. وإذا كان الدفع قد تم إرساله والتحقق منه بالفعل، يرجى التواصل مع فريق الدعم لطلب مراجعة. يتم التعامل مع قرارات الاسترداد حسب كل حالة.',
    },
    {
      'q_en': 'Are technicians verified?',
      'q_ar': 'هل يتم التحقق من الفنيين؟',
      'a_en': 'All technicians on Syanat register with their professional details and service specialty. We review registrations before activating accounts. However, we recommend reviewing a technician\'s rating and reviews before booking, and always confirm the scope of work before service begins.',
      'a_ar': 'جميع الفنيين في صيانات يسجلون ببياناتهم المهنية وتخصص الخدمة الخاصة بهم. نقوم بمراجعة التسجيلات قبل تفعيل الحسابات. ومع ذلك ننصح دائماً بمراجعة تقييمات الفني وآراء العملاء قبل الحجز، والتأكد من نطاق العمل قبل بدء الخدمة.',
    },
    {
      'q_en': 'How do I rate a technician?',
      'q_ar': 'كيف أقيم الفني؟',
      'a_en': 'After your job is marked as completed, you will have the option to leave a rating for the technician. Ratings help other customers make informed decisions and help us maintain service quality on the platform.',
      'a_ar': 'بعد وضع علامة اكتمال على الطلب، سيظهر لك خيار تقييم الفني. تساعد التقييمات العملاء الآخرين على اتخاذ قرار أفضل، كما تساعدنا في الحفاظ على جودة الخدمة على المنصة.',
    },
    {
      'q_en': 'How do I delete my account?',
      'q_ar': 'كيف أحذف حسابي؟',
      'a_en': 'You can permanently delete your account from Account Settings → Danger zone → Delete account. Your profile, saved locations, and personal data are removed immediately. Your past order history is anonymized but kept for the technicians who completed your jobs. Account deletion is blocked while you have an active order — please complete or cancel any open orders first. This action cannot be undone.',
      'a_ar': 'يمكنك حذف حسابك نهائياً من إعدادات الحساب ← منطقة الخطر ← حذف الحساب. ستتم إزالة ملفك الشخصي ومواقعك المحفوظة وبياناتك الشخصية فوراً. سيتم إخفاء هوية سجل طلباتك السابقة مع الاحتفاظ بها للفنيين الذين أنجزوا طلباتك. لا يمكن حذف الحساب أثناء وجود طلب نشط — يُرجى إكمال أو إلغاء أي طلبات مفتوحة أولاً. لا يمكن التراجع عن هذا الإجراء.',
    },
    {
      'q_en': 'How do I reset my password?',
      'q_ar': 'كيف أعيد تعيين كلمة المرور؟',
      'a_en': 'On the login screen, tap "Forgot Password" and enter your registered email address. You will receive a password reset link by email. If you do not receive the email within a few minutes, check your spam folder or contact support.',
      'a_ar': 'من شاشة تسجيل الدخول اضغط على "نسيت كلمة المرور" ثم أدخل بريدك الإلكتروني المسجل. ستصلك رسالة تحتوي على رابط إعادة تعيين كلمة المرور. إذا لم تصلك الرسالة خلال بضع دقائق، تحقق من مجلد الرسائل غير المرغوب فيها أو تواصل مع الدعم.',
    },
    {
      'q_en': 'How do I contact support?',
      'q_ar': 'كيف أتواصل مع الدعم؟',
      'a_en': 'You can reach our support team by emailing support@syanat.app or through the "Need Help?" section in the app. We aim to respond to all inquiries within 24 hours.',
      'a_ar': 'يمكنك التواصل مع فريق الدعم عبر البريد الإلكتروني support@syanat.app أو من خلال قسم "تحتاج مساعدة؟" داخل التطبيق. نهدف إلى الرد على جميع الاستفسارات خلال 24 ساعة.',
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
                question: isEn ? faq['q_en']! : faq['q_ar']!,
                answer: isEn ? faq['a_en']! : faq['a_ar']!,
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
