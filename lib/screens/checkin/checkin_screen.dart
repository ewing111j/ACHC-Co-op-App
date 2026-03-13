// lib/screens/checkin/checkin_screen.dart
// Check-In tab: self + students; Attendance tab: per-class breakdown
// Attendance permissions:
//   - Admin: can check in students for any class
//   - Mentor/Second: can check in only for their own assigned classes
//   - Parent: self check-in + their own students only
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CheckInTab(user: user, db: _db),
          _AttendanceTab(db: _db, user: user),
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
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (widget.user.kidUids.isEmpty) return;
    final futures = widget.user.kidUids
        .map((uid) => widget.db.collection('users').doc(uid).get());
    final docs = await Future.wait(futures);
    final students = docs
        .where((d) => d.exists)
        .map((d) => {
              'uid': d.id,
              'name': d.data()?['displayName'] ?? 'Student',
            })
        .toList();
    if (mounted) {
      setState(
          () => _students = List<Map<String, dynamic>>.from(students));
    }
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
                const Icon(Icons.today_outlined,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 11)),
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

          // Students check-in
          if (_students.isNotEmpty) ...[
            AppTheme.sectionHeader('Check In Students'),
            ..._students.map((s) => _CheckInCard(
                  name: s['name'] as String,
                  subtitle: 'Check in for co-op today',
                  icon: Icons.school_outlined,
                  db: widget.db,
                  user: widget.user,
                  checkForUid: s['uid'] as String,
                )),
          ],
        ],
      ),
    );
  }
}

// ── Check-In Card (3-state: none → checkedIn → checkedOut → reset) ──
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

enum _CIState { none, checkedIn, checkedOut }

