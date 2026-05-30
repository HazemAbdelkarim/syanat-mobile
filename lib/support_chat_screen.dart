import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF6C3FA0);

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  User? _currentUser;
  String? _chatId;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// On screen open: only LOOK for an existing open chat.
  /// Do NOT create one — that would create a phantom admin-side ticket
  /// for users who opened the screen but never wrote anything.
  Future<void> _initChat() async {
    final user = await FirebaseService.auth
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (!mounted) return;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    _currentUser = user;
    try {
      final chatId = await FirebaseService.getExistingSupportChat(user.uid);
      if (mounted) setState(() { _chatId = chatId; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final user = _currentUser;
    if (user == null) return;

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _msgController.clear();

    try {
      // Lazy-create the support chat only on the very first message send.
      // This prevents phantom tickets from users who just opened the screen.
      if (_chatId == null) {
        final profile = await FirebaseService.getProfile(user.uid);
        final userName =
            (profile?['username'] as String?)?.trim().isNotEmpty == true
                ? profile!['username'] as String
                : user.email ?? 'User';
        final chatId = await FirebaseService.getOrCreateSupportChat(
          userId: user.uid,
          userName: userName,
        );
        if (mounted) setState(() => _chatId = chatId);
      }

      await FirebaseService.sendSupportMessage(
        chatId: _chatId!,
        senderId: user.uid,
        text: text,
        setUnreadForAdmin: true,
      );

      await Future.delayed(const Duration(milliseconds: 80));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Restore message text so user does not lose it
      _msgController.text = text;
      if (mounted) {
        final isPermission = e.toString().contains('PERMISSION_DENIED');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermission
                  ? _t('Please wait a moment before sending another message.',
                        'يرجى الانتظار لحظة قبل إرسال رسالة أخرى.')
                  : _t('Failed to send message. Please try again.',
                        'فشل إرسال الرسالة. يرجى المحاولة مرة أخرى.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _isEn => Localizations.localeOf(context).languageCode == 'en';

  String _t(String en, String ar) => _isEn ? en : ar;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF211D40)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Need Help?', 'تحتاج مساعدة؟'),
                style: const TextStyle(
                    color: Color(0xFF211D40),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              Text(
                _t('Syanat Support', 'دعم صيانات'),
                style: const TextStyle(color: Color(0xFF8B8699), fontSize: 12),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _syanatBlue))
            : _currentUser == null
                ? Center(
                    child: Text(
                      _t(
                        'Please log in to access support.',
                        'يرجى تسجيل الدخول للوصول إلى الدعم.',
                      ),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : _buildChatBody(),
      ),
    );
  }

  Widget _buildChatBody() {
    final currentUid = _currentUser!.uid;

    return Column(
      children: [
        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF0EDFF),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _syanatBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent,
                    color: _syanatBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t(
                    'Our support team typically replies within 24 hours.',
                    'فريق الدعم يرد عادة خلال 24 ساعة.',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: _chatId == null
              // No existing chat — show empty-state hint
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _t(
                        'Send us a message and we\'ll get back to you.',
                        'أرسل لنا رسالة وسنرد عليك.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 14),
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseService.firestore
                      .collection('support_chats')
                      .doc(_chatId)
                      .collection('messages')
                      .orderBy('createdAt')
                      .limitToLast(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: _syanatBlue));
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _t(
                              'Send us a message and we\'ll get back to you.',
                              'أرسل لنا رسالة وسنرد عليك.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.black45, fontSize: 14),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data =
                            docs[index].data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == currentUid;
                        final text = data['text'] as String? ?? '';
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? _syanatBlue
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              text,
                              style: TextStyle(
                                color:
                                    isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),

        // Closed notice + input
        _chatId == null
            ? _inputBar(closed: false)
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseService.firestore
                    .collection('support_chats')
                    .doc(_chatId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  final closed = data?['status'] == 'closed';
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (closed)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16),
                          color: Colors.grey.shade100,
                          child: Text(
                            _t(
                              'This conversation has been closed by support. You may open a new request.',
                              'تم إغلاق هذه المحادثة من قبل الدعم. يمكنك فتح طلب جديد.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      _inputBar(closed: closed),
                    ],
                  );
                },
              ),
      ],
    );
  }

  Widget _inputBar({required bool closed}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              maxLength: 2000,
              enabled: !closed,
              decoration: InputDecoration(
                counterText: '',
                hintText: closed
                    ? _t('Conversation closed', 'تم إغلاق المحادثة')
                    : _t('Describe your issue...', 'اشرح مشكلتك...'),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _syanatBlue),
                  ),
                )
              : IconButton(
                  onPressed: closed ? null : _sendMessage,
                  icon: Icon(
                    Icons.send,
                    color: closed ? Colors.grey : _syanatBlue,
                  ),
                ),
        ],
      ),
    );
  }
}
