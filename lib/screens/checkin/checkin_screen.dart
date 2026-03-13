// lib/screens/checkin/checkin_screen.dart
// Parent self-check-in for kids/self, auto-attendance list, volunteer gap alerts
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Check-In'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Check In'),
            Tab(text: 'Attendance'),
            Tab(text: 'Volunteers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CheckInTab(user: user, db: _db),
          _AttendanceTab(db: _db, user: user),
          _VolunteersTab(user: user, db: _db),
        ],
      ),
    );
  }
}

// ── Check-In Tab ──────────────────────────────────────────────────
class _CheckInTab extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _CheckInTab({required this.user, required this.db});

  @override
  State<_CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends State<_CheckInTab> {
  bool _checkingIn = false;
  List<Map<String, dynamic>> _kids = [];

  @override
  void initState() {
    super.initState();
    _loadKids();
  }

  Future<void> _loadKids() async {
    if (widget.user.kidUids.isEmpty) return;
    final futures = widget.user.kidUids
        .map((uid) => widget.db.collection('users').doc(uid).get());
    final docs = await Future.wait(futures);
    final kids = docs
        .where((d) => d.exists)
        .map((d) => {'uid': d.id, 'name': d.data()?['displayName'] ?? 'Kid', 'checked': false})
        .toList();
    if (mounted) setState(() => _kids = List<Map<String, dynamic>>.from(kids));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.navyGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.today_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text(today,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Self check-in
          AppTheme.sectionHeader('Self Check-In'),
          _CheckInCard(
            name: widget.user.displayName,
            subtitle: 'Check yourself in',
            icon: Icons.person_outlined,
            db: widget.db,
            user: widget.user,
            checkForUid: widget.user.uid,
          ),
          const SizedBox(height: 20),

          // Kids check-in
          if (_kids.isNotEmpty) ...[
            AppTheme.sectionHeader('Check In Kids'),
            ..._kids.map((kid) => _CheckInCard(
              name: kid['name'] as String,
              subtitle: 'Check in for co-op today',
              icon: Icons.child_care_outlined,
              db: widget.db,
              user: widget.user,
              checkForUid: kid['uid'] as String,
            )),
          ],
        ],
      ),
    );
  }
}

