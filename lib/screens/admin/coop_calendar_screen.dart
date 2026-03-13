// lib/screens/admin/coop_calendar_screen.dart
// Admin can label each week of the year with a custom label
// Default: "ACHC Week XX, Unit XX"
// Displayed on: front page good-morning section, calendar view
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class CoopCalendarScreen extends StatefulWidget {
  const CoopCalendarScreen({super.key});

  @override
  State<CoopCalendarScreen> createState() => _CoopCalendarScreenState();
}

class _CoopCalendarScreenState extends State<CoopCalendarScreen> {
  final _db = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _controllers = {};
  Map<String, String> _savedLabels = {};
  bool _loading = true;
  bool _saving = false;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    final snap = await _db.collection('coopCalendar').get();
    final labels = <String, String>{};
    for (final doc in snap.docs) {
      labels[doc.id] = doc.data()['label'] as String? ?? '';
    }
    if (mounted) {
      setState(() {
        _savedLabels = labels;
        _loading = false;
      });
    }
  }

  // Build list of Monday dates for the selected year
  List<DateTime> _getMondaysForYear(int year) {
    final mondays = <DateTime>[];
    var d = DateTime(year, 1, 1);
    // Find first Monday
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    while (d.year <= year) {
      mondays.add(d);
      d = d.add(const Duration(days: 7));
    }
    return mondays;
  }

  String _weekKey(DateTime monday) =>
      DateFormat('yyyy-MM-dd').format(monday);

  String _defaultLabel(DateTime monday, int weekIndex) {
    return 'ACHC Week ${weekIndex + 1}, Unit ${(weekIndex ~/ 8) + 1}';
  }

  TextEditingController _ctrl(String key, int weekIndex, DateTime monday) {
    if (!_controllers.containsKey(key)) {
      final saved = _savedLabels[key];
      _controllers[key] = TextEditingController(
        text: saved ?? _defaultLabel(monday, weekIndex),
      );
    }
    return _controllers[key]!;
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final batch = _db.batch();
      for (final entry in _controllers.entries) {
        final ref = _db.collection('coopCalendar').doc(entry.key);
        batch.set(ref, {
          'label': entry.value.text.trim(),
          'weekStart': entry.key,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      // Reload
      await _loadLabels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Co-op calendar saved!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mondays = _getMondaysForYear(_selectedYear);
    final currentWeekKey = () {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      return DateFormat('yyyy-MM-dd').format(monday);
    }();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Co-op Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveAll,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save All',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Year selector
                Container(
                  color: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: AppTheme.navy, size: 18),
                      const SizedBox(width: 8),
                      const Text('School Year:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _selectedYear,
                        items: List.generate(5, (i) {
                          final y = DateTime.now().year - 1 + i;
                          return DropdownMenuItem(
                              value: y, child: Text('$y'));
                        }),
                        onChanged: (y) {
                          if (y != null) {
                            setState(() {
                              _selectedYear = y;
                              // Clear cached controllers for new year
                              _controllers.clear();
                            });
                          }
                        },
                      ),
                      const Spacer(),
                      Text('${mondays.length} weeks',
                          style: const TextStyle(
                              color: AppTheme.textHint,
                              fontSize: 12)),
                    ],
                  ),
                ),
                // Info banner
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: AppTheme.navy.withValues(alpha: 0.05),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 15, color: AppTheme.navy),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Labels appear on the home screen and calendar. '
                          'Leave as default or customise per week.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                AppTheme.goldDivider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: mondays.length,
                    itemBuilder: (_, i) {
                      final monday = mondays[i];
                      final key = _weekKey(monday);
                      final isCurrentWeek = key == currentWeekKey;
                      final ctrl = _ctrl(key, i, monday);
                      final dateRange =
                          '${DateFormat('MMM d').format(monday)} – '
                          '${DateFormat('MMM d').format(monday.add(const Duration(days: 6)))}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrentWeek
                              ? AppTheme.navy.withValues(alpha: 0.04)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isCurrentWeek
                                  ? AppTheme.navy.withValues(
                                      alpha: 0.3)
                                  : AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Week ${i + 1} · $dateRange',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isCurrentWeek
                                        ? AppTheme.navy
                                        : AppTheme.textHint,
                                    fontWeight: isCurrentWeek
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (isCurrentWeek) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.navy,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: const Text('THIS WEEK',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight:
                                                FontWeight.w700)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: ctrl,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8),
                                hintText: _defaultLabel(monday, i),
                                hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textHint),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.restore,
                                      size: 16),
                                  tooltip: 'Reset to default',
                                  onPressed: () {
                                    ctrl.text =
                                        _defaultLabel(monday, i);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveAll,
        backgroundColor: AppTheme.navy,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_outlined),
        label: const Text('Save All'),
      ),
    );
  }
}
