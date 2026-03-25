import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/memory/memory_models.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../providers/memory_provider.dart';
import '../../providers/class_mode_provider.dart';
import '../../services/cloze_override_service.dart';
import '../../services/verification_service.dart';
import '../../widgets/speech_recording_widget.dart';
import 'cloze_text_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContentCardScreen
// ─────────────────────────────────────────────────────────────────────────────

class ContentCardScreen extends StatefulWidget {
  final String subjectId;
  final int unitNumber;
  final UserModel user;
  final List<MemoryItemModel>? preloadedItems; // optional for drill/battle
  final String? viewingChildId; // parent viewing a specific child's content

  const ContentCardScreen({
    super.key,
    required this.subjectId,
    required this.unitNumber,
    required this.user,
    this.viewingChildId,
  }) : preloadedItems = null;

  const ContentCardScreen.withItems({
    super.key,
    required this.subjectId,
    required this.unitNumber,
    required this.user,
    required List<MemoryItemModel> items,
    this.viewingChildId,
  }) : preloadedItems = items;

  @override
  State<ContentCardScreen> createState() => _ContentCardScreenState();
}

class _ContentCardScreenState extends State<ContentCardScreen> {
  late int _currentUnit;
  String get _subjectId => widget.subjectId;

  MemoryItemModel? _item;
  bool _loadingItem = true;
  String? _itemError;

  int _clozeLevel = 0;
  bool _allRevealed = false;
  bool _ratingSubmitted = false;
  int? _priorRating;

  // P3-1: Recite check
  bool _reciteEnabled = false;   // feature flag loaded from SharedPrefs
  bool _showReciteWidget = false;

