// lib/screens/checkin/checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/checkin_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import 'package:uuid/uuid.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _firestoreService = FirestoreService();
  final _uuid = const Uuid();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final familyId = user.familyId ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Check-In'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector banner
          Container(
            color: AppTheme.checkInColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white),
                  onPressed: () => setState(() => _selectedDate =
                      _selectedDate.subtract(const Duration(days: 1))),
                ),
                Text(
                  isSameDay(_selectedDate, DateTime.now())
                      ? 'Today – ${DateFormat('MMM d').format(_selectedDate)}'
                      : DateFormat('EEEE, MMM d').format(_selectedDate),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: Colors.white),
                  onPressed: _selectedDate.isBefore(DateTime.now())
                      ? () => setState(() => _selectedDate =
                          _selectedDate.add(const Duration(days: 1)))
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CheckInModel>>(
              stream: _firestoreService.streamCheckIns(
                  familyId, _selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final checkIns = snapshot.data ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick check-in for self
                      _buildSelfCheckIn(
                          context, user, familyId, checkIns),
                      const SizedBox(height: 20),

                      // Family members (if parent/admin)
                      if (user.isParent || user.isAdmin) ...[
                        const Text(
                          'Family Members',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...context
                            .read<AuthProvider>()
                            .kids
                            .map((kid) => _buildMemberCheckInCard(
                                context,
                                kid.uid,
                                kid.displayName,
                                familyId,
                                checkIns)),
                      ],

                      // All check-ins list
                      if (checkIns.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Check-In Log',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...checkIns.map(
                            (c) => _buildCheckInRecord(c)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfCheckIn(BuildContext context, user, String familyId,
      List<CheckInModel> checkIns) {
    final myCheckIn = checkIns
        .where((c) => c.userId == user.uid)
        .toList();
    final isCheckedIn = myCheckIn.isNotEmpty &&
        myCheckIn.first.status == CheckInStatus.checkedIn;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (isCheckedIn
                        ? AppTheme.success
                        : AppTheme.checkInColor)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCheckedIn ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isCheckedIn
                    ? AppTheme.success
                    : AppTheme.checkInColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Me (${user.displayName})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Text(
                    isCheckedIn
                        ? 'Checked in at ${DateFormat('h:mm a').format(myCheckIn.first.checkInTime ?? DateTime.now())}'
                        : 'Not checked in today',
                    style: TextStyle(
                      color: isCheckedIn
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (isCheckedIn) {
                  await _firestoreService.checkOut(myCheckIn.first.id);
                } else {
                  await _firestoreService.checkIn(CheckInModel(
                    id: _uuid.v4(),
                    userId: user.uid,
                    userName: user.displayName,
                    familyId: familyId,
                    date: _selectedDate,
                    status: CheckInStatus.checkedIn,
                    checkInTime: DateTime.now(),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isCheckedIn
                    ? AppTheme.error
                    : AppTheme.checkInColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
              ),
              child: Text(isCheckedIn ? 'Check Out' : 'Check In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCheckInCard(BuildContext context, String memberId,
      String memberName, String familyId, List<CheckInModel> allCheckIns) {
    final memberCheckIns =
        allCheckIns.where((c) => c.userId == memberId).toList();
    final isCheckedIn = memberCheckIns.isNotEmpty &&
        memberCheckIns.first.status == CheckInStatus.checkedIn;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isCheckedIn ? AppTheme.success : AppTheme.textHint)
              .withValues(alpha: 0.15),
          child: Text(
            memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
            style: TextStyle(
              color:
                  isCheckedIn ? AppTheme.success : AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(memberName),
        subtitle: Text(
          isCheckedIn ? 'Checked In ✓' : 'Not checked in',
          style: TextStyle(
            color: isCheckedIn ? AppTheme.success : AppTheme.textHint,
            fontSize: 12,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () async {
            if (isCheckedIn) {
              await _firestoreService.checkOut(memberCheckIns.first.id);
            } else {
              await _firestoreService.checkIn(CheckInModel(
                id: _uuid.v4(),
                userId: memberId,
                userName: memberName,
                familyId: familyId,
                date: _selectedDate,
                status: CheckInStatus.checkedIn,
                checkInTime: DateTime.now(),
              ));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isCheckedIn ? AppTheme.error : AppTheme.checkInColor,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: Text(isCheckedIn ? 'Out' : 'In'),
        ),
      ),
    );
  }

  Widget _buildCheckInRecord(CheckInModel record) {
    final statusColor = record.status == CheckInStatus.checkedIn
        ? AppTheme.success
        : record.status == CheckInStatus.checkedOut
            ? AppTheme.info
            : AppTheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(
          record.status == CheckInStatus.checkedIn
              ? Icons.login
              : Icons.logout,
          color: statusColor,
        ),
        title: Text(record.userName),
        subtitle: record.checkInTime != null
            ? Text(DateFormat('h:mm a').format(record.checkInTime!),
                style: const TextStyle(fontSize: 12))
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            record.status.name.replaceAll('checked', '').toUpperCase(),
            style:
                TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
