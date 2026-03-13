// lib/screens/moodle/moodle_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/moodle_service.dart';
import '../../utils/app_theme.dart';

class MoodleSetupScreen extends StatefulWidget {
  const MoodleSetupScreen({super.key});

  @override
  State<MoodleSetupScreen> createState() => _MoodleSetupScreenState();
}

class _MoodleSetupScreenState extends State<MoodleSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _moodleService = MoodleService();
  bool _isValidating = false;
  String? _validationResult;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user?.moodleUrl != null) _urlCtrl.text = user!.moodleUrl!;
    if (user?.moodleToken != null) _tokenCtrl.text = user!.moodleToken!;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isValidating = true;
      _validationResult = null;
      _isValid = false;
    });

    final info = await _moodleService.validateCredentials(
      _urlCtrl.text.trim(),
      _tokenCtrl.text.trim(),
    );

    setState(() {
      _isValidating = false;
      if (info != null && info['sitename'] != null) {
        _isValid = true;
        _validationResult =
            '✅ Connected to: ${info['sitename']} (User: ${info['fullname'] ?? 'Unknown'})';
      } else {
        _validationResult =
            '❌ Could not connect. Check your URL and token.';
      }
    });
  }

  Future<void> _save() async {
    if (!_isValid) {
      await _validate();
      if (!_isValid) return;
    }

    final auth = context.read<AuthProvider>();
    await auth.saveMoodleCredentials(
        _urlCtrl.text.trim(), _tokenCtrl.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Moodle settings saved!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Moodle Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.info.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppTheme.info, size: 18),
                          SizedBox(width: 8),
                          Text('How to get your Moodle token:',
                              style: TextStyle(
                                  color: AppTheme.info,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Log in to your Moodle site\n'
                        '2. Go to Profile → Preferences → Security keys\n'
                        '3. Copy the "Mobile service" key\n'
                        '4. Paste it below as your token',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Icon(Icons.cloud_sync,
                    size: 56, color: AppTheme.assignmentsColor),
                const SizedBox(height: 16),
                const Text(
                  'Connect to Moodle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sync assignments directly from your Moodle LMS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Moodle Site URL',
                    prefixIcon: Icon(Icons.language),
                    hintText: 'https://your-school.moodlecloud.com',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter Moodle URL';
                    if (!v.startsWith('http')) {
                      return 'URL must start with http:// or https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Moodle API Token',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    hintText: 'Your mobile service token',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your token' : null,
                ),
                if (_validationResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isValid
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isValid
                            ? AppTheme.success.withValues(alpha: 0.3)
                            : AppTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _validationResult!,
                      style: TextStyle(
                        color: _isValid ? AppTheme.success : AppTheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _isValidating ? null : _validate,
                  icon: _isValidating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : const Icon(Icons.network_check),
                  label: const Text('Test Connection'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isValidating ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Moodle Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.assignmentsColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