  // Audio
  final AudioPlayer _sungPlayer = AudioPlayer();
  final AudioPlayer _spokenPlayer = AudioPlayer();
  bool _sungPlaying = false;
  bool _spokenPlaying = false;
  Duration? _sungDuration;
  Duration? _spokenDuration;
  Duration _sungPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentUnit = widget.unitNumber;
    _loadClozeLevel();
    _loadItem();
    _setupAudioListeners();
    _loadReciteFlag();
  }

  Future<void> _loadReciteFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('recite_check_enabled') ?? false;
    if (mounted) setState(() => _reciteEnabled = enabled);
  }

  Future<void> _handleReciteResult(VerificationResult result) async {
    if (result.wpBonus > 0) {
      await context.read<MemoryProvider>().awardWP(result.wpBonus);
    }
    if (!mounted) return;
    // Log the attempt in progress (mastery bump only if pass/partial)
    if (_item != null &&
        (result.outcome == ReciteOutcome.pass ||
            result.outcome == ReciteOutcome.partial)) {
      await context.read<MemoryProvider>().updateProgress(
        memoryItemId: _item!.id,
        masteryLevel: result.outcome == ReciteOutcome.pass ? 3 : 2,
        wpEarned: result.wpBonus,
        sungPlayedFirst: false,
      );
    }
    // Keep the widget visible so the student sees the result; they dismiss it
  }

  @override
  void dispose() {
    _sungPlayer.dispose();
    _spokenPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadClozeLevel() async {
    // P2-5: Check Firestore class override first (class mode or admin override)
    final classProv = context.read<ClassModeProvider>();
    final classId = classProv.currentClassId;

    if (classId != null) {
      try {
        final overrideLevel = await ClozeOverrideService().getOverrideLevel(
          classId: classId,
          subjectId: widget.subjectId,
          unitNumber: _currentUnit,
        );
        if (overrideLevel != null && mounted) {
          setState(() => _clozeLevel = overrideLevel);
          return; // override wins — don't load personal pref
        }
      } catch (_) {
        // Non-fatal; fall through to personal pref
      }
    }

    // Fall back to per-student SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('cloze_level_${widget.subjectId}') ?? 0;
    if (mounted) setState(() => _clozeLevel = saved);
  }

  Future<void> _saveClozeLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cloze_level_${widget.subjectId}', level);
  }

  void _setupAudioListeners() {
    _sungPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _sungPlaying = state.playing);
      }
    });
    _sungPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _sungDuration = d);
    });
    _sungPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _sungPosition = p);
    });
    _spokenPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _spokenPlaying = state.playing);
    });
    _spokenPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _spokenDuration = d);
    });
  }

  Future<void> _loadItem() async {
    setState(() {
      _loadingItem = true;
      _itemError = null;
      _allRevealed = false;
      _ratingSubmitted = false;
      _priorRating = null;
    });

    try {
      final provider = context.read<MemoryProvider>();
      final items = await provider.loadMemoryItems(
        subjectId: _subjectId,
        unitNumber: _currentUnit,
      );

      MemoryItemModel? found;
      if (items.isNotEmpty) found = items.first;

      // Check prior rating
      int? prior;
      if (found != null) {
        final progress = provider.progressFor(found.id);
        if (progress != null && progress.masteryLevel > 0) {
          prior = progress.masteryLevel;
        }
      }

      if (mounted) {
        setState(() {
          _item = found;
          _priorRating = prior;
          _loadingItem = false;
        });
      }

      // Stop any playing audio
      await _sungPlayer.stop();
      await _spokenPlayer.stop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _itemError = 'Failed to load content: $e';
          _loadingItem = false;
        });
      }
    }
  }

  Future<void> _toggleSungAudio() async {
    if (_item?.sungAudioUrl == null) return;
    if (kIsWeb) {
      // Web: use url_launcher or just disable audio
      _showAudioWebNote();
      return;
    }
    if (_sungPlaying) {
      await _sungPlayer.pause();
    } else {
      await _spokenPlayer.stop();
      try {
        if (_sungPlayer.audioSource == null) {
          await _sungPlayer.setUrl(_item!.sungAudioUrl!);
        }
        await _sungPlayer.play();
        // Record first play for WP
        final provider = context.read<MemoryProvider>();
        final wpGained = await provider.recordSungPlayed(_item!.id);
        if (wpGained > 0) {
          await provider.awardWP(wpGained);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio error: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleSpokenAudio() async {
    if (_item?.spokenAudioUrl == null) return;
    if (kIsWeb) {
      _showAudioWebNote();
      return;
    }
    if (_spokenPlaying) {
      await _spokenPlayer.pause();
    } else {
      await _sungPlayer.stop();
      try {
        if (_spokenPlayer.audioSource == null) {
          await _spokenPlayer.setUrl(_item!.spokenAudioUrl!);
        }
        await _spokenPlayer.play();
        // +1 WP for spoken
        await context.read<MemoryProvider>().awardWP(1);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio error: $e')),
          );
        }
      }
    }
  }

  void _showAudioWebNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio playback is available on the mobile app.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitRating(int level) async {
    if (_item == null) return;

    final wpMap = {1: 3, 2: 8, 3: 15};
    int wp = wpMap[level] ?? 0;

    // Improvement bonus
    if (_priorRating != null && level > _priorRating!) wp += 10;

    final provider = context.read<MemoryProvider>();
    await provider.updateProgress(
      memoryItemId: _item!.id,
      masteryLevel: level,
      wpEarned: wp,
      sungPlayedFirst: false,
    );

    final leveledUp = await provider.awardWP(wp);

    setState(() {
      _ratingSubmitted = true;
      _priorRating = level;
    });

    if (!mounted) return;

    if (leveledUp != null) {
      _showLevelUpDialog(leveledUp);
    } else {
      final labels = {1: 'Just Heard It', 2: 'Getting There', 3: 'Got It!'};
      final icons = {1: '🌱', 2: '🔥', 3: '⭐'};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${icons[level]} ${labels[level]} · +$wp WP'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppTheme.navy,
        ),
      );
    }
  }

  void _showLevelUpDialog(LumenStateModel state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('⭐', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Level Up!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lumen is now a ${state.levelName}!',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Level ${state.lumenLevel}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Onward!'),
          ),
        ],
      ),
    );
  }

  void _navigateUnit(int delta) {
    final provider = context.read<MemoryProvider>();
    final units = provider.units.where((u) => u.cycleId == provider.activeCycleId).toList();
    final newUnit = (_currentUnit + delta).clamp(1, units.length);
    if (newUnit == _currentUnit) return;
    setState(() => _currentUnit = newUnit);
    _loadItem();
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── Subject display helpers ───────────────────────────────────────────────
  SubjectModel? _getSubject() {
    final provider = context.read<MemoryProvider>();
    return provider.subjects.where((s) => s.id == _subjectId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final subject = _getSubject();
    final subjectName = subject?.name ?? _subjectId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text(
          '$subjectName · Unit $_currentUnit',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () => _navigateUnit(-1),
            tooltip: 'Previous unit',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () => _navigateUnit(1),
            tooltip: 'Next unit',
          ),
          // PDF button for parent/mentor/admin
          if (!widget.user.isStudent && _item?.sungAudioUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () {
                // Will wire to PDFViewerScreen in a later phase
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF viewer coming soon')),
                );
              },
            ),
        ],
      ),
      body: _loadingItem
          ? const Center(child: CircularProgressIndicator())
          : _itemError != null
              ? _ErrorView(message: _itemError!)
              : _item == null
                  ? const _EmptyView()
                  : _CardBody(
                      item: _item!,
                      subject: subject,
                      currentUnit: _currentUnit,
                      clozeLevel: _clozeLevel,
                      allRevealed: _allRevealed,
                      ratingSubmitted: _ratingSubmitted,
                      priorRating: _priorRating,
                      sungPlaying: _sungPlaying,
                      spokenPlaying: _spokenPlaying,
                      sungDuration: _sungDuration,
                      spokenDuration: _spokenDuration,
                      sungPosition: _sungPosition,
                      onClozeLevelChanged: (l) {
                        setState(() => _clozeLevel = l);
                        _saveClozeLevel(l);
                      },
                      onAllRevealed: () => setState(() => _allRevealed = true),
                      onSungTap: _toggleSungAudio,
                      onSpokenTap: _toggleSpokenAudio,
                      onRate: _submitRating,
                      reciteEnabled: _reciteEnabled,
                      showReciteWidget: _showReciteWidget,
                      onReciteTap: () =>
                          setState(() => _showReciteWidget = true),
                      onReciteDismiss: () =>
                          setState(() => _showReciteWidget = false),
                      onReciteResult: _handleReciteResult,
                    ),
    );
  }
}