class _CheckInCardState extends State<_CheckInCard> {
  _CIState _state = _CIState.none;
  bool _loading = false;
  String? _checkinId;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;

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
      final data = snap.docs.first.data();
      final hasOut = data['checkOutTime'] != null;
      setState(() {
        _state = hasOut ? _CIState.checkedOut : _CIState.checkedIn;
        _checkinId = snap.docs.first.id;
        if (data['timestamp'] != null) {
          _checkInTime = DateTime.fromMillisecondsSinceEpoch(
              (data['timestamp'] as Timestamp).millisecondsSinceEpoch);
        }
        if (hasOut) {
          _checkOutTime = DateTime.fromMillisecondsSinceEpoch(
              (data['checkOutTime'] as Timestamp)
                  .millisecondsSinceEpoch);
        }
      });
    }
  }

  Future<void> _checkIn() async {
    setState(() => _loading = true);
    try {
      final doc = await widget.db.collection('checkins').add({
        'uid': widget.checkForUid,
        'name': widget.name,
        'checkedInBy': widget.user.uid,
        'checkedInByName': widget.user.displayName,
        'date': _todayKey,
        'timestamp': FieldValue.serverTimestamp(),
        'checkOutTime': null,
        'status': 'checkedIn',
      });
      setState(() {
        _state = _CIState.checkedIn;
        _checkinId = doc.id;
        _checkInTime = DateTime.now();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkOut() async {
    if (_checkinId == null) return;
    setState(() => _loading = true);
    try {
      await widget.db
          .collection('checkins')
          .doc(_checkinId)
          .update({
        'checkOutTime': FieldValue.serverTimestamp(),
        'status': 'checkedOut',
      });
      setState(() {
        _state = _CIState.checkedOut;
        _checkOutTime = DateTime.now();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_checkinId == null) return;
    setState(() => _loading = true);
    try {
      await widget.db
          .collection('checkins')
          .doc(_checkinId)
          .delete();
      setState(() {
        _state = _CIState.none;
        _checkinId = null;
        _checkInTime = null;
        _checkOutTime = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('h:mm a');
    Color borderColor;
    Color iconBg;
    Color iconColor;
    IconData stateIcon;
    String stateLabel;

    switch (_state) {
      case _CIState.checkedIn:
        borderColor = AppTheme.success.withValues(alpha: 0.4);
        iconBg = AppTheme.success.withValues(alpha: 0.1);
        iconColor = AppTheme.success;
        stateIcon = Icons.login_outlined;
        stateLabel =
            'In ${_checkInTime != null ? fmt.format(_checkInTime!) : ""}';
        break;
      case _CIState.checkedOut:
        borderColor = AppTheme.navy.withValues(alpha: 0.3);
        iconBg = AppTheme.navy.withValues(alpha: 0.08);
        iconColor = AppTheme.navy;
        stateIcon = Icons.check_circle_outline;
        stateLabel =
            'In ${_checkInTime != null ? fmt.format(_checkInTime!) : ""}  •  '
            'Out ${_checkOutTime != null ? fmt.format(_checkOutTime!) : ""}';
        break;
      case _CIState.none:
      default:
        borderColor = AppTheme.cardBorder;
        iconBg = AppTheme.surfaceVariant;
        iconColor = AppTheme.textSecondary;
        stateIcon = widget.icon;
        stateLabel = widget.subtitle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(stateIcon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(stateLabel,
                    style: TextStyle(
                        color: _state == _CIState.none
                            ? AppTheme.textHint
                            : AppTheme.textSecondary,
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_loading)
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            _buildButton(),
        ],
      ),
    );
  }

  Widget _buildButton() {
    switch (_state) {
      case _CIState.none:
        return ElevatedButton(
          onPressed: _checkIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Check In'),
        );
      case _CIState.checkedIn:
        return ElevatedButton(
          onPressed: _checkOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warning,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Check Out'),
        );
      case _CIState.checkedOut:
        return OutlinedButton(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.cardBorder),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Reset'),
        );
    }
  }
}

// ── Attendance Tab ─────────────────────────────────────────────────
class _AttendanceTab extends StatefulWidget {
  final FirebaseFirestore db;
  final UserModel user;
  const _AttendanceTab({required this.db, required this.user});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  String get _todayKey =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.db
          .collection('groups')
          .where('type', isEqualTo: 'class')
          .snapshots(),
      builder: (ctx, groupSnap) {
        final allGroups = groupSnap.data?.docs ?? [];

        // Filter groups based on role:
        // - Admin sees all classes
        // - Mentor/Second sees only their assigned classes
        // - Others see all (for viewing purposes)
        final groups = widget.user.isAdmin
            ? allGroups
            : allGroups.where((g) {
                final data = g.data() as Map<String, dynamic>;
                final mentors = List<String>.from(
                    data['mentorUids'] as List? ?? []);
                final seconds = List<String>.from(
                    data['secondUids'] as List? ?? []);
                // Mentors/seconds can interact with their classes
                final isAssigned =
                    mentors.contains(widget.user.uid) ||
                        seconds.contains(widget.user.uid);
                // Parents can see all for viewing
                return widget.user.isParent ? true : isAssigned;
              }).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: widget.db
              .collection('checkins')
              .where('date', isEqualTo: _todayKey)
              .snapshots(),
          builder: (ctx2, ciSnap) {
            if (ciSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final checkIns = ciSnap.data?.docs ?? [];
            final checkedInUids = checkIns
                .map((d) =>
                    (d.data() as Map)['uid'] as String? ?? '')
                .toSet();

            if (groups.isEmpty) {
              return _SimpleTodayList(
                  checkIns: checkIns,
                  totalCheckedIn: checkIns.length);
            }

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.surface,
                  child: Row(
                    children: [
                      const Icon(Icons.people,
                          color: AppTheme.navy, size: 20),
                      const SizedBox(width: 10),
                      Text(
                          '${checkIns.length} checked in today',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const Spacer(),
                      Text(
                          DateFormat('MMMM d')
                              .format(DateTime.now()),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textHint)),
                    ],
                  ),
                ),
                AppTheme.goldDivider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final gData = groups[i].data()
                          as Map<String, dynamic>;
                      final gName =
                          gData['name'] as String? ?? 'Class';
                      final members = List<String>.from(
                          gData['memberUids'] as List? ?? []);
                      final mentors = List<String>.from(
                          gData['mentorUids'] as List? ?? []);
                      final seconds = List<String>.from(
                          gData['secondUids'] as List? ?? []);

                      // Determine if this user can check in for this class
                      final canCheckIn = widget.user.isAdmin ||
                          mentors.contains(widget.user.uid) ||
                          seconds.contains(widget.user.uid);

                      final classCheckedIn = members
                          .where(
                              (uid) => checkedInUids.contains(uid))
                          .toSet();
                      final classAbsent = members
                          .where((uid) =>
                              !checkedInUids.contains(uid))
                          .toList();
                      final mentorIn = mentors
                          .any((m) => checkedInUids.contains(m));
                      final secondIn = seconds
                          .any((s) => checkedInUids.contains(s));

                      return _ClassTodayCard(
                        groupId: groups[i].id,
                        className: gName,
                        totalStudents: members.length,
                        checkedInCount: classCheckedIn.length,
                        absentUids: classAbsent,
                        mentorIn: mentorIn,
                        secondIn: secondIn,
                        hasMentor: mentors.isNotEmpty,
                        hasSecond: seconds.isNotEmpty,
                        db: widget.db,
                        user: widget.user,
                        canCheckIn: canCheckIn,
                        todayKey: _todayKey,
                        checkedInUids: checkedInUids,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SimpleTodayList extends StatelessWidget {
  final List<QueryDocumentSnapshot> checkIns;
  final int totalCheckedIn;
  const _SimpleTodayList(
      {required this.checkIns, required this.totalCheckedIn});

  @override
  Widget build(BuildContext context) {
    if (checkIns.isEmpty) {
      return const Center(
          child: Text('No check-ins today',
              style: TextStyle(color: AppTheme.textHint)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: checkIns.length,
      itemBuilder: (_, i) {
        final d = checkIns[i].data() as Map<String, dynamic>;
        final ts = d['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (d['timestamp'] as Timestamp).millisecondsSinceEpoch)
            : DateTime.now();
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 18,
            backgroundColor:
                AppTheme.success.withValues(alpha: 0.1),
            child: const Icon(Icons.check,
                color: AppTheme.success, size: 18),
          ),
          title: Text(d['name'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Text(DateFormat('h:mm a').format(ts),
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textHint)),
        );
      },
    );
  }
}

// ── Class Today Card ───────────────────────────────────────────────
class _ClassTodayCard extends StatefulWidget {
  final String groupId;
  final String className;
  final int totalStudents;
  final int checkedInCount;
  final List<String> absentUids;
  final bool mentorIn;
  final bool secondIn;
  final bool hasMentor;
  final bool hasSecond;
  final FirebaseFirestore db;
  final UserModel user;
  final bool canCheckIn;
  final String todayKey;
  final Set<String> checkedInUids;
  const _ClassTodayCard({
    required this.groupId,
    required this.className,
    required this.totalStudents,
    required this.checkedInCount,
    required this.absentUids,
    required this.mentorIn,
    required this.secondIn,
    required this.hasMentor,
    required this.hasSecond,
    required this.db,
    required this.user,
    required this.canCheckIn,
    required this.todayKey,
    required this.checkedInUids,
  });

  @override
  State<_ClassTodayCard> createState() => _ClassTodayCardState();
}

class _ClassTodayCardState extends State<_ClassTodayCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pct = widget.totalStudents > 0
        ? widget.checkedInCount / widget.totalStudents
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.className,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ),
                      // Permission badge
                      if (widget.canCheckIn)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Can check in',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600)),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                          _expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppTheme.textHint),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppTheme.surfaceVariant,
                      color: pct >= 1.0
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${widget.checkedInCount}/${widget.totalStudents} checked in',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      if (widget.hasMentor) ...[
                        _Badge(
                            label: 'Mentor',
                            ok: widget.mentorIn),
                        const SizedBox(width: 6),
                      ],
                      if (widget.hasSecond)
                        _Badge(label: '2nd', ok: widget.secondIn),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            // Absent list
            widget.absentUids.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 16, color: AppTheme.success),
                        SizedBox(width: 6),
                        Text('Everyone checked in!',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.success)),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Absent (${widget.absentUids.length}):',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.error),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...widget.absentUids.map(
                          (uid) => FutureBuilder<DocumentSnapshot>(
                            future: widget.db
                                .collection('users')
                                .doc(uid)
                                .get(),
                            builder: (_, snap) {
                              final name =
                                  snap.data?.exists == true
                                      ? (snap.data!.data()
                                              as Map)[
                                              'displayName']
                                          as String? ??
                                          uid
                                      : uid;
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.close,
                                        size: 14,
                                        color: AppTheme.error),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme
                                                  .textSecondary)),
                                    ),
                                    // Check-in button for absent student
                                    if (widget.canCheckIn)
                                      TextButton(
                                        onPressed: () =>
                                            _checkInStudent(
                                                uid, name),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              AppTheme.success,
                                          padding: const EdgeInsets
                                              .symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                        ),
                                        child: const Text(
                                            'Check In',
                                            style: TextStyle(
                                                fontSize: 11)),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkInStudent(String uid, String name) async {
    try {
      // Check if already checked in (concurrent update)
      final existing = await widget.db
          .collection('checkins')
          .where('uid', isEqualTo: uid)
          .where('date', isEqualTo: widget.todayKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('$name is already checked in'),
                duration: const Duration(seconds: 2)),
          );
        }
        return;
      }
      await widget.db.collection('checkins').add({
        'uid': uid,
        'name': name,
        'checkedInBy': widget.user.uid,
        'checkedInByName': widget.user.displayName,
        'date': widget.todayKey,
        'timestamp': FieldValue.serverTimestamp(),
        'checkOutTime': null,
        'status': 'checkedIn',
        'classId': widget.groupId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$name checked in!'),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool ok;
  const _Badge({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppTheme.success : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check : Icons.close,
              size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
