// lib/screens/coverage/coverage_screen.dart
// Main coverage hub — shows open absences and lets volunteers offer to help.
// Also entry point for mentors to report an absence.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/coverage_models.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/coverage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';
import 'report_absence_sheet.dart';
import 'volunteer_sheet.dart';

class CoverageScreen extends StatelessWidget {
  const CoverageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final service = CoverageService();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        foregroundColor: Colors.white,
        title: const Text('Coverage Board',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          if (!user!.isStudent)
            TextButton.icon(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppTheme.gold, size: 18),
              label: const Text('Report Absence',
                  style: TextStyle(color: AppTheme.gold, fontSize: 13)),
              onPressed: () => _showReportSheet(context, user),
            ),
        ],
      ),
      body: StreamBuilder<List<MentorAbsenceModel>>(
        stream: user!.isAdmin
            ? service.streamAllAbsences()
            : service.streamOpenAbsences(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final absences = snap.data ?? [];
          if (absences.isEmpty) {
            return _EmptyState(isAdmin: user!.isAdmin);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: absences.length,
            itemBuilder: (context, index) {
              return _AbsenceCard(
                absence: absences[index],
                currentUser: user,
                service: service,
              )
                  .animate(delay: Duration(milliseconds: 60 * index))
                  .fadeIn(duration: AppAnimations.navTransitionDuration)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  void _showReportSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportAbsenceSheet(mentor: user),
    );
  }
}

// ── Absence Card ─────────────────────────────────────────────────────────────
class _AbsenceCard extends StatelessWidget {
  final MentorAbsenceModel absence;
  final UserModel currentUser;
  final CoverageService service;

  const _AbsenceCard({
    required this.absence,
    required this.currentUser,
    required this.service,
  });

  Color get _statusColor {
    switch (absence.status) {
      case AbsenceStatus.covered:
        return Colors.green;
      case AbsenceStatus.uncovered:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (absence.status) {
      case AbsenceStatus.covered:
        return 'Covered';
      case AbsenceStatus.uncovered:
        return 'Needs Cover';
      default:
        return 'Open';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEEE, MMM d').format(absence.absenceDate);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(absence.className,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('${absence.mentorName} · $dateStr · ${absence.period}',
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            if (absence.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(absence.notes,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
            if (absence.status == AbsenceStatus.covered &&
                absence.coveringVolunteerName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text('Covered by ${absence.coveringVolunteerName}',
                      style: const TextStyle(
                          color: Colors.green, fontSize: 13)),
                ],
              ),
            ],
            // Action buttons
            if (absence.status != AbsenceStatus.covered) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!currentUser.isStudent &&
                      absence.mentorUid != currentUser.uid)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.volunteer_activism, size: 16),
                        label: const Text('Volunteer to Cover'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.classesColor,
                          side: const BorderSide(color: AppTheme.classesColor),
                        ),
                        onPressed: () =>
                            _showVolunteerSheet(context),
                      ),
                    ),
                  if (absence.mentorUid == currentUser.uid ||
                      currentUser.isAdmin) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                      onPressed: () =>
                          _confirmDelete(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showVolunteerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VolunteerSheet(
        absence: absence,
        currentUser: currentUser,
        service: service,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Absence'),
        content: const Text(
            'Are you sure you want to remove this absence report?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep')),
          TextButton(
            onPressed: () {
              service.deleteAbsence(absence.id);
              Navigator.pop(context);
            },
            child:
                const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isAdmin;
  const _EmptyState({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available,
              size: 64,
              color: AppTheme.classesColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No Open Absences',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyDark)),
          const SizedBox(height: 8),
          Text(
            isAdmin
                ? 'All classes are covered this week.'
                : 'No coverage needed right now.',
            style:
                const TextStyle(color: AppTheme.textHint, fontSize: 14),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
    );
  }
}
