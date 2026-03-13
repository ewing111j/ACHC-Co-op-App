// lib/screens/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import 'package:uuid/uuid.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _firestoreService = FirestoreService();
  final _uuid = const Uuid();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  List<EventModel> _getEventsForDay(
      List<EventModel> events, DateTime day) {
    return events.where((e) => isSameDay(e.startDate, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final familyId = user.familyId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: (user.isParent || user.isAdmin)
          ? FloatingActionButton(
              onPressed: () =>
                  _showAddEventDialog(context, familyId, user.uid),
              backgroundColor: AppTheme.calendarColor,
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<List<EventModel>>(
        stream: _firestoreService.streamEvents(familyId),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          final selectedEvents = _selectedDay != null
              ? _getEventsForDay(events, _selectedDay!)
              : <EventModel>[];

          return Column(
            children: [
              Container(
                color: Colors.white,
                child: TableCalendar<EventModel>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      isSameDay(_selectedDay, day),
                  eventLoader: (day) => _getEventsForDay(events, day),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.calendarColor,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppTheme.calendarColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: selectedEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_outlined,
                                size: 48, color: AppTheme.textHint),
                            const SizedBox(height: 12),
                            const Text(
                              'No events on this day',
                              style: TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: selectedEvents.length,
                        itemBuilder: (ctx, i) =>
                            _buildEventCard(selectedEvents[i], user),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventCard(EventModel event, user) {
    final color = _hexToColor(event.color);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (event.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                  if (event.location?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          event.location!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('h:mm a').format(event.startDate),
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                if ((user.isParent || user.isAdmin))
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.error),
                    onPressed: () =>
                        _firestoreService.deleteEvent(event.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return AppTheme.calendarColor;
    }
  }

  void _showAddEventDialog(
      BuildContext context, String familyId, String userId) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime startDate = _selectedDay ?? DateTime.now();
    String selectedColor = '#43A047';

    final colors = {
      'Green': '#43A047',
      'Blue': '#1E88E5',
      'Orange': '#FF7043',
      'Purple': '#8E24AA',
      'Red': '#E53935',
      'Teal': '#00897B',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Event Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: locationCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat('MMM d, y – h:mm a').format(startDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                  leading: const Icon(Icons.schedule, size: 20),
                  onTap: () async {
                    final picked = await showDateTimePicker(
                      context: ctx,
                      initialDate: startDate,
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: colors.entries.map((e) {
                    final color = _hexToColor(e.value);
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedColor = e.value),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == e.value
                              ? Border.all(
                                  color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                final event = EventModel(
                  id: _uuid.v4(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  startDate: startDate,
                  location: locationCtrl.text.trim().isEmpty
                      ? null
                      : locationCtrl.text.trim(),
                  color: selectedColor,
                  createdBy: userId,
                  familyId: familyId,
                  createdAt: DateTime.now(),
                );
                await _firestoreService.createEvent(event);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.calendarColor),
              child: const Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> showDateTimePicker({
    required BuildContext context,
    required DateTime initialDate,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
