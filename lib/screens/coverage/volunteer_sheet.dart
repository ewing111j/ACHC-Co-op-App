// lib/screens/coverage/volunteer_sheet.dart
// Bottom sheet: shows who has volunteered to cover an absence, and lets
// a parent volunteer or an admin accept a volunteer.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../models/coverage_models.dart';
import '../../models/user_model.dart';
import '../../services/coverage_service.dart';
import '../../utils/app_theme.dart';

class VolunteerSheet extends StatefulWidget {
  final MentorAbsenceModel absence;
  final UserModel currentUser;
  final CoverageService service;

  const VolunteerSheet({
    super.key,
    required this.absence,
    required this.currentUser,
    required this.service,
  });

  @override
  State<VolunteerSheet> createState() => _VolunteerSheetState();
}

class _VolunteerSheetState extends State<VolunteerSheet> {
  bool _submitting = false;

  Future<void> _offerCoverage() async {
    setState(() => _submitting = true);
    try {
      await widget.service.offerCoverage(
          widget.absence.id, widget.currentUser);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Thank you! Your offer has been recorded.'),
              backgroundColor: AppTheme.classesColor),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _acceptVolunteer(CoverageVolunteerModel vol) async {
    try {
      await widget.service.acceptVolunteer(widget.absence.id, vol);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vol.volunteerName} confirmed as cover.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEEE, MMM d').format(widget.absence.absenceDate);
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coverage Volunteers',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyDark)),
                const SizedBox(height: 4),
                Text(
                    '${widget.absence.className} · $dateStr · ${widget.absence.period}',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 13)),
                const SizedBox(height: 20),

                // Volunteer list
                StreamBuilder<List<CoverageVolunteerModel>>(
                  stream: widget.service
                      .streamVolunteersForAbsence(widget.absence.id),
                  builder: (context, snap) {
                    final volunteers = snap.data ?? [];
                    final myUid = widget.currentUser.uid;
                    final iHaveVolunteered =
                        volunteers.any((v) => v.volunteerUid == myUid);

                    return Column(
                      children: [
                        if (volunteers.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No volunteers yet — be the first!',
                              style: TextStyle(
                                  color: AppTheme.textHint, fontSize: 14),
                            ),
                          )
                        else
                          ...volunteers.asMap().entries.map((entry) {
                            final i = entry.key;
                            final vol = entry.value;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.classesColor.withValues(alpha: 0.15),
                                child: Text(
                                  vol.volunteerName.isNotEmpty
                                      ? vol.volunteerName[0].toUpperCase()
                                      : '?',
                                  style:
                                      const TextStyle(color: AppTheme.classesColor),
                                ),
                              ),
                              title: Text(vol.volunteerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  DateFormat('MMM d, h:mm a')
                                      .format(vol.offeredAt),
                                  style: const TextStyle(fontSize: 12)),
                              trailing: vol.accepted
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : widget.currentUser.isAdmin
                                      ? TextButton(
                                          onPressed: () =>
                                              _acceptVolunteer(vol),
                                          child: const Text('Accept',
                                              style: TextStyle(
                                                  color: AppTheme.classesColor)),
                                        )
                                      : null,
                            )
                                .animate(
                                    delay: Duration(milliseconds: 50 * i))
                                .fadeIn(duration: 300.ms)
                                .slideX(begin: 0.05, end: 0);
                          }),

                        const Divider(height: 24),

                        // Offer button
                        if (!iHaveVolunteered &&
                            !widget.currentUser.isStudent &&
                            widget.absence.mentorUid !=
                                widget.currentUser.uid)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                  Icons.volunteer_activism,
                                  size: 18),
                              label: const Text('I Can Cover This'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.classesColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12))),
                              onPressed: _submitting ? null : _offerCoverage,
                            ),
                          )
                        else if (iHaveVolunteered)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color:
                                    AppTheme.classesColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.classesColor
                                        .withValues(alpha: 0.4))),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: AppTheme.classesColor, size: 18),
                                SizedBox(width: 8),
                                Text('You\'ve offered to cover',
                                    style: TextStyle(
                                        color: AppTheme.classesColor,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOut)
        .fadeIn(duration: 250.ms);
  }
}
