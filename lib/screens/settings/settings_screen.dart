// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/notification_prefs_service.dart';
import '../moodle/moodle_setup_screen.dart';
import 'claim_student_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, bool> _notifPrefs = {};

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await NotificationPrefsService.loadPrefs();
    if (mounted) setState(() => _notifPrefs = prefs);
  }

  Future<void> _setNotifPref(String key, bool value) async {
    await NotificationPrefsService.setPref(key, value);
    await _loadNotifPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.navyDark, AppTheme.navy],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.25),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2),
                    ),
                    child: Center(
                      child: Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.name.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Students section for parents
            if (user.isParent) ...[
              _buildSection(
                context,
                'Family Members',
                Icons.family_restroom,
                AppTheme.navy,
                [
                  ...auth.students.map((kid) => _StudentTile(kid: kid)),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.navy.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add,
                          color: AppTheme.navy, size: 22),
                    ),
                    title: const Text('Add Student Account'),
                    trailing: const Icon(Icons.add,
                        color: AppTheme.navy, size: 20),
                    onTap: () => _showAddKidDialog(context),
                  ),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.classesColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.link,
                          color: AppTheme.classesColor, size: 22),
                    ),
                    title: const Text('Claim Imported Student'),
                    subtitle: const Text(
                        'Link an existing student account to your family',
                        style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppTheme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ClaimStudentScreen(parentUser: user)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Moodle settings for parents
            if (user.isParent || user.isAdmin) ...[
              _buildSection(
                context,
                'Moodle Integration',
                Icons.cloud_sync,
                AppTheme.assignmentsColor,
                [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.assignmentsColor
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        user.moodleUrl != null
                            ? Icons.check_circle
                            : Icons.settings,
                        color: user.moodleUrl != null
                            ? AppTheme.success
                            : AppTheme.assignmentsColor,
                        size: 22,
                      ),
                    ),
                    title: const Text('Moodle Setup'),
                    subtitle: Text(
                      user.moodleUrl != null
                          ? user.moodleUrl!
                          : 'Not configured',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MoodleSetupScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Account section
            _buildSection(
              context,
              'Account',
              Icons.account_circle_outlined,
              AppTheme.textSecondary,
              [
                // ── Notification Badge Settings ──
                if (!user.isStudent) ...[
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined,
                        color: AppTheme.navy),
                    title: const Text('Notification Badges'),
                    subtitle: const Text('Choose which sections show a badge'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _showNotifSettings(context),
                  ),
                  const Divider(height: 1, indent: 72),
                ],
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About ACHC Hub'),
                  subtitle: const Text('Version 1.0.0'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'ACHC Hub',
                    applicationVersion: '1.0.0',
                    applicationLegalese:
                        '© 2024 ACHC Homeschool Co-op',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.error),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: AppTheme.error),
                  ),
                  onTap: () => _confirmSignOut(context, auth),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon,
      Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showNotifSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifSettingsSheet(
        prefs: Map.from(_notifPrefs),
        onChanged: _setNotifPref,
      ),
    );
  }

  void _showAddKidDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    bool adding = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Student Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create a login for your child. They use your email + their name + password to sign in.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: "Student's Name *"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password (optional)',
                    hintText: 'Leave blank to auto-generate',
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '💡 If you leave the password blank, a password will be auto-generated. You can change it later.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: adding ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: adding ? null : () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter the student\'s name'),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                setDialogState(() => adding = true);
                final auth = context.read<AuthProvider>();
                final success = await auth.addKid(
                    nameCtrl.text.trim(), passwordCtrl.text.trim());
                setDialogState(() => adding = false);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? '${nameCtrl.text.trim()} added successfully!'
                          : auth.errorMessage ?? 'Failed to add student'),
                      backgroundColor:
                          success ? AppTheme.success : AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: adding
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add Student'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.signOut();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ── Student Tile with classes listed below name ───────────────────
class _StudentTile extends StatefulWidget {
  final UserModel kid;
  const _StudentTile({required this.kid});

  @override
  State<_StudentTile> createState() => _StudentTileState();
}