// ─── Card Body ─────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final MemoryItemModel item;
  final SubjectModel? subject;
  final int currentUnit;
  final int clozeLevel;
  final bool allRevealed;
  final bool ratingSubmitted;
  final int? priorRating;
  final bool sungPlaying;
  final bool spokenPlaying;
  final Duration? sungDuration;
  final Duration? spokenDuration;
  final Duration sungPosition;
  final ValueChanged<int> onClozeLevelChanged;
  final VoidCallback onAllRevealed;
  final VoidCallback onSungTap;
  final VoidCallback onSpokenTap;
  final ValueChanged<int> onRate;
  // P3-1
  final bool reciteEnabled;
  final bool showReciteWidget;
  final VoidCallback onReciteTap;
  final VoidCallback onReciteDismiss;
  final ValueChanged<VerificationResult> onReciteResult;

  const _CardBody({
    required this.item,
    required this.subject,
    required this.currentUnit,
    required this.clozeLevel,
    required this.allRevealed,
    required this.ratingSubmitted,
    required this.priorRating,
    required this.sungPlaying,
    required this.spokenPlaying,
    required this.sungDuration,
    required this.spokenDuration,
    required this.sungPosition,
    required this.onClozeLevelChanged,
    required this.onAllRevealed,
    required this.onSungTap,
    required this.onSpokenTap,
    required this.onRate,
    required this.reciteEnabled,
    required this.showReciteWidget,
    required this.onReciteTap,
    required this.onReciteDismiss,
    required this.onReciteResult,
  });

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return ' $m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MemoryProvider>();
    final cycleLabel = provider.activeCycle?.name ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cycle label
          Text(
            cycleLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Level selector
          Center(
            child: ClozeLevelSelector(
              selectedLevel: clozeLevel,
              onChanged: onClozeLevelChanged,
            ),
          ),
          const SizedBox(height: 16),

          // Content card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type A: show question
                  if (item.contentType == 'A' && item.questionText != null) ...[
                    Text(
                      item.questionText!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Divider(height: 20),
                  ],
                  // Type B soft prompt
                  if (item.contentType == 'B' && subject?.softPrompt.isNotEmpty == true) ...[
                    Text(
                      subject!.softPrompt,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Cloze text
                  if (clozeLevel == 4 && item.contentType == 'A')
                    // Solo level for Q&A: show question only
                    Text(
                      item.questionText ?? '',
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    )
                  else if (clozeLevel == 4 && item.contentType == 'B')
                    // Solo level for statement: show soft prompt only
                    Text(
                      subject?.softPrompt ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ClozeTextWidget(
                      text: item.contentText,
                      clozeLevel: clozeLevel,
                      itemId: item.id,
                      onAllRevealed: onAllRevealed,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // PRIMARY: Sung audio button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: item.sungAudioUrl != null ? onSungTap : null,
              icon: Icon(
                sungPlaying ? Icons.pause : Icons.music_note,
                color: AppTheme.navy,
              ),
              label: Text(
                item.sungAudioUrl != null
                    ? '${sungPlaying ? 'Pause' : 'Play'} Sung Version${_formatDuration(sungDuration)}'
                    : 'Audio coming soon',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: item.sungAudioUrl != null
                    ? AppTheme.gold
                    : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Sung audio progress bar
          if (sungPlaying && sungDuration != null) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: sungDuration!.inMilliseconds > 0
                  ? sungPosition.inMilliseconds / sungDuration!.inMilliseconds
                  : 0,
              color: AppTheme.gold,
              backgroundColor: Colors.grey[200],
              minHeight: 3,
            ),
          ],

          const SizedBox(height: 10),

          // SECONDARY: Spoken audio
          OutlinedButton.icon(
            onPressed: item.spokenAudioUrl != null ? onSpokenTap : null,
            icon: Icon(
              spokenPlaying ? Icons.pause : Icons.record_voice_over_outlined,
              size: 18,
              color: item.spokenAudioUrl != null ? AppTheme.navy : Colors.grey,
            ),
            label: Text(
              item.spokenAudioUrl != null
                  ? 'Spoken${_formatDuration(spokenDuration)}'
                  : 'Audio coming soon',
              style: TextStyle(
                color: item.spokenAudioUrl != null ? AppTheme.navy : Colors.grey,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: item.spokenAudioUrl != null ? AppTheme.navy : Colors.grey[300]!,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          const SizedBox(height: 12),

          // P3-1: Recite Check button (only when feature flag on)
          if (reciteEnabled) ...[
            if (!showReciteWidget)
              OutlinedButton.icon(
                onPressed: onReciteTap,
                icon: const Icon(Icons.record_voice_over_outlined, size: 18),
                label: const Text('Recite Check'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.navy,
                  side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            else
              SpeechRecordingWidget(
                targetText: item.contentText,
                onResult: onReciteResult,
                onDismiss: onReciteDismiss,
              ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 12),

          // Rating section — shown when all blanks revealed or level 0
          if (allRevealed || clozeLevel == 0) ...[
            const Text(
              'HOW DID YOU DO?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RatingButton(
                    label: 'Just Heard It',
                    icon: '🌱',
                    wp: 3,
                    level: 1,
                    isSelected: priorRating == 1,
                    onTap: () => onRate(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    label: 'Getting There',
                    icon: '🔥',
                    wp: 8,
                    level: 2,
                    isSelected: priorRating == 2,
                    onTap: () => onRate(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatingButton(
                    label: "Got It!",
                    icon: '⭐',
                    wp: 15,
                    level: 3,
                    isSelected: priorRating == 3,
                    onTap: () => onRate(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            // Nudge to reveal
            Text(
              'Tap blanks to reveal, then rate yourself',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],

          // Prior rating footer
          if (priorRating != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Last rated: ${_ratingLabelFor(priorRating!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _ratingLabelFor(int level) {
    switch (level) {
      case 1:
        return 'Just Heard It';
      case 2:
        return 'Getting There';
      case 3:
        return 'Got It!';
      default:
        return '';
    }
  }
}

// ─── Rating Button ─────────────────────────────────────────────────────────────

class _RatingButton extends StatelessWidget {
  final String label;
  final String icon;
  final int wp;
  final int level;
  final bool isSelected;
  final VoidCallback onTap;

  const _RatingButton({
    required this.label,
    required this.icon,
    required this.wp,
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navy.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.navy : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.navy : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '+$wp WP',
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppTheme.gold : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error / Empty views ──────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No content for this subject yet.\nCheck back after content is imported.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
