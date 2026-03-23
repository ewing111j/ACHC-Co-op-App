import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/memory/memory_models.dart';
import '../../models/user_model.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// YoungLearnerHomeScreen
//
// Simplified home for students with is_young_learner = true.
// Large subject icons, no cloze, no battle/drill, simple "We practiced this!"
// ─────────────────────────────────────────────────────────────────────────────

class YoungLearnerHomeScreen extends StatelessWidget {
  final UserModel user;
  const YoungLearnerHomeScreen({super.key, required this.user});

  static const Map<String, String> _icons = {
    'religion': '✝️',
    'scripture': '📖',
    'latin': '🏛️',
    'grammar': '✏️',
    'history': '🏰',
    'science': '🔬',
    'math': '➕',
    'geography': '🌍',
    'great_words_1': '💬',
    'great_words_2': '📝',
    'timeline': '⏳',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1), // warm cream for young learners
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: const Text('Memory Work',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<MemoryProvider>(builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final subjects = provider.subjects;
        final unit = provider.currentUnit;
        final cycle = provider.activeCycle?.name ?? 'Cycle 2';

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Friendly heading
              Text(
                '$cycle · Week $unit',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'What do you want to learn today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2A4A)),
              ),
              const SizedBox(height: 24),

              // Large subject grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: subjects.length,
                itemBuilder: (context, i) {
                  final s = subjects[i];
                  return _YoungSubjectTile(
                    subject: s,
                    icon: _icons[s.id] ?? '📚',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => YoungLearnerContentCard(
                          subjectId: s.id,
                          unitNumber: unit,
                          user: user,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Large subject tile ───────────────────────────────────────────────────────

class _YoungSubjectTile extends StatelessWidget {
  final SubjectModel subject;
  final String icon;
  final VoidCallback onTap;

  const _YoungSubjectTile({
    required this.subject,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(
                subject.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2A4A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YoungLearnerContentCard
//
// Simplified content card: large PLAY button, optional text (long-press),
// "We practiced this!" button that records mastery level 1 + +3 WP.
// No cloze, no self-rating, no drill.
// ─────────────────────────────────────────────────────────────────────────────

class YoungLearnerContentCard extends StatefulWidget {
  final String subjectId;
  final int unitNumber;
  final UserModel user;

  const YoungLearnerContentCard({
    super.key,
    required this.subjectId,
    required this.unitNumber,
    required this.user,
  });

  @override
  State<YoungLearnerContentCard> createState() =>
      _YoungLearnerContentCardState();
}

class _YoungLearnerContentCardState extends State<YoungLearnerContentCard> {
  MemoryItemModel? _item;
  bool _loading = true;
  bool _showText = false;
  bool _practiced = false;
  bool _playing = false;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItem());
  }

  Future<void> _loadItem() async {
    final provider = context.read<MemoryProvider>();
    try {
      final items = await provider.loadMemoryItems(
        subjectId: widget.subjectId,
        unitNumber: widget.unitNumber,
      );
      setState(() {
        _item = items.isNotEmpty ? items.first : null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _playSung() async {
    if (_item?.sungAudioUrl == null || kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Audio available in the mobile app!')),
      );
      return;
    }
    try {
      setState(() => _playing = true);
      await _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setUrl(_item!.sungAudioUrl!);
      await _audioPlayer!.play();
      _audioPlayer!.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playing = false);
        }
      });

      // Award WP for first sung play
      if (widget.user.isStudent) {
        final provider = context.read<MemoryProvider>();
        final wp = await provider.recordSungPlayed(_item!.id);
        if (wp > 0) await provider.awardWP(wp);
      }
    } catch (_) {
      setState(() => _playing = false);
    }
  }

  Future<void> _recordPracticed() async {
    if (_practiced) return;
    setState(() => _practiced = true);

    if (widget.user.isStudent && _item != null) {
      final provider = context.read<MemoryProvider>();
      await provider.updateProgress(
        memoryItemId: _item!.id,
        masteryLevel: 1, // neutral — "just heard/practiced"
        wpEarned: 3,
        sungPlayedFirst: false,
      );
      await provider.awardWP(3);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Great job! +3 Wisdom Points!'),
            backgroundColor: AppTheme.gold,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = widget.subjectId.replaceAll('_', ' ');

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text(subjectName[0].toUpperCase() +
            subjectName.substring(1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _item == null
              ? _NoContent(subjectName: subjectName)
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Spacer(),

                        // Content text (optional, revealed via long-press)
                        if (_showText) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.navy.withValues(alpha: 0.15)),
                            ),
                            child: Text(
                              _item!.contentText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showText = false),
                            child: const Text('Hide text'),
                          ),
                        ] else ...[
                          GestureDetector(
                            onLongPress: () =>
                                setState(() => _showText = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 20, horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppTheme.navy
                                        .withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.touch_app_outlined,
                                      color:
                                          Colors.grey[400], size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Hold to show text',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Big PLAY button
                        GestureDetector(
                          onTap: _playSung,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppTheme.navy,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.navy
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _playing
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Icon(Icons.play_arrow_rounded,
                                    size: 60, color: Colors.white),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text(
                          _playing ? 'Playing...' : 'Tap to play',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),

                        const Spacer(),

                        // "We practiced this!" button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _practiced ? null : _recordPracticed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _practiced
                                  ? Colors.grey[300]
                                  : AppTheme.gold,
                              foregroundColor: _practiced
                                  ? Colors.grey
                                  : AppTheme.navy,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: _practiced ? 0 : 4,
                            ),
                            child: Text(
                              _practiced
                                  ? '✓ Practiced!'
                                  : '⭐  We practiced this!',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _NoContent extends StatelessWidget {
  final String subjectName;
  const _NoContent({required this.subjectName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📚', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('No content yet for $subjectName',
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
