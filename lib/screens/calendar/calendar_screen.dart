// lib/screens/calendar/calendar_screen.dart
// Shared schedule, admin editable, event notifications
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../models/event_model.dart';
import '../../utils/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _db = FirebaseFirestore.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calFormat = CalendarFormat.month;
  Map<DateTime, List<EventModel>> _events = {};

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_calFormat == CalendarFormat.month
                ? Icons.view_week
                : Icons.calendar_view_month),
            onPressed: () => setState(() => _calFormat =
                _calFormat == CalendarFormat.month
                    ? CalendarFormat.week
                    : CalendarFormat.month),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('events').orderBy('startDate').snapshots(),
        builder: (ctx, snap) {
          if (snap.hasData) {
            _events = {};
            for (final doc in snap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ev = EventModel.fromMap(data, doc.id);
              final key = DateTime(
                  ev.startDate.year, ev.startDate.month, ev.startDate.day);
              _events.putIfAbsent(key, () => []).add(ev);
            }
          }

          final selectedEvents = _getEventsForDay(_selectedDay);

          return Column(
            children: [
              // Calendar widget
              Container(
                color: AppTheme.surface,
                child: TableCalendar<EventModel>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calFormat,
                  selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                  eventLoader: _getEventsForDay,
                  onDaySelected: (sel, foc) {
                    setState(() {
                      _selectedDay = sel;
                      _focusedDay = foc;
                    });
                  },
                  onFormatChanged: (f) => setState(() => _calFormat = f),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.navy, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                        color: AppTheme.gold, shape: BoxShape.circle),
                    weekendTextStyle: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ),
              AppTheme.goldDivider(),
              // Events for selected day
              Expanded(
                child: selectedEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_outlined,
                                size: 48, color: AppTheme.textHint),
                            const SizedBox(height: 12),
                            Text(
                              DateFormat('MMMM d').format(_selectedDay),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            const Text('No events scheduled',
                                style: TextStyle(color: AppTheme.textHint)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: selectedEvents.length,
                        itemBuilder: (_, i) =>
                            _EventCard(event: selectedEvents[i], user: user, db: _db),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: (user.isAdmin || user.isParent)
          ? FloatingActionButton(
              onPressed: () => _showAddEvent(context, user),
              backgroundColor: AppTheme.calendarColor,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  List<EventModel> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  void _showAddEvent(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEventSheet(db: _db, user: user),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final EventModel event;
  final dynamic user;
  final FirebaseFirestore db;
  const _EventCard({required this.event, required this.user, required this.db});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppTheme.calendarColor, width: 4),
          top: BorderSide(color: AppTheme.cardBorder),
          right: BorderSide(color: AppTheme.cardBorder),
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            title: Text(event.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.description.isNotEmpty)
                  Text(event.description,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 2),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: AppTheme.textHint),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(event.startDate),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint),
                    ),
                    if (event.location != null &&
                        event.location!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.place_outlined,
                          size: 12, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(event.location!,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textHint),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: (user?.isAdmin == true || user?.uid == event.createdBy)
                ? IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.textHint),
                    onPressed: () =>
                        db.collection('events').doc(event.id).delete(),
                  )
                : null,
          ),
          // Add to calendar row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _addToGoogleCalendar(context),
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: const Text('Google Cal',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.calendarColor,
                    side: BorderSide(
                        color: AppTheme.calendarColor.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _addToIcal(context),
                  icon: const Icon(Icons.download_outlined, size: 14),
                  label: const Text('iCal / Apple',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.navy,
                    side: BorderSide(
                        color: AppTheme.navy.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens Google Calendar "add event" URL in the browser
  Future<void> _addToGoogleCalendar(BuildContext context) async {
    final fmt = DateFormat("yyyyMMdd'T'HHmmss");
    final start = fmt.format(event.startDate.toUtc());
    final end = fmt.format(event.startDate
        .add(const Duration(hours: 1))
        .toUtc());
    final title = Uri.encodeComponent(event.title);
    final details = Uri.encodeComponent(event.description);
    final location = Uri.encodeComponent(event.location ?? '');

    final url = Uri.parse(
        'https://www.google.com/calendar/render'
        '?action=TEMPLATE'
        '&text=$title'
        '&dates=$start/$end'
        '&details=$details'
        '&location=$location');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Calendar')),
      );
    }
  }

  /// Opens iCal deep-link (works on iOS/macOS; on web prompts .ics download)
  Future<void> _addToIcal(BuildContext context) async {
    final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final start = fmt.format(event.startDate.toUtc());
    final end = fmt.format(
        event.startDate.add(const Duration(hours: 1)).toUtc());
    final uid =
        '${event.id}@achc-hub.app';
    final title = event.title.replaceAll(',', '\\,');
    final desc = event.description.replaceAll(',', '\\,');
    final loc = (event.location ?? '').replaceAll(',', '\\,');

    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ACHC Hub//EN',
      'BEGIN:VEVENT',
      'UID:$uid',
      'DTSTART:$start',
      'DTEND:$end',
      'SUMMARY:$title',
      'DESCRIPTION:$desc',
      'LOCATION:$loc',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    // Encode as data URI
    final encoded = Uri.encodeComponent(ics);
    final url = Uri.parse('data:text/calendar;charset=utf8,$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback: open Apple Calendar web
      final apple = Uri.parse('webcal://p${event.startDate.year}-'
          'calendarws.icloud.com/ca');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'iCal: Copy this event on ${DateFormat('MMM d').format(event.startDate)}')),
        );
      }
    }
  }
}

// ── Add Event Sheet ───────────────────────────────────────────────
class _AddEventSheet extends StatefulWidget {
  final FirebaseFirestore db;
  final dynamic user;
  const _AddEventSheet({required this.db, required this.user});

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Add Event',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Event Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locCtrl,
                decoration: const InputDecoration(
                    labelText: 'Location', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Start: ${DateFormat('MMM d, y – h:mm a').format(_start)}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18, color: AppTheme.navy),
                onTap: () async {
                  final p = await showDateTimePicker(context);
                  if (p != null) setState(() => _start = p);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.calendarColor,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Add Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> showDateTimePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.db.collection('events').add({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'location': _locCtrl.text.trim(),
        'startDate': Timestamp.fromDate(_start),
        'endDate': Timestamp.fromDate(_start.add(const Duration(hours: 1))),
        'createdBy': widget.user?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isRecurring': false,
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
