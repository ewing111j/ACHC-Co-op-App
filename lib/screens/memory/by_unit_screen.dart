import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/user_model.dart';
import '../../models/memory/memory_models.dart';
import '../../providers/memory_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/child_switcher_pill.dart';
import 'content_card_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ByUnitScreen — unit strip + subject grid + Play All + child switcher pill
// ─────────────────────────────────────────────────────────────────────────────

class ByUnitScreen extends StatefulWidget {
  final UserModel user;
  const ByUnitScreen({super.key, required this.user});

  @override
  State<ByUnitScreen> createState() => _ByUnitScreenState();
}

class _ByUnitScreenState extends State<ByUnitScreen> with ChildSwitcherMixin {
  int _selectedUnit = 1;

  // Play All state
  AudioPlayer? _audioPlayer;
  bool _playAllActive = false;
  int _playAllIndex = 0;
  List<String> _playAllQueue = []; // audio URLs
  List<String> _playAllSubjectLabels = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MemoryProvider>();
      _selectedUnit = provider.currentUnit;
      setState(() {});
    });
    if (widget.user.isParent && widget.user.kidUids.isNotEmpty) {
      _loadChildNames();
    }
  }

  Future<void> _loadChildNames() async {
    final db = FirebaseFirestore.instance;
    final names = <String, String>{};
    for (final uid in widget.user.kidUids) {
      final doc = await db.collection('users').doc(uid).get();
      names[uid] = (doc.data()?['displayName'] as String?) ?? uid;
    }
    await initChildSwitcher(widget.user.kidUids, names);
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  // ── Play All ───────────────────────────────────────────────────────────────

  Future<void> _startPlayAll() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Play All is not available on web preview. '
              'Use the mobile app for audio playback.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final provider = context.read<MemoryProvider>();
    final subjects = provider.subjects;

    // Fetch audio URLs for all 11 subjects at the selected unit
    final urls = <String>[];
    final labels = <String>[];

    for (final subject in subjects) {
      try {
        final items = await provider.loadMemoryItems(
          subjectId: subject.id,
          unitNumber: _selectedUnit,
        );
        for (final item in items) {
          if (item.sungAudioUrl != null && item.sungAudioUrl!.isNotEmpty) {
            urls.add(item.sungAudioUrl!);
            labels.add(subject.name);
            break; // one sung track per subject per unit
          }
        }
      } catch (_) {
        // Skip subjects with no items/audio
      }
    }

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No audio files found for this unit yet.')),
      );
      return;
    }

    setState(() {
      _playAllQueue = urls;
      _playAllSubjectLabels = labels;
      _playAllIndex = 0;
      _playAllActive = true;
    });

    await _playTrack(0);
  }

  Future<void> _playTrack(int index) async {
    if (index >= _playAllQueue.length) {
      _stopPlayAll();
      return;
    }
    await _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();

    try {
      await _audioPlayer!.setUrl(_playAllQueue[index]);
      _audioPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) _playTrack(index + 1);
        }
      });
      await _audioPlayer!.play();

      // Award WP for first sung play (student only)
      if (widget.user.isStudent) {
        final provider = context.read<MemoryProvider>();
        // We don't have the exact memory item ID here, so we award via
        // the generic sung-played path with a synthetic key
        await provider.awardWP(2);
      }
    } catch (_) {
      // Skip unplayable track
      _playTrack(index + 1);
    }

    if (mounted) setState(() => _playAllIndex = index);
  }

  void _stopPlayAll() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    if (mounted) {
      setState(() {
        _playAllActive = false;
        _playAllIndex = 0;
        _playAllQueue = [];
        _playAllSubjectLabels = [];
      });
    }
  }

  void _skipTrack() {
    if (_playAllIndex + 1 < _playAllQueue.length) {
      _playTrack(_playAllIndex + 1);
    } else {
      _stopPlayAll();
    }
  }

  void _prevTrack() {
    if (_playAllIndex > 0) {
      _playTrack(_playAllIndex - 1);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showPill =
        widget.user.isParent && widget.user.kidUids.length >= 2;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        title: Text('By Unit · Unit $_selectedUnit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (showPill && selectedChildId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: ChildSwitcherPill(
                  childIds: widget.user.kidUids,
                  childNames: childNames,
                  selectedId: selectedChildId,
                  onChanged: selectChild,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<MemoryProvider>(builder: (context, provider, _) {
            final units = provider.units;
            final subjects = provider.subjects;
            if (units.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                // Unit strip
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: units.length,
                    itemBuilder: (context, i) {
                      final u = units[i];
                      final selected = u.unitNumber == _selectedUnit;
                      Color bg;
                      if (u.isReview) {
                        bg = AppTheme.gold;
                      } else if (u.isBreak) {
                        bg = Colors.grey[300]!;
                      } else {
                        bg = AppTheme.navy;
                      }
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedUnit = u.unitNumber),
                        child: Container(
                          width: 44,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: selected
                                ? Border.all(
                                    color: AppTheme.gold, width: 2)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (u.isReview)
                                const Icon(Icons.refresh,
                                    size: 14, color: Colors.white)
                              else if (u.isBreak)
                                const Icon(Icons.bedtime_outlined,
                                    size: 14, color: Colors.white),
                              Text(
                                '${u.unitNumber}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: u.isBreak
                                      ? Colors.black54
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Play All button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _playAllActive ? _stopPlayAll : _startPlayAll,
                      icon: Icon(
                        _playAllActive
                            ? Icons.stop_circle_outlined
                            : Icons.playlist_play_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _playAllActive
                            ? 'Stop Playlist'
                            : '▶  Play All Songs for Unit $_selectedUnit',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _playAllActive
                            ? Colors.red[700]
                            : AppTheme.navy,
                        side: BorderSide(
                          color: _playAllActive
                              ? Colors.red[300]!
                              : AppTheme.navy.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),

                // Subject grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: subjects.length,
                    itemBuilder: (context, i) {
                      final s = subjects[i];
                      final effectiveChildId =
                          (widget.user.isParent &&
                                  selectedChildId.isNotEmpty)
                              ? selectedChildId
                              : null;
                      return _SubjectTile(
                        subject: s,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContentCardScreen(
                              subjectId: s.id,
                              unitNumber: _selectedUnit,
                              user: widget.user,
                              viewingChildId: effectiveChildId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }),

          // Mini-player bar (floats above content when Play All is active)
          if (_playAllActive && _playAllSubjectLabels.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _MiniPlayerBar(
                currentLabel: _playAllIndex < _playAllSubjectLabels.length
                    ? _playAllSubjectLabels[_playAllIndex]
                    : '...',
                currentIndex: _playAllIndex,
                totalTracks: _playAllQueue.length,
                onPrev: _prevTrack,
                onNext: _skipTrack,
                onStop: _stopPlayAll,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Subject Tile ─────────────────────────────────────────────────────────────

class _SubjectTile extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onTap;
  const _SubjectTile({required this.subject, required this.onTap});

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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_icons[subject.id] ?? '📚',
                  style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                subject.name.length > 10
                    ? subject.name.split(' ').first
                    : subject.name,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
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

// ─── Mini Player Bar ──────────────────────────────────────────────────────────

class _MiniPlayerBar extends StatelessWidget {
  final String currentLabel;
  final int currentIndex;
  final int totalTracks;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onStop;

  const _MiniPlayerBar({
    required this.currentLabel,
    required this.currentIndex,
    required this.totalTracks,
    required this.onPrev,
    required this.onNext,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navy,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Track dots
            Wrap(
              spacing: 3,
              children: List.generate(
                totalTracks,
                (i) => Container(
                  width: i == currentIndex ? 10 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentIndex
                        ? AppTheme.gold
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${currentIndex + 1} / $totalTracks',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded,
                  color: Colors.white, size: 22),
              onPressed: onPrev,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded,
                  color: Colors.white, size: 22),
              onPressed: onNext,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: Icon(Icons.stop_rounded,
                  color: AppTheme.gold, size: 22),
              onPressed: onStop,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}
