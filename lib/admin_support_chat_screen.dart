import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

const Color _syanatBlue = Color(0xFF3C21C8);

class AdminSupportChatScreen extends StatefulWidget {
  final String chatId;
  final String userName;

  const AdminSupportChatScreen({
    required this.chatId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminSupportChatScreen> createState() =>
      _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Clear unread flag when admin opens the chat.
    FirebaseService.markSupportChatReadByAdmin(widget.chatId);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final user = FirebaseService.getCurrentUser();
    if (user == null) return;

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    try {
      await FirebaseService.sendSupportMessage(
        chatId: widget.chatId,
        senderId: user.uid,
        text: text,
        setUnreadForAdmin: false, // admin is actively reading — no badge bump
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
      debugPrint('Admin send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    }
  }

  Future<void> _endConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Conversation'),
        content: const Text(
          'This will close the support thread. The user will no longer be '
          'able to send messages in this conversation. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Conversation'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.closeSupportChat(widget.chatId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminUid = FirebaseService.getCurrentUser()?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _syanatBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            const Text(
              'Support Request',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'end') _endConversation();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'end',
                child: Row(
                  children: [
                    Icon(Icons.close, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'End Conversation',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseService.firestore
            .collection('support_chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, chatSnap) {
          final chatData =
              chatSnap.data?.data() as Map<String, dynamic>?;
          final status = chatData?['status'] as String? ?? 'open';
          final closed = status == 'closed';

          return Column(
            children: [
              // User info + status strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: const Color(0xFFF0EDFF),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 18, color: _syanatBlue),
                    const SizedBox(width: 8),
                    Text(
                      widget.userName,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: closed
                            ? Colors.grey.shade200
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: closed
                              ? Colors.grey.shade400
                              : Colors.green,
                        ),
                      ),
                      child: Text(
                        closed ? 'Closed' : 'Open',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: closed
                              ? Colors.grey.shade600
                              : Colors.green.shade700,
                        ),
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
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('createdAt')
                      .limitToLast(50)
                      .snapshots(),
                  builder: (context, msgSnap) {
                    if (!msgSnap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: _syanatBlue),
                      );
                    }
                    final docs = msgSnap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet.',
                          style: TextStyle(color: Colors.black45),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data()
                            as Map<String, dynamic>;
                        final isAdmin =
                            data['senderId'] == adminUid;
                        final text = data['text'] as String? ?? '';
                        return Align(
                          alignment: isAdmin
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context)
                                      .size
                                      .width *
                                  0.72,
                            ),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? _syanatBlue
                                  : Colors.grey.shade200,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              text,
                              style: TextStyle(
                                color: isAdmin
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Closed notice
              if (closed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  color: Colors.grey.shade100,
                  child: const Text(
                    'This conversation has been closed.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),

              // Input bar
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
                              : 'Reply to ${widget.userName}...',
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
                        color: closed ? Colors.grey : _syanatBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