class _StudentTileState extends State<_StudentTile> {
  List<String> _classNames = [];
  bool _loaded = false;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      // Use the 'classes' collection (correct path) instead of 'groups'
      final snap = await _db
          .collection('classes')
          .where('enrolledUids', arrayContains: widget.kid.uid)
          .get();
      final names = snap.docs
          .map((d) => d.data()['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList()
        ..sort();
      if (mounted) {
        setState(() {
          _classNames = names;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _editName(BuildContext context) async {
    final ctrl = TextEditingController(text: widget.kid.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Student Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navy, foregroundColor: Colors.white),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == widget.kid.displayName) return;
    try {
      await _db.collection('users').doc(widget.kid.uid).update({'displayName': newName});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to $newName'), backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _removeStudent(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
            'Remove "${widget.kid.displayName}" from your family? '
            'Their account will remain but be unlinked from your profile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    final parentUid = context.read<AuthProvider>().currentUser?.uid;
    if (parentUid == null) return;
    try {
      final batch = _db.batch();
      // Remove kid from parent's kidUids
      batch.update(_db.collection('users').doc(parentUid), {
        'kidUids': FieldValue.arrayRemove([widget.kid.uid]),
      });
      // Clear parentUid on the student
      batch.update(_db.collection('users').doc(widget.kid.uid), {
        'parentUid': FieldValue.delete(),
        'needsClaim': true,
      });
      await batch.commit();
      if (mounted) {
        context.read<AuthProvider>().refreshStudents();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${widget.kid.displayName} removed from family'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine label: imported students may have role 'student' even when
    // their Firestore doc says parent — always show 'Student' for kids listed here.
    const roleLabel = 'Student';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.gold.withValues(alpha: 0.15),
              child: Text(
                widget.kid.displayName.isNotEmpty
                    ? widget.kid.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppTheme.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          // Name + role label + classes
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.kid.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(roleLabel,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Classes row — wraps to multiple lines if needed
                  if (!_loaded)
                    const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5))
                  else if (_classNames.isEmpty)
                    const Text('No classes assigned',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textHint))
                  else
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: _classNames.map((cn) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.35)),
                        ),
                        child: Text(cn,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ),
          // Edit / remove popup
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textHint),
              onSelected: (v) {
                if (v == 'edit') _editName(context);
                if (v == 'remove') _removeStudent(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined, size: 18),
                        title: Text('Rename'))),
                const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.link_off, size: 18, color: Colors.red),
                        title: Text('Unlink from family',
                            style: TextStyle(color: Colors.red)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification Settings Sheet ────────────────────────────────────
class _NotifSettingsSheet extends StatefulWidget {
  final Map<String, bool> prefs;
  final Future<void> Function(String key, bool value) onChanged;
  const _NotifSettingsSheet({required this.prefs, required this.onChanged});

  @override
  State<_NotifSettingsSheet> createState() => _NotifSettingsSheetState();
}

class _NotifSettingsSheetState extends State<_NotifSettingsSheet> {
  late Map<String, bool> _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = Map.from(widget.prefs);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NotifItem('Assignments', Icons.assignment_outlined,
          AppTheme.assignmentsColor, NotificationPrefsService.keyAssignments),
      _NotifItem('Messages', Icons.chat_bubble_outline,
          AppTheme.messagesColor, NotificationPrefsService.keyMessages),
      _NotifItem('Calendar Events', Icons.calendar_today_outlined,
          AppTheme.calendarColor, NotificationPrefsService.keyCalendar),
      _NotifItem('Files', Icons.folder_outlined,
          AppTheme.filesColor, NotificationPrefsService.keyFiles),
      _NotifItem('Announcements (always on)', Icons.campaign_outlined,
          AppTheme.feedsColor, NotificationPrefsService.keyFeedAnnouncements,
          locked: true),
      _NotifItem('Social Feed', Icons.people_outline,
          AppTheme.photosColor, NotificationPrefsService.keyFeedSocial),
      _NotifItem('Prayer Feed', Icons.volunteer_activism_outlined,
          AppTheme.prayerColor, NotificationPrefsService.keyFeedPrayer),
      _NotifItem('Photos', Icons.photo_library_outlined,
          AppTheme.photosColor, NotificationPrefsService.keyPhotos),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      size: 22, color: AppTheme.navy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Notification Badge Settings',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia')),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose which sections show a badge counter on the home screen. '
                'Long-press any home tile to clear its badge.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isOn = _prefs[item.key] ?? false;
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withValues(alpha: 0.1),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    title: Text(item.label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: Switch(
                      value: isOn,
                      onChanged: item.locked
                          ? null
                          : (v) async {
                              setState(() => _prefs[item.key] = v);
                              await widget.onChanged(item.key, v);
                            },
                      activeTrackColor: item.color,
                      activeThumbColor: item.color,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem {
  final String label;
  final IconData icon;
  final Color color;
  final String key;
  final bool locked;
  const _NotifItem(this.label, this.icon, this.color, this.key,
      {this.locked = false});
}
