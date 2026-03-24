// lib/widgets/volunteer_rotation_card.dart
// P1-1: "This Week" Volunteer Rotation card — shown at top of HomeScreen.
// Loads volunteer_rotations/{YYYY-Www} from Firestore.
// Supports prev/next week navigation.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_animations.dart';
import '../screens/volunteer/volunteer_schedule_screen.dart';

class VolunteerRotationCard extends StatefulWidget {
  final UserModel? user;
  const VolunteerRotationCard({super.key, this.user});

  @override
  State<VolunteerRotationCard> createState() => _VolunteerRotationCardState();
}

class _VolunteerRotationCardState extends State<VolunteerRotationCard> {
  // ── Week navigation state ────────────────────────────────────────────────
  DateTime _weekAnchor = _currentWeekMonday();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  static DateTime _currentWeekMonday() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  static String _weekId(DateTime monday) {
    // ISO 8601 week: YYYY-Www
    final jan4 = DateTime(monday.year, 1, 4);
    final weekNum = ((monday.difference(
                      DateTime(jan4.year, 1, 1).subtract(
                        Duration(days: DateTime(jan4.year, 1, 1).weekday - 1),
                      ))
                    .inDays) ~/
                7) +
            1;
    return '${monday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  String get _currentWeekId => _weekId(_weekAnchor);

  String get _weekLabel {
    final end = _weekAnchor.add(const Duration(days: 4));
    return '${DateFormat('MMM d').format(_weekAnchor)} – ${DateFormat('MMM d').format(end)}';
  }

  String get _todayKey {
    const keys = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return keys[DateTime.now().weekday];
  }

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('volunteer_rotations')
          .doc(_currentWeekId)
          .get();
      setState(() {
        _data = doc.exists ? doc.data() : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load rotation';
        _loading = false;
      });
    }
  }

  void _prevWeek() {
    setState(() {
      _weekAnchor = _weekAnchor.subtract(const Duration(days: 7));
    });
    _loadWeek();
  }

  void _nextWeek() {
    setState(() {
      _weekAnchor = _weekAnchor.add(const Duration(days: 7));
    });
    _loadWeek();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with week navigation
            Row(
              children: [
                const Icon(Icons.volunteer_activism_outlined,
                    size: 18, color: AppTheme.navy),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Volunteer Rotation',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _prevWeek,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppTheme.navy,
                ),
                Text(
                  _weekLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                IconButton(
                  onPressed: _nextWeek,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppTheme.navy,
                ),
              ],
            ),
            const Divider(height: 12),
            // Body — AnimatedSwitcher for week changes
            AnimatedSwitcher(
              duration: AppAnimations.weekChangeDuration,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _loading
                  ? _LoadingShimmer(key: ValueKey('loading_$_currentWeekId'))
                  : _error != null
                      ? _ErrorState(key: ValueKey('error_$_currentWeekId'))
                      : _data == null
                          ? _EmptyState(
                              key: ValueKey('empty_$_currentWeekId'))
                          : _RotationBody(
                              key: ValueKey('data_$_currentWeekId'),
                              data: _data!,
                              todayKey: _todayKey,
                            ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VolunteerScheduleScreen(
                        user: widget.user!,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.navy,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(
                  'View Full Schedule →',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppAnimations.cardFadeInDuration)
        .moveY(
          begin: AppAnimations.cardEntranceMoveY,
          end: 0,
          duration: AppAnimations.cardFadeInDuration,
        );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _shimmerBar(0.9),
        const SizedBox(height: 6),
        _shimmerBar(0.6),
      ],
    );
  }

  Widget _shimmerBar(double widthFraction) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: widthFraction),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return LayoutBuilder(builder: (context, constraints) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            height: 12,
            width: constraints.maxWidth * value,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
          );
        });
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No rotation posted yet for this week.',
        style: TextStyle(color: Colors.black45, fontSize: 13),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Could not load volunteer rotation.',
        style: TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  }
}

class _RotationBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String todayKey;

  const _RotationBody({super.key, required this.data, required this.todayKey});

  @override
  Widget build(BuildContext context) {
    final lunchSlots =
        (data['lunchSlots'] as Map<String, dynamic>?) ?? {};
    final recessSlots =
        (data['recessSlots'] as Map<String, dynamic>?) ?? {};
    final thursdayExtra =
        List<String>.from(data['thursdayExtra'] as List? ?? []);
    final notes = data['notes'] as String?;

    final lunchToday = List<String>.from(lunchSlots[todayKey] as List? ?? []);
    final recessToday =
        List<String>.from(recessSlots[todayKey] as List? ?? []);
    final isThursday = todayKey == 'thu';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lunchToday.isNotEmpty) ...[
          _DutyRow(
              icon: Icons.lunch_dining_outlined,
              label: "Today's Lunch",
              names: lunchToday),
          const SizedBox(height: 6),
        ],
        if (recessToday.isNotEmpty) ...[
          _DutyRow(
              icon: Icons.directions_run_outlined,
              label: "Today's Recess",
              names: recessToday),
          const SizedBox(height: 6),
        ],
        if (isThursday && thursdayExtra.isNotEmpty) ...[
          _DutyRow(
              icon: Icons.star_outline_rounded,
              label: 'Thursday Special',
              names: thursdayExtra),
          const SizedBox(height: 6),
        ],
        if (lunchToday.isEmpty && recessToday.isEmpty)
          const Text(
            'No duties listed for today.',
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '📌 $notes',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ],
    );
  }
}

class _DutyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> names;

  const _DutyRow(
      {required this.icon, required this.label, required this.names});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.navy),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navy)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: names
                    .map((name) => _NameChip(name: name))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NameChip extends StatelessWidget {
  final String name;
  const _NameChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppTheme.navy.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy),
          ),
        ),
        const SizedBox(width: 4),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// (VolunteerScheduleScreenStub removed — using real VolunteerScheduleScreen)
