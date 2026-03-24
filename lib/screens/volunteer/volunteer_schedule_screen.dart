// lib/screens/volunteer/volunteer_schedule_screen.dart
// P1-1: Full volunteer rotation schedule — read-only for all users,
// CSV upload for admins.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';

class VolunteerScheduleScreen extends StatefulWidget {
  final UserModel user;
  const VolunteerScheduleScreen({super.key, required this.user});

  @override
  State<VolunteerScheduleScreen> createState() =>
      _VolunteerScheduleScreenState();
}

class _VolunteerScheduleScreenState
    extends State<VolunteerScheduleScreen> {
  List<Map<String, dynamic>> _weeks = [];
  bool _loading = true;
  bool _uploading = false;
  String? _uploadMessage;

  @override
  void initState() {
    super.initState();
    _loadWeeks();
  }

  Future<void> _loadWeeks() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('volunteer_rotations')
          .orderBy('publishedAt', descending: true)
          .limit(12)
          .get();
      setState(() {
        _weeks = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ── Admin: CSV upload ────────────────────────────────────────────────────

  Future<void> _uploadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final csv = String.fromCharCodes(bytes);
    final rows = csv.split('\n').skip(1); // skip header

    setState(() {
      _uploading = true;
      _uploadMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      int count = 0;

      for (final row in rows) {
        final cols = row.trim().split(',');
        if (cols.length < 4) continue;

        final weekId = cols[0].trim();
        final day = cols[1].trim().toLowerCase();
        final dutyType = cols[2].trim().toLowerCase();
        final names = cols[3].trim().split(';').map((n) => n.trim()).toList();

        // Validate
        final validWeekId =
            RegExp(r'^\d{4}-W\d{2}$').hasMatch(weekId);
        final validDay =
            ['mon', 'tue', 'wed', 'thu', 'fri'].contains(day);
        final validDuty =
            ['lunch', 'recess', 'thursday_extra'].contains(dutyType);
        if (!validWeekId || !validDay || !validDuty) continue;

        final ref = db.collection('volunteer_rotations').doc(weekId);

        if (dutyType == 'lunch') {
          batch.set(
              ref, {'lunchSlots.$day': names, 'publishedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
        } else if (dutyType == 'recess') {
          batch.set(
              ref, {'recessSlots.$day': names, 'publishedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
        } else if (dutyType == 'thursday_extra') {
          batch.set(
              ref, {'thursdayExtra': names, 'publishedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
        }
        count++;
      }

      await batch.commit();
      setState(() {
        _uploadMessage = '✅ $count rows imported successfully';
        _uploading = false;
      });
      await _loadWeeks();
    } catch (e) {
      setState(() {
        _uploadMessage = '❌ Import failed: $e';
        _uploading = false;
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
        title: const Text('Volunteer Schedule',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _uploadCsv,
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_uploading ? 'Uploading…' : 'Upload CSV'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_uploadMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: _uploadMessage!.startsWith('✅')
                        ? Colors.green[50]
                        : Colors.red[50],
                    child: Text(_uploadMessage!,
                        style: TextStyle(
                          color: _uploadMessage!.startsWith('✅')
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontSize: 13,
                        )),
                  ),
                Expanded(
                  child: _weeks.isEmpty
                      ? const Center(
                          child: Text('No rotation data posted yet.',
                              style: TextStyle(color: Colors.black45)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _weeks.length,
                          itemBuilder: (context, i) {
                            return _WeekExpansionTile(
                                weekData: _weeks[i],
                                index: i);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _WeekExpansionTile extends StatelessWidget {
  final Map<String, dynamic> weekData;
  final int index;
  const _WeekExpansionTile(
      {required this.weekData, required this.index});

  @override
  Widget build(BuildContext context) {
    final weekId = weekData['id'] as String? ?? '';
    final weekLabel = weekData['weekLabel'] as String? ?? weekId;
    final notes = weekData['notes'] as String?;
    final lunchSlots =
        (weekData['lunchSlots'] as Map<String, dynamic>?) ?? {};
    final recessSlots =
        (weekData['recessSlots'] as Map<String, dynamic>?) ?? {};
    final thursdayExtra =
        List<String>.from(weekData['thursdayExtra'] as List? ?? []);

    const days = ['mon', 'tue', 'wed', 'thu', 'fri'];
    const dayLabels = {
      'mon': 'Monday',
      'tue': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'fri': 'Friday',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(weekLabel,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: notes != null
            ? Text(notes,
                style: const TextStyle(fontSize: 12, color: Colors.black54))
            : null,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.map((day) {
                final lunch = List<String>.from(
                    lunchSlots[day] as List? ?? []);
                final recess = List<String>.from(
                    recessSlots[day] as List? ?? []);
                final hasThursday =
                    day == 'thu' && thursdayExtra.isNotEmpty;

                if (lunch.isEmpty && recess.isEmpty && !hasThursday) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayLabels[day]!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.navy)),
                    if (lunch.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text('Lunch: ${lunch.join(', ')}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    if (recess.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text('Recess: ${recess.join(', ')}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    if (hasThursday)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2),
                        child: Text(
                            'Special: ${thursdayExtra.join(', ')}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(height: 6),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    )
        .animate(delay: AppAnimations.staggerItemDelay * index)
        .fadeIn()
        .moveY(
          begin: 8,
          end: 0,
          duration: AppAnimations.cardFadeInDuration,
        );
  }
}
