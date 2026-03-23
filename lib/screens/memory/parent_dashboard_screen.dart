import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/memory/memory_models.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ParentDashboardScreen
// Shows all linked children's Memory Work progress at a glance.
// Child switcher pill is on individual browse screens; dashboard shows all.
// ─────────────────────────────────────────────────────────────────────────────

class ParentDashboardScreen extends StatefulWidget {
  final UserModel user;
  const ParentDashboardScreen({super.key, required this.user});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, ChildProgressSnapshot> _snapshots = {};
  Map<String, UserModel> _childUsers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (widget.user.kidUids.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<MemoryProvider>();

      // Load child user profiles from Firestore
      final db = provider.db;
      final childModels = <String, UserModel>{};
      for (final uid in widget.user.kidUids) {
        final doc = await db.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          childModels[uid] = UserModel.fromMap(doc.data()!, uid);
        }
      }

      // Load memory snapshots (lumen, achievements, recent progress)
      final snapshots =
          await provider.loadChildSnapshots(widget.user.kidUids);

      setState(() {
        _childUsers = childModels;
        _snapshots = snapshots;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load family progress: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Family Progress',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (widget.user.kidUids.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No students linked to this account.\nAsk an admin to link your students.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final provider = context.read<MemoryProvider>();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.user.kidUids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final childId = widget.user.kidUids[i];
        final child = _childUsers[childId];
        final snap = _snapshots[childId] ??
            const ChildProgressSnapshot(
                lumen: null, achievements: [], recentProgress: []);
        final name = child?.displayName ?? 'Student';
        return _ChildCard(
          childId: childId,
          childUser: child,
          name: name,
          snap: snap,
          subjects: provider.subjects,
        );
      },
    );
  }
}

// ─── Child Progress Card ──────────────────────────────────────────────────────

class _ChildCard extends StatefulWidget {
  final String childId;
  final UserModel? childUser;
  final String name;
  final ChildProgressSnapshot snap;
  final List<SubjectModel> subjects;

  const _ChildCard({
    required this.childId,
    required this.childUser,
    required this.name,
    required this.snap,
    required this.subjects,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  late bool _isYoungLearner;
  bool _togglingYL = false;

  @override
  void initState() {
    super.initState();
    _isYoungLearner = widget.childUser?.isYoungLearner ?? false;
  }

  Future<void> _toggleYoungLearner(bool val) async {
    setState(() => _togglingYL = true);
    try {
      final provider = context.read<MemoryProvider>();
      await provider.setYoungLearnerMode(widget.childId, enabled: val);
      setState(() {
        _isYoungLearner = val;
        _togglingYL = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(val
            ? 'Young Learner mode enabled for ${widget.name}'
            : 'Young Learner mode disabled for ${widget.name}'),
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {
      setState(() => _togglingYL = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + level badge
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.navy,
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppTheme.navy)),
                      if (widget.snap.lumen != null)
                        Text(
                          '${widget.snap.lumen!.levelName} · ${widget.snap.lumen!.totalWp} WP',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                if (widget.snap.lumen != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Lv ${widget.snap.lumen!.lumenLevel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
              ],
            ),

            // Lumen progress bar
            if (widget.snap.lumen != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.snap.lumen!.levelProgress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  color: AppTheme.gold,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.snap.lumen!.wpProgressInLevel} / ${widget.snap.lumen!.wpNeededForNextLevel} WP to next level',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Recent subjects practiced (last 7 days)
            _RecentSubjectsSection(recentProgress: widget.snap.recentProgress),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Mastery overview
            _MasterySection(
                recentProgress: widget.snap.recentProgress, subjects: widget.subjects),

            // Young Learner toggle
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.child_care_outlined, size: 18, color: AppTheme.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Young Learner Mode',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.navy)),
                      Text(
                        'Simplified interface with large icons and buttons',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                _togglingYL
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(
                        value: _isYoungLearner,
                        activeColor: AppTheme.navy,
                        onChanged: _toggleYoungLearner,
                      ),
              ],
            ),

            // Achievements
            if (widget.snap.achievements.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _AchievementsSection(achievements: widget.snap.achievements),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Recent Subjects Section ──────────────────────────────────────────────────

class _RecentSubjectsSection extends StatelessWidget {
  final List<StudentProgressModel> recentProgress;

  const _RecentSubjectsSection({required this.recentProgress});

  @override
  Widget build(BuildContext context) {
    // Count practice events and show summary
    final sessionCount = recentProgress.length;
    final subjectCount = recentProgress
        .map((p) => p.memoryItemId.split('_').take(2).join('_'))
        .toSet()
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_edu_outlined, size: 16, color: AppTheme.navy),
            const SizedBox(width: 6),
            Text(
              'Last 7 Days',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentProgress.isEmpty)
          Text(
            'No practice recorded this week.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          )
        else
          Text(
            '$sessionCount practice sessions across ~$subjectCount items',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
      ],
    );
  }
}

// ─── Mastery Section ──────────────────────────────────────────────────────────

class _MasterySection extends StatelessWidget {
  final List<StudentProgressModel> recentProgress;
  final List<SubjectModel> subjects;

  const _MasterySection(
      {required this.recentProgress, required this.subjects});

  @override
  Widget build(BuildContext context) {
    // Compute average mastery per subject (best mastery for rated items)
    final ratedItems = recentProgress.where((p) => p.masteryLevel > 0);
    final totalRated = ratedItems.length;
    final avgMastery = totalRated > 0
        ? ratedItems.fold(0, (s, p) => s + p.masteryLevel) / totalRated
        : 0.0;

    final got = recentProgress.where((p) => p.masteryLevel == 3).length;
    final getting = recentProgress.where((p) => p.masteryLevel == 2).length;
    final heard = recentProgress.where((p) => p.masteryLevel == 1).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_graph_outlined, size: 16, color: AppTheme.navy),
            const SizedBox(width: 6),
            Text(
              'Mastery Overview',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (totalRated == 0)
          Text(
            'No rated items yet.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          )
        else ...[
          _MasteryRow(
              label: 'Got It',
              count: got,
              total: totalRated,
              color: const Color(0xFF2E7D32)),
          const SizedBox(height: 4),
          _MasteryRow(
              label: 'Getting There',
              count: getting,
              total: totalRated,
              color: AppTheme.gold),
          const SizedBox(height: 4),
          _MasteryRow(
              label: 'Just Heard',
              count: heard,
              total: totalRated,
              color: Colors.blueGrey),
          const SizedBox(height: 6),
          Text(
            'Average: ${avgMastery.toStringAsFixed(1)}/3.0 · $totalRated items rated',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ],
    );
  }
}

class _MasteryRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _MasteryRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

// ─── Achievements Section ────────────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  final List<AchievementModel> achievements;

  const _AchievementsSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    final recent =
        achievements.take(4).toList(); // show up to 4 most recent badges

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_outlined, size: 16, color: AppTheme.gold),
            const SizedBox(width: 6),
            Text(
              'Achievements (${achievements.length})',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: recent
              .map((a) => Chip(
                    avatar: Icon(Icons.star_rounded,
                        size: 14, color: AppTheme.gold),
                    label: Text(
                      a.label,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: AppTheme.gold.withValues(alpha: 0.12),
                    side: BorderSide(
                        color: AppTheme.gold.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ))
              .toList(),
        ),
        if (achievements.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${achievements.length - 4} more',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
      ],
    );
  }
}

// ChildProgressSnapshot is defined in memory_provider.dart
