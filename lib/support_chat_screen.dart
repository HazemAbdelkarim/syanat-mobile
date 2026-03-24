import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  String? _chatId;
  bool _loading = true;

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

  Future<void> _initChat() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final profile = await FirebaseService.getProfile(user.uid);
      final userName =
          (profile?['username'] as String?)?.trim().isNotEmpty == true
              ? profile!['username'] as String
              : user.email ?? 'User';

      final chatId = await FirebaseService.getOrCreateSupportChat(
        userId: user.uid,
        userName: userName,
      );
      if (mounted) setState(() { _chatId = chatId; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null || _chatId == null) return;

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    try {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _syanatBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need Help?',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Syanat Support',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _syanatBlue))
          : _chatId == null
              ? const Center(
                  child: Text(
                    'Please log in to access support.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : _buildChatBody(),
    );
  }

  Widget _buildChatBody() {
    final currentUid = FirebaseService.getCurrentUser()!.uid;

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
              const Expanded(
                child: Text(
                  'Our support team typically replies within 24 hours.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                    child:
                        CircularProgressIndicator(color: _syanatBlue));
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Send us a message and we\'ll get back to you.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.black45, fontSize: 14),
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

        // Closed notice + input — driven by a single chat doc stream
        StreamBuilder<DocumentSnapshot>(
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
                    child: const Text(
                      'This conversation has been closed by support. '
                      'You may open a new request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: const Border(
                        top: BorderSide(color: Colors.grey)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          enabled: !closed,
                          decoration: InputDecoration(
                            hintText: closed
                                ? 'Conversation closed'
                                : 'Describe your issue...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: closed ? null : _sendMessage,
                        icon: Icon(
                          Icons.send,
                          color:
                              closed ? Colors.grey : _syanatBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
