import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/memory/memory_models.dart';
import '../../models/user_model.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import 'content_card_screen.dart';
import 'by_unit_screen.dart';
import 'by_subject_screen.dart';
import 'special_collections_screen.dart';
import 'parent_dashboard_screen.dart';
import 'drill_setup_screen.dart';
import 'battle_entry_screen.dart';
import 'achievements_screen.dart';
import 'memory_settings_screen.dart';
import 'content_manager_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MemoryWorkHomeScreen
// ─────────────────────────────────────────────────────────────────────────────

class MemoryWorkHomeScreen extends StatefulWidget {
  final UserModel user;

  const MemoryWorkHomeScreen({super.key, required this.user});

  @override
  State<MemoryWorkHomeScreen> createState() => _MemoryWorkHomeScreenState();
}

class _MemoryWorkHomeScreenState extends State<MemoryWorkHomeScreen> {
  late MemoryProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<MemoryProvider>();
      final studentId = widget.user.isStudent
          ? widget.user.uid
          : (widget.user.isParent && widget.user.kidUids.isNotEmpty
              ? widget.user.kidUids.first
              : null);
      _provider.load(studentId: studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<MemoryProvider>(),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.navy,
          foregroundColor: Colors.white,
          title: const Text('Memory Work',
              style: TextStyle(fontWeight: FontWeight.w700)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (widget.user.isAdmin)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemoryWorkSettingsScreen(user: widget.user),
                  ),
                ),
              ),
          ],
        ),
        body: Consumer<MemoryProvider>(
          builder: (context, provider, _) {
            if (provider.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(provider.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.load(
                        studentId: widget.user.isStudent ? widget.user.uid : null,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return _HomeBody(user: widget.user, provider: provider);
          },
        ),
      ),
    );
  }
}

// ─── Home Body ─────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final UserModel user;
  final MemoryProvider provider;

  const _HomeBody({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    final cycleLabel = provider.activeCycle?.name ?? 'Cycle 2';
    final unit = provider.currentUnit;
    final lumen = provider.lumenState;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cycle / unit subtitle
        Text(
          '$cycleLabel · Unit $unit',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Lumen character panel
        _LumenPanel(lumen: lumen, user: user),
        const SizedBox(height: 20),

        // Navigation cards row
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.grid_view_rounded,
                label: 'By Unit',
                color: AppTheme.navy,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ByUnitScreen(user: user),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavCard(
                icon: Icons.category_outlined,
                label: 'By Subject',
                color: AppTheme.navy,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BySubjectScreen(user: user),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavCard(
                icon: Icons.collections_bookmark_outlined,
                label: 'Collections',
                color: AppTheme.navy,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SpecialCollectionsScreen(user: user),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // "THIS UNIT" section
        Row(
          children: [
            const Text(
              'THIS UNIT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Unit $unit',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Subject grid
        _SubjectGrid(user: user, provider: provider, unitNumber: unit),
        const SizedBox(height: 20),

        // Drill and Battle row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DrillSetupScreen(user: user),
                  ),
                ),
                icon: const Icon(Icons.fitness_center, size: 18),
                label: const Text('Drill Mode'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: provider.currentUnit >= 4
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BattleEntryScreen(user: user),
                          ),
                        )
                    : null,
                icon: Icon(
                  provider.currentUnit >= 4 ? Icons.flash_on : Icons.lock_outline,
                  size: 18,
                ),
                label: Text(
                  provider.currentUnit >= 4 ? 'Battle Mode' : 'Locked',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.currentUnit >= 4
                      ? AppTheme.gold
                      : Colors.grey[300],
                  foregroundColor: provider.currentUnit >= 4
                      ? AppTheme.navy
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Achievements button
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AchievementsScreen(user: user),
            ),
          ),
          icon: const Icon(Icons.emoji_events_outlined, size: 18),
          label: const Text('Achievements'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.gold),
            foregroundColor: AppTheme.navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),

        // Parent/Mentor/Admin extras
        if (!user.isStudent) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParentDashboardScreen(user: user),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline, size: 18),
                  label: const Text('Family Progress'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.navy),
                    foregroundColor: AppTheme.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Admin: Content Manager shortcut
        if (user.isAdmin) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContentManagerScreen(user: user),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Content Manager'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey),
                    foregroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Lumen Panel ──────────────────────────────────────────────────────────────

class _LumenPanel extends StatelessWidget {
  final LumenStateModel? lumen;
  final UserModel user;

  const _LumenPanel({this.lumen, required this.user});

  @override
  Widget build(BuildContext context) {
    final level = lumen?.lumenLevel ?? 1;
    final levelName = lumen?.levelName ?? 'Initiate';
    final totalWp = lumen?.totalWp ?? 0;
    final progress = lumen?.levelProgress ?? 0.0;
    final wpProgress = lumen?.wpProgressInLevel ?? 0;
    final wpNeeded = lumen?.wpNeededForNextLevel ?? 200;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Lumen icon placeholder (will be replaced with actual image assets)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _levelEmoji(level),
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Lumen',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Level $level',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    levelName,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  // WP progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: AppTheme.gold,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$wpProgress / $wpNeeded WP · Total: $totalWp WP',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _levelEmoji(int level) {
    switch (level) {
      case 1:
        return '🕯️';
      case 2:
        return '📜';
      case 3:
        return '🎓';
      case 4:
        return '⚔️';
      case 5:
        return '👑';
      default:
        return '🕯️';
    }
  }
}

// ─── Subject Grid ──────────────────────────────────────────────────────────────

class _SubjectGrid extends StatelessWidget {
  final UserModel user;
  final MemoryProvider provider;
  final int unitNumber;

  const _SubjectGrid({
    required this.user,
    required this.provider,
    required this.unitNumber,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = provider.subjects;
    if (subjects.isEmpty) {
      return const Center(
        child: Text(
          'Subjects loading...',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, i) {
        final subject = subjects[i];
        return _SubjectTile(
          subject: subject,
          user: user,
          unitNumber: unitNumber,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentCardScreen(
                subjectId: subject.id,
                unitNumber: unitNumber,
                user: user,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final SubjectModel subject;
  final UserModel user;
  final int unitNumber;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.subject,
    required this.user,
    required this.unitNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _subjectIcon(subject.id),
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                _shortName(subject.name),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subjectIcon(String id) {
    const icons = {
      'religion': '✝️',
      'scripture': '📖',
      'latin': '🏛️',
      'grammar': '✏️',
      'history': '🏰',
      'science': '🔬',
      'math': '➕',
      'geography': '🌍',
      'great_words_1': '💬',
      'great_words_2': '📝',
      'timeline': '⏳',
    };
    return icons[id] ?? '📚';
  }

  String _shortName(String name) {
    if (name.length <= 10) return name;
    return name.split(' ').first;
  }
}

// ─── Navigation Card ──────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
