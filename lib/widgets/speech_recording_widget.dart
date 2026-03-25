// lib/widgets/speech_recording_widget.dart
//
// P3-1: Self-contained recording widget.
//
// States:
//   idle        → tap mic to start
//   listening   → animated mic, live transcript updated in real-time,
//                 auto-stop at maxDuration or silence timeout
//   processing  → scoring in progress (brief spinner)
//   done        → ResultBanner displayed
//
// Design:
//   • kIsWeb guard — on web preview shows a "not available on web" notice
//     rather than crashing (speech_to_text has no web engine in this env).
//   • 30-second hard cap; 4-second silence timeout after first words heard.
//   • Up to 3 attempts before forcing the manual self-check fallback.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/verification_service.dart';
import '../utils/app_theme.dart';
import 'result_banner.dart';

class SpeechRecordingWidget extends StatefulWidget {
  /// The canonical text the student should recite.
  final String targetText;

  /// Called when a final result is ready (pass, partial, fail, or fallback).
  /// Parent uses this to award WP and update progress.
  final ValueChanged<VerificationResult> onResult;

  /// Called when the user dismisses / closes the widget.
  final VoidCallback onDismiss;

  const SpeechRecordingWidget({
    super.key,
    required this.targetText,
    required this.onResult,
    required this.onDismiss,
  });

  @override
  State<SpeechRecordingWidget> createState() => _SpeechRecordingWidgetState();
}

class _SpeechRecordingWidgetState extends State<SpeechRecordingWidget>
    with SingleTickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();

  _RecordState _state = _RecordState.idle;
  String _liveTranscript = '';
  int _attemptsLeft = 3;
  VerificationResult? _result;
  String? _errorMsg;

  bool _sttAvailable = false;

  // Pulse animation controller for the mic button while listening
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  static const _maxDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (!kIsWeb) _initStt();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorMsg = 'Microphone error: ${e.errorMsg}';
            _state = _RecordState.idle;
          });
        }
      },
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable) {
      setState(() => _errorMsg = 'Microphone not available on this device.');
      return;
    }
    if (_attemptsLeft <= 0) {
      // Force fallback
      _triggerFallback();
      return;
    }

    setState(() {
      _state = _RecordState.listening;
      _liveTranscript = '';
      _errorMsg = null;
    });

    await _stt.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _liveTranscript = result.recognizedWords);
          // Auto-finalise when STT marks the result as final
          if (result.finalResult) _stopAndScore();
        }
      },
      listenFor: _maxDuration,
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      cancelOnError: false,
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> _stopAndScore() async {
    if (_state != _RecordState.listening) return;
    await _stt.stop();
    setState(() {
      _state = _RecordState.processing;
      _attemptsLeft--;
    });

    final result = await VerificationService.score(
      target: widget.targetText,
      transcript: _liveTranscript,
    );

    if (!mounted) return;

    // If STT returned empty and we still have attempts, offer retry rather
    // than immediately jumping to fallback
    if (result.outcome == ReciteOutcome.fallback && _attemptsLeft > 0) {
      setState(() {
        _result = result;
        _state = _RecordState.done;
      });
    } else {
      setState(() {
        _result = result;
        _state = _RecordState.done;
      });
      // Bubble non-fallback results up immediately
      if (result.outcome != ReciteOutcome.fallback) {
        widget.onResult(result);
      }
    }
  }

  void _triggerFallback() {
    final fallbackResult = VerificationResult(
      outcome: ReciteOutcome.fallback,
      scorePercent: 0,
      wpBonus: 0,
      diff: const [],
      transcript: '',
    );
    setState(() {
      _result = fallbackResult;
      _state = _RecordState.done;
    });
  }

  void _onFallbackSelected(VerificationResult r) {
    setState(() => _result = r);
    widget.onResult(r);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Web: STT not supported — show informational card
    if (kIsWeb) {
      return _WebUnsupportedCard(onDismiss: widget.onDismiss);
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildBody(),
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              _ErrorMessage(message: _errorMsg!),
            ],
            const SizedBox(height: 8),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.navy.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.record_voice_over_outlined,
              color: AppTheme.navy, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Recite Check',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (_attemptsLeft < 3)
          Text(
            '$_attemptsLeft attempt${_attemptsLeft != 1 ? 's' : ''} left',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: widget.onDismiss,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _RecordState.idle:
        return _IdleBody(
          available: _sttAvailable,
          onStart: _startListening,
        );

      case _RecordState.listening:
        return _ListeningBody(
          transcript: _liveTranscript,
          pulseAnim: _pulseAnim,
          onStop: _stopAndScore,
        );

      case _RecordState.processing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Checking...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        );

      case _RecordState.done:
        if (_result == null) return const SizedBox.shrink();
        return Column(
          children: [
            ResultBanner(
              result: _result!,
              target: widget.targetText,
              onFallbackSelected: _onFallbackSelected,
            ),
            if (_result!.outcome != ReciteOutcome.pass &&
                _attemptsLeft > 0 &&
                _result!.outcome != ReciteOutcome.fallback) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _startListening,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Try again ($_attemptsLeft left)'),
              ),
            ],
          ],
        );
    }
  }

  Widget _buildFooter() {
    if (_state == _RecordState.idle && !_sttAvailable) {
      return Text(
        'Initialising microphone…',
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
      );
    }
    if (_state == _RecordState.done && _result?.outcome != ReciteOutcome.fallback) {
      return TextButton(
        onPressed: widget.onDismiss,
        child: const Text('Done'),
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

enum _RecordState { idle, listening, processing, done }

class _IdleBody extends StatelessWidget {
  final bool available;
  final VoidCallback onStart;
  const _IdleBody({required this.available, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Tap the microphone and recite the item from memory.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: available ? onStart : null,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: available ? AppTheme.navy : Colors.grey[300],
              boxShadow: available
                  ? [
                      BoxShadow(
                        color: AppTheme.navy.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.mic,
              color: available ? Colors.white : Colors.grey[500],
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          available ? 'Tap to start' : 'Microphone initialising…',
          style: TextStyle(
            fontSize: 12,
            color: available ? AppTheme.navy : Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '🔒 Audio is processed on your device only',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }
}

class _ListeningBody extends StatelessWidget {
  final String transcript;
  final Animation<double> pulseAnim;
  final VoidCallback onStop;

  const _ListeningBody({
    required this.transcript,
    required this.pulseAnim,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pulsing stop button
        GestureDetector(
          onTap: onStop,
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: pulseAnim.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red[600],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.stop, color: Colors.white, size: 34),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Listening… tap stop when done',
          style: TextStyle(fontSize: 12, color: Colors.red),
        ),
        const SizedBox(height: 16),
        // Live transcript
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: transcript.isEmpty
              ? Text(
                  '…',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                )
              : Text(
                  transcript,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 200.ms);
  }
}

class _WebUnsupportedCard extends StatelessWidget {
  final VoidCallback onDismiss;
  const _WebUnsupportedCard({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Recite Check is available on the mobile app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onDismiss, child: const Text('OK')),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