// ── Check-In Card ─────────────────────────────────────────────────
class _CheckInCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final FirebaseFirestore db;
  final UserModel user;
  final String checkForUid;
  const _CheckInCard({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.db,
    required this.user,
    required this.checkForUid,
  });

  @override
  State<_CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<_CheckInCard> {
  bool _isCheckedIn = false;
  bool _loading = false;
  String? _checkinId;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _checkStatus() async {
    final snap = await widget.db
        .collection('checkins')
        .where('uid', isEqualTo: widget.checkForUid)
        .where('date', isEqualTo: _todayKey)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty && mounted) {
      setState(() {
        _isCheckedIn = true;
        _checkinId = snap.docs.first.id;
      });
    }
  }

  Future<void> _toggleCheckIn() async {
    setState(() => _loading = true);
    try {
      if (_isCheckedIn && _checkinId != null) {
        await widget.db.collection('checkins').doc(_checkinId).delete();
        setState(() {
          _isCheckedIn = false;
          _checkinId = null;
        });
      } else {
        final doc = await widget.db.collection('checkins').add({
          'uid': widget.checkForUid,
          'name': widget.name,
          'checkedInBy': widget.user.uid,
          'checkedInByName': widget.user.displayName,
          'date': _todayKey,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isCheckedIn = true;
          _checkinId = doc.id;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCheckedIn
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isCheckedIn
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.surfaceVariant,
            ),
            child: Icon(
              _isCheckedIn ? Icons.check_circle : widget.icon,
              color: _isCheckedIn ? AppTheme.success : AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  _isCheckedIn ? 'Checked in ✓' : widget.subtitle,
                  style: TextStyle(
                    color: _isCheckedIn ? AppTheme.success : AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _loading
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : OutlinedButton(
                  onPressed: _toggleCheckIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isCheckedIn ? AppTheme.error : AppTheme.success,
                    side: BorderSide(
                      color: _isCheckedIn ? AppTheme.error : AppTheme.success,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(_isCheckedIn ? 'Undo' : 'Check In'),
                ),
        ],
      ),
    );
  }
}

// ── Attendance Tab ────────────────────────────────────────────────
class _AttendanceTab extends StatelessWidget {
  final FirebaseFirestore db;
  final UserModel user;
  const _AttendanceTab({required this.db, required this.user});

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('checkins')
          .where('date', isEqualTo: _todayKey)
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.surface,
              child: Row(
                children: [
                  const Icon(Icons.people, color: AppTheme.navy, size: 20),
                  const SizedBox(width: 10),
                  Text('${docs.length} checked in today',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            ),
            AppTheme.goldDivider(),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('No check-ins yet today',
                          style: TextStyle(color: AppTheme.textHint)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final ts = d['timestamp'] != null
                            ? DateTime.fromMillisecondsSinceEpoch(
                                (d['timestamp'] as Timestamp).millisecondsSinceEpoch)
                            : DateTime.now();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                            child: const Icon(Icons.check, color: AppTheme.success, size: 18),
                          ),
                          title: Text(d['name'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('By: ${d['checkedInByName'] ?? ''}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(DateFormat('h:mm a').format(ts),
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textHint)),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Volunteers Tab ────────────────────────────────────────────────
class _VolunteersTab extends StatefulWidget {
  final UserModel user;
  final FirebaseFirestore db;
  const _VolunteersTab({required this.user, required this.db});

  @override
  State<_VolunteersTab> createState() => _VolunteersTabState();
}

class _VolunteersTabState extends State<_VolunteersTab> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('volunteerSlots')
          .orderBy('date', descending: false)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];

        return Column(
          children: [
            if (widget.user.isAdmin)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : () => _addSlot(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Volunteer Slot'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.checkInColor),
                  ),
                ),
              ),
            Expanded(
              child: docs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.volunteer_activism_outlined,
                              size: 64, color: AppTheme.textHint),
                          const SizedBox(height: 16),
                          const Text('No volunteer slots yet',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final docId = docs[i].id;
                        final volunteers = List<String>.from(
                            d['volunteerNames'] as List? ?? []);
                        final needed = d['spotsNeeded'] as int? ?? 1;
                        final filled = volunteers.length;
                        final isShort = filled < needed;
                        final hasSignedUp = (d['volunteerUids'] as List? ?? [])
                            .contains(widget.user.uid);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isShort
                                  ? AppTheme.error.withValues(alpha: 0.3)
                                  : AppTheme.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(d['role'] as String? ?? 'Volunteer',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                  if (isShort)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Needs Help!',
                                          style: TextStyle(
                                              color: AppTheme.error, fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(d['description'] as String? ?? '',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 14, color: AppTheme.textHint),
                                  const SizedBox(width: 4),
                                  Text('$filled / $needed spots',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isShort
                                              ? AppTheme.error
                                              : AppTheme.success)),
                                  const Spacer(),
                                  if (!widget.user.isKid)
                                    ElevatedButton(
                                      onPressed: () =>
                                          _signUp(docId, d, hasSignedUp),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hasSignedUp
                                            ? AppTheme.surfaceVariant
                                            : AppTheme.checkInColor,
                                        foregroundColor: hasSignedUp
                                            ? AppTheme.textSecondary
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      child: Text(hasSignedUp ? 'Signed Up ✓' : 'Sign Up'),
                                    ),
                                ],
                              ),
                              if (volunteers.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: volunteers
                                      .map((v) => Chip(
                                            label: Text(v,
                                                style: const TextStyle(fontSize: 11)),
                                            padding: EdgeInsets.zero,
                                          ))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signUp(String docId, Map<String, dynamic> data, bool hasSignedUp) async {
    if (hasSignedUp) {
      await widget.db.collection('volunteerSlots').doc(docId).update({
        'volunteerUids': FieldValue.arrayRemove([widget.user.uid]),
        'volunteerNames': FieldValue.arrayRemove([widget.user.displayName]),
      });
    } else {
      await widget.db.collection('volunteerSlots').doc(docId).update({
        'volunteerUids': FieldValue.arrayUnion([widget.user.uid]),
        'volunteerNames': FieldValue.arrayUnion([widget.user.displayName]),
      });
    }
  }

  void _addSlot(BuildContext context) {
    final roleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int spots = 2;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Volunteer Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Role/Task'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              Row(
                children: [
                  const Text('Spots needed:'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setS(() => spots = (spots - 1).clamp(1, 20)),
                  ),
                  Text('$spots', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setS(() => spots++),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (roleCtrl.text.trim().isEmpty) return;
                await widget.db.collection('volunteerSlots').add({
                  'role': roleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'spotsNeeded': spots,
                  'volunteerUids': [],
                  'volunteerNames': [],
                  'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
