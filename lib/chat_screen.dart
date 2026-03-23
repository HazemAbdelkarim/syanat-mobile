// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_service.dart';

const Color syanatBlue = Color(0xFF3C21C8);

class ChatScreen extends StatefulWidget {
  final String chatId;
  final bool isTechnician;
  const ChatScreen({
    required this.chatId,
    required this.isTechnician,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  int _currentUserMessageCount = 0;
  bool _loadingMessages = true;

  @override
  void initState() {
    super.initState();
    _countExistingMessages();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _countExistingMessages() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    final snap = await FirebaseService.firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('senderId', isEqualTo: user.uid)
        .limit(2)
        .get();

    setState(() {
      _currentUserMessageCount = snap.docs.length;
      _loadingMessages = false;
    });
  }

  Future<void> _sendMessage() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    // Limit to 2 messages only for customer side
    if (!widget.isTechnician && _currentUserMessageCount >= 2) {
      final isEn = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'You already sent your two messages.'
                : 'لقد أرسلت بالفعل رسالتين.',
          ),
        ),
      );
      return;
    }

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    await FirebaseService.firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!widget.isTechnician) {
      setState(() {
        _currentUserMessageCount += 1;
      });
    }

    _msgController.clear();

    await Future.delayed(const Duration(milliseconds: 80));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: syanatBlue,
          title: Text(
            isEn ? 'Chat' : 'الدردشة',
            style: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('createdAt')
                    .limitToLast(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    if (_loadingMessages) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: syanatBlue,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data() as Map<String, dynamic>;
                      final isMe =
                          data['senderId'] == FirebaseService.getCurrentUser()?.uid;
                      final text = data['text'] as String? ?? '';

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? syanatBlue : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Info text above input – different for user vs technician
            Padding(
              padding:
                  const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 2),
              child: Text(
                widget.isTechnician
                    ? (isEn
                        ? "Accept the request if you want to continue chatting with the user."
                        : "يجب عليك قبول الطلب إذا كنت تريد متابعة الدردشة مع العميل.")
                    : (isEn
                        ? "You can only send two messages: one explaining the problem and another for the price. The chat will continue normally if the technician accepts."
                        : "يمكنك إرسال رسالتين فقط: رسالة لشرح المشكلة وأخرى لعرض السعر. تستمر الدردشة بشكل عادي إذا قبل الفني."),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // input bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: const Border(
                  top: BorderSide(color: Colors.grey),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      enabled:
                          widget.isTechnician || _currentUserMessageCount < 2,
                      decoration: InputDecoration(
                        hintText: widget.isTechnician
                            ? (isEn
                                ? "Type your message..."
                                : "اكتب رسالتك...")
                            : (_currentUserMessageCount < 2
                                ? (isEn
                                    ? "Type your message..."
                                    : "اكتب رسالتك...")
                                : (isEn
                                    ? "Limit reached (2 messages)"
                                    : "لقد وصلت للحد (رسالتان)")),
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
                  IconButton(
                    onPressed: widget.isTechnician ||
                            _currentUserMessageCount < 2
                        ? _sendMessage
                        : null,
                    icon: Icon(
                      Icons.send,
                      color: widget.isTechnician ||
                              _currentUserMessageCount < 2
                          ? syanatBlue
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
