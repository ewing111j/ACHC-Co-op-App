// lib/screens/classes/ask_mentor_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/class_models.dart';
import '../../utils/app_theme.dart';

class AskMentorScreen extends StatefulWidget {
  final ClassModel classModel;
  final UserModel user;
  const AskMentorScreen({super.key, required this.classModel, required this.user});

  @override
  State<AskMentorScreen> createState() => _AskMentorScreenState();
}

class _AskMentorScreenState extends State<AskMentorScreen> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final cls = widget.classModel;
    final canSeePrivate = user.canMentor || user.isAdmin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Ask the Mentor · ${cls.shortname}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAskSheet(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Ask a Question'),
        backgroundColor: Color(cls.colorValue),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('classes')
            .doc(cls.id)
            .collection('askMentor')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          final questions = docs
              .map((d) => AskMentorModel.fromMap(
                  d.data() as Map<String, dynamic>, d.id))
              .where((q) => canSeePrivate || !q.isPrivate)
              .toList();

          if (questions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.question_answer_outlined,
                      size: 56, color: AppTheme.textTertiary),
                  SizedBox(height: 16),
                  Text('No questions yet.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 15)),
                  SizedBox(height: 6),
                  Text('Tap the button below to ask the mentor.',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: questions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) =>
                _QuestionTile(q: questions[i], user: user, db: _db, cls: cls),
          );
        },
      ),
    );
  }

  void _showAskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AskSheet(classModel: widget.classModel, user: widget.user, db: _db),
    );
  }
}

// ── Question Tile ─────────────────────────────────────────────────────────────

class _QuestionTile extends StatelessWidget {
  final AskMentorModel q;
  final UserModel user;
  final FirebaseFirestore db;
  final ClassModel cls;
  const _QuestionTile(
      {required this.q,
      required this.user,
      required this.db,
      required this.cls});

  @override
  Widget build(BuildContext context) {
    final canModerate = user.canMentor || user.isAdmin;
    return ExpansionTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            Color(cls.colorValue).withValues(alpha: 0.15),
        child: Text(
          q.authorName.isNotEmpty ? q.authorName[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(cls.colorValue)),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(q.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                    decoration: q.isAnswered
                        ? TextDecoration.none
                        : TextDecoration.none)),
          ),
          if (q.isPrivate)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.lock_outline, size: 14, color: Colors.orange),
            ),
          if (q.isAnswered)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.check_circle, size: 14, color: Colors.green),
            ),
        ],
      ),
      subtitle: Text(
        '${q.authorName} · ${_timeAgo(q.createdAt)} · ${q.replyCount} replies',
        style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
      ),
      children: [
        // Replies
        _RepliesView(question: q, user: user, db: db, cls: cls),
        // Moderation actions
        if (canModerate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                if (!q.isAnswered)
                  TextButton.icon(
                    onPressed: () => _markAnswered(context),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Mark Answered', style: TextStyle(fontSize: 12)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                  label: const Text('Delete',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _markAnswered(BuildContext context) async {
    try {
      await db
          .collection('classes')
          .doc(cls.id)
          .collection('askMentor')
          .doc(q.id)
          .update({'isAnswered': true});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await db
          .collection('classes')
          .doc(cls.id)
          .collection('askMentor')
          .doc(q.id)
          .delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return DateFormat('MMM d').format(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ── Replies View ─────────────────────────────────────────────────────────────

class _RepliesView extends StatefulWidget {
  final AskMentorModel question;
  final UserModel user;
  final FirebaseFirestore db;
  final ClassModel cls;
  const _RepliesView(
      {required this.question,
      required this.user,
      required this.db,
      required this.cls});

  @override
  State<_RepliesView> createState() => _RepliesViewState();
}

class _RepliesViewState extends State<_RepliesView> {
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await widget.db
          .collection('classes')
          .doc(widget.cls.id)
          .collection('askMentor')
          .doc(widget.question.id)
          .collection('replies')
          .add({
        'text': text,
        'authorUid': widget.user.uid,
        'authorName': widget.user.displayName,
        'isMentor': widget.user.canMentor,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await widget.db
          .collection('classes')
          .doc(widget.cls.id)
          .collection('askMentor')
          .doc(widget.question.id)
          .update({'replyCount': FieldValue.increment(1)});
      _replyCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: widget.db
              .collection('classes')
              .doc(widget.cls.id)
              .collection('askMentor')
              .doc(widget.question.id)
              .collection('replies')
              .orderBy('createdAt')
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text('No replies yet.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textTertiary)),
              );
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isMentor = data['isMentor'] as bool? ?? false;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isMentor
                        ? AppTheme.navy.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    child: Text(
                      (data['authorName'] as String? ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMentor ? AppTheme.navy : AppTheme.textSecondary),
                    ),
                  ),
                  title: Text(data['text'] as String? ?? '',
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Row(
                    children: [
                      Text(data['authorName'] as String? ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      if (isMentor)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppTheme.navy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('Mentor',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        // Reply input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Write a reply…',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.send, size: 20, color: AppTheme.navy),
                onPressed: _addReply,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Ask Sheet ─────────────────────────────────────────────────────────────────

class _AskSheet extends StatefulWidget {
  final ClassModel classModel;
  final UserModel user;
  final FirebaseFirestore db;
  const _AskSheet(
      {required this.classModel, required this.user, required this.db});

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _questionCtrl = TextEditingController();
  bool _isPrivate = false;
  bool _saving = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _questionCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.db
          .collection('classes')
          .doc(widget.classModel.id)
          .collection('askMentor')
          .add({
        'classId': widget.classModel.id,
        'question': text,
        'authorUid': widget.user.uid,
        'authorName': widget.user.displayName,
        'visibility': _isPrivate ? 'private' : 'public',
        'replyCount': 0,
        'isAnswered': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Ask the Mentor',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy)),
          const SizedBox(height: 12),
          TextField(
            controller: _questionCtrl,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type your question here…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Private question',
                style: TextStyle(fontSize: 13)),
            subtitle: const Text(
                'Only visible to mentors and admins',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
            secondary: Icon(
                _isPrivate ? Icons.lock : Icons.lock_open,
                size: 18,
                color: _isPrivate ? Colors.orange : AppTheme.textTertiary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Question'),
            ),
          ),
        ],
      ),
    );
  }
}
