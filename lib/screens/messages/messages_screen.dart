// lib/screens/messages/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/message_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'New Message',
            onPressed: () => _showNewMessageDialog(context, user),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: _firestoreService.streamChatRooms(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  const Text(
                    'No messages yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a conversation with your co-op',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showNewMessageDialog(context, user),
                    icon: const Icon(Icons.add_comment),
                    label: const Text('New Message'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (ctx, i) {
              final room = rooms[i];
              final otherName = room.isGroup
                  ? (room.groupName ?? 'Group')
                  : room.participantNames
                      .firstWhere((n) => n != user.displayName,
                          orElse: () => 'Unknown');

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.messagesColor
                      .withValues(alpha: 0.15),
                  child: Text(
                    otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppTheme.messagesColor,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(otherName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                  room.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                trailing: room.lastMessageTime != null
                    ? Text(
                        _formatTime(room.lastMessageTime!),
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 11),
                      )
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: room.id,
                      roomName: otherName,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (now.difference(time).inDays == 1) {
      return 'Yesterday';
    }
    return DateFormat('MMM d').format(time);
  }

  void _showNewMessageDialog(BuildContext context, user) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Start a conversation with a family member or co-op member',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Recipient Name',
                prefixIcon: Icon(Icons.person_search),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              // Create a general/co-op announcement room
              final roomId = await _firestoreService.createOrGetDirectRoom(
                user.uid,
                user.displayName,
                'co_op_general',
                'Co-op General',
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      roomId: roomId,
                      roomName: nameCtrl.text.trim(),
                    ),
                  ),
                );
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
