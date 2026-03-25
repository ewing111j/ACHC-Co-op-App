// lib/screens/memory/leaderboard_screen.dart
// P2-3: Memory Work Leaderboard — family tab + class tab.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import '../../widgets/lumen_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  final UserModel user;
  const LeaderboardScreen({super.key, required this.user});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _showRealNames = false;

  @override
  void initState() {
    super.initState();
    final hasBothTabs =
        widget.user.canMentor || widget.user.isAdmin;
    _tabs = TabController(length: hasBothTabs ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _hasBothTabs =>
      widget.user.canMentor || widget.user.isAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('Leaderboard',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          if (_hasBothTabs)
            IconButton(
              icon: Icon(
                _showRealNames
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white70,
              ),
              tooltip: _showRealNames ? 'Hide Names' : 'Show Names',
              onPressed: () =>
                  setState(() => _showRealNames = !_showRealNames),
            ),
        ],
        bottom: _hasBothTabs
            ? TabBar(
                controller: _tabs,
                indicatorColor: AppTheme.gold,
                labelColor: AppTheme.gold,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(text: 'Family'),
                  Tab(text: 'Class'),
                ],
              )
            : null,
      ),
      body: _hasBothTabs
          ? TabBarView(
              controller: _tabs,
              children: [
                _FamilyLeaderboard(user: widget.user),
                _ClassLeaderboard(
                    user: widget.user, showRealNames: _showRealNames),
              ],
            )
          : _FamilyLeaderboard(user: widget.user),
    );
  }
}

// ── Family Leaderboard ────────────────────────────────────────────────────────
class _FamilyLeaderboard extends StatelessWidget {
  final UserModel user;
  const _FamilyLeaderboard({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.kidUids.isEmpty) {
      return const _EmptyState(
          msg: 'No children linked to this account yet.');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lumen_state')
          .where('studentId', whereIn: user.kidUids)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
              msg: 'No memory work data for your children yet.');
        }
        final states = docs
            .map((d) => LumenStateModel.fromMap(
                d.id, d.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.totalWp.compareTo(a.totalWp));

        return _RankList(
          states: states,
          showRealNames: true,
          nameResolver: (s) => s.studentId,
        );
      },
    );
  }
}

// ── Class Leaderboard ─────────────────────────────────────────────────────────
class _ClassLeaderboard extends StatefulWidget {
  final UserModel user;
  final bool showRealNames;
  const _ClassLeaderboard(
      {required this.user, required this.showRealNames});

  @override
  State<_ClassLeaderboard> createState() => _ClassLeaderboardState();
}

class _ClassLeaderboardState extends State<_ClassLeaderboard> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    final classIds = widget.user.mentorClassIds;
    if (classIds.isEmpty) {
      return const _EmptyState(msg: 'No classes assigned.');
    }

    return Column(
      children: [
        // Class filter chips
        if (classIds.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _ClassChip(
                  label: 'All Classes',
                  selected: _selectedClassId == null,
                  onTap: () =>
                      setState(() => _selectedClassId = null),
                ),
                ...classIds.map((cid) => _ClassChip(
                      label: cid,
                      selected: _selectedClassId == cid,
                      onTap: () =>
                          setState(() => _selectedClassId = cid),
                    )),
              ],
            ),
          ),

        // Leaderboard list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _selectedClassId != null
                ? FirebaseFirestore.instance
                    .collection('lumen_state')
                    .where('classIds',
                        arrayContains: _selectedClassId)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('lumen_state')
                    .where('classIds',
                        arrayContainsAny: classIds)
                    .limit(50)
                    .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const _EmptyState(
                    msg: 'No student data for this class yet.');
              }
              final states = docs
                  .map((d) => LumenStateModel.fromMap(
                      d.id, d.data() as Map<String, dynamic>))
                  .toList()
                ..sort((a, b) => b.totalWp.compareTo(a.totalWp));

              return _RankList(
                states: states,
                showRealNames: widget.showRealNames,
                nameResolver: (s) => s.studentId,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ClassChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.memoryWorkColor.withValues(alpha: 0.2),
      ),
    );
  }
}

// ── Rank list ─────────────────────────────────────────────────────────────────
class _RankList extends StatelessWidget {
  final List<LumenStateModel> states;
  final bool showRealNames;
  final String Function(LumenStateModel) nameResolver;

  const _RankList({
    required this.states,
    required this.showRealNames,
    required this.nameResolver,
  });

  String _anonymizedName(int index) {
    const labels = [
      'Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon',
      'Zeta', 'Eta', 'Theta', 'Iota', 'Kappa',
    ];
    return index < labels.length
        ? 'Scholar ${labels[index]}'
        : 'Scholar ${index + 1}';
  }

  Widget _medal(int rank) {
    switch (rank) {
      case 1:
        return const Text('🥇',
            style: TextStyle(fontSize: 22))
            .animate()
            .rotate(begin: -0.1, end: 0, duration: 400.ms);
      case 2:
        return const Text('🥈',
            style: TextStyle(fontSize: 22))
            .animate()
            .rotate(begin: -0.08, end: 0, duration: 400.ms);
      case 3:
        return const Text('🥉',
            style: TextStyle(fontSize: 22))
            .animate()
            .rotate(begin: -0.06, end: 0, duration: 400.ms);
      default:
        return SizedBox(
          width: 32,
          child: Text('#$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textHint,
                  fontSize: 14)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: states.length,
      itemBuilder: (context, index) {
        final s = states[index];
        final rank = index + 1;
        final name = showRealNames
            ? nameResolver(s)
            : _anonymizedName(index);
        return _RankRow(
          rank: rank,
          medal: _medal(rank),
          state: s,
          name: name,
          index: index,
        );
      },
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final Widget medal;
  final LumenStateModel state;
  final String name;
  final int index;

  const _RankRow({
    required this.rank,
    required this.medal,
    required this.state,
    required this.name,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: rank <= 3
            ? AppTheme.gold.withValues(alpha: 0.07)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3
              ? AppTheme.gold.withValues(alpha: 0.3)
              : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: medal),
          const SizedBox(width: 8),
          LumenAvatarWidget(
            level: state.lumenLevel,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.navyDark)),
                Text(state.levelName,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: AppAnimations.navTransitionDuration,
            child: Text(
              key: ValueKey(state.totalWp),
              '${state.totalWp} WP',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.memoryWorkColor),
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: AppAnimations.cardFadeInDuration)
        .moveX(begin: 12, end: 0);
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 64,
                color: AppTheme.gold.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textHint, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
