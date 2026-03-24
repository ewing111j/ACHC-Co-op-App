// lib/services/audio_service.dart
// Centralized audio management for the Memory Work module (P1-3).
//
// Wraps just_audio AudioPlayer instances so content_card_screen,
// drill_session_screen, and young_learner_screens all share the same
// lifecycle logic (load, play, pause, dispose, error handling) without
// duplicating code.
//
// USAGE:
//   final _audio = AudioService();
//   await _audio.loadSung(url);
//   await _audio.playSung();
//   _audio.dispose();   // call in widget dispose()

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Describes which player fired a state change.
enum AudioTrack { sung, spoken }

/// Simple value class returned from [AudioService.state].
class AudioServiceState {
  final bool sungPlaying;
  final bool spokenPlaying;
  final Duration sungPosition;
  final Duration? sungDuration;
  final Duration? spokenDuration;
  final bool sungLoading;
  final bool spokenLoading;
  final String? sungError;
  final String? spokenError;

  const AudioServiceState({
    this.sungPlaying = false,
    this.spokenPlaying = false,
    this.sungPosition = Duration.zero,
    this.sungDuration,
    this.spokenDuration,
    this.sungLoading = false,
    this.spokenLoading = false,
    this.sungError,
    this.spokenError,
  });
}

class AudioService extends ChangeNotifier {
  final AudioPlayer _sungPlayer = AudioPlayer();
  final AudioPlayer _spokenPlayer = AudioPlayer();

  bool _sungPlaying = false;
  bool _spokenPlaying = false;
  Duration _sungPosition = Duration.zero;
  Duration? _sungDuration;
  Duration? _spokenDuration;
  bool _sungLoading = false;
  bool _spokenLoading = false;
  String? _sungError;
  String? _spokenError;

  bool _disposed = false;

  AudioServiceState get state => AudioServiceState(
        sungPlaying: _sungPlaying,
        spokenPlaying: _spokenPlaying,
        sungPosition: _sungPosition,
        sungDuration: _sungDuration,
        spokenDuration: _spokenDuration,
        sungLoading: _sungLoading,
        spokenLoading: _spokenLoading,
        sungError: _sungError,
        spokenError: _spokenError,
      );

  // ── Expose raw players for widgets that need direct access ────────────────
  AudioPlayer get sungPlayer => _sungPlayer;
  AudioPlayer get spokenPlayer => _spokenPlayer;

  // ── Initialise listeners ──────────────────────────────────────────────────
  AudioService() {
    _sungPlayer.playerStateStream.listen((ps) {
      _sungPlaying = ps.playing &&
          ps.processingState != ProcessingState.completed;
      if (ps.processingState == ProcessingState.completed) {
        _sungPlaying = false;
        _sungPosition = Duration.zero;
        _sungPlayer.seek(Duration.zero);
      }
      _safeNotify();
    });

    _sungPlayer.positionStream.listen((pos) {
      _sungPosition = pos;
      _safeNotify();
    });

    _sungPlayer.durationStream.listen((d) {
      _sungDuration = d;
      _safeNotify();
    });

    _spokenPlayer.playerStateStream.listen((ps) {
      _spokenPlaying = ps.playing &&
          ps.processingState != ProcessingState.completed;
      if (ps.processingState == ProcessingState.completed) {
        _spokenPlaying = false;
        _spokenPlayer.seek(Duration.zero);
      }
      _safeNotify();
    });

    _spokenPlayer.durationStream.listen((d) {
      _spokenDuration = d;
      _safeNotify();
    });
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Load a sung audio URL. Skips if the same URL is already loaded.
  Future<void> loadSung(String url) async {
    if (url.isEmpty) return;
    _sungError = null;
    _sungLoading = true;
    _safeNotify();
    try {
      if (kIsWeb) {
        // Web: setUrl is sufficient
        await _sungPlayer.setUrl(url);
      } else {
        await _sungPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      }
    } catch (e) {
      _sungError = 'Could not load audio';
      if (kDebugMode) debugPrint('[AudioService] loadSung error: $e');
    } finally {
      _sungLoading = false;
      _safeNotify();
    }
  }

  /// Load a spoken audio URL.
  Future<void> loadSpoken(String url) async {
    if (url.isEmpty) return;
    _spokenError = null;
    _spokenLoading = true;
    _safeNotify();
    try {
      if (kIsWeb) {
        await _spokenPlayer.setUrl(url);
      } else {
        await _spokenPlayer.setAudioSource(AudioSource.uri(Uri.parse(url)));
      }
    } catch (e) {
      _spokenError = 'Could not load audio';
      if (kDebugMode) debugPrint('[AudioService] loadSpoken error: $e');
    } finally {
      _spokenLoading = false;
      _safeNotify();
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> playSung() async {
    await _stopOther(AudioTrack.sung);
    await _sungPlayer.play();
  }

  Future<void> pauseSung() async => _sungPlayer.pause();

  Future<void> toggleSung() async {
    _sungPlaying ? await pauseSung() : await playSung();
  }

  Future<void> seekSung(Duration position) async {
    await _sungPlayer.seek(position);
  }

  Future<void> playSpoken() async {
    await _stopOther(AudioTrack.spoken);
    await _spokenPlayer.play();
  }

  Future<void> pauseSpoken() async => _spokenPlayer.pause();

  Future<void> toggleSpoken() async {
    _spokenPlaying ? await pauseSpoken() : await playSpoken();
  }

  // ── Stop all ──────────────────────────────────────────────────────────────

  Future<void> stopAll() async {
    await _sungPlayer.stop();
    await _spokenPlayer.stop();
    _sungPosition = Duration.zero;
  }

  // ── Reset (new card / navigate away) ─────────────────────────────────────

  Future<void> reset() async {
    await stopAll();
    _sungDuration = null;
    _spokenDuration = null;
    _sungError = null;
    _spokenError = null;
    _safeNotify();
  }

  // ── AppLifecycle support ──────────────────────────────────────────────────

  void onPause() {
    if (_sungPlaying) _sungPlayer.pause();
    if (_spokenPlaying) _spokenPlayer.pause();
  }

  void onResume() {
    // Don't auto-resume — wait for user tap
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _stopOther(AudioTrack active) async {
    if (active == AudioTrack.sung && _spokenPlaying) {
      await _spokenPlayer.stop();
    } else if (active == AudioTrack.spoken && _sungPlaying) {
      await _sungPlayer.stop();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sungPlayer.dispose();
    _spokenPlayer.dispose();
    super.dispose();
  }
}
