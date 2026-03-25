// lib/screens/training/training_resource_screen.dart
// P2-2: View a single training resource (PDF or Video).

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/training_models.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_animations.dart';

class TrainingResourceScreen extends StatefulWidget {
  final TrainingResourceModel resource;
  final Color color;
  final UserModel user;

  const TrainingResourceScreen({
    super.key,
    required this.resource,
    required this.color,
    required this.user,
  });

  @override
  State<TrainingResourceScreen> createState() => _TrainingResourceScreenState();
}

class _TrainingResourceScreenState extends State<TrainingResourceScreen> {
  bool _viewed = false;
  bool _markingViewed = false;
  PdfControllerPinch? _pdfController;
  bool _pdfLoading = false;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    _checkViewed();
    if (widget.resource.isPdf) _initPdf();
  }

  Future<void> _checkViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        prefs.getStringList('training_viewed_${widget.user.uid}') ?? [];
    if (mounted) setState(() => _viewed = list.contains(widget.resource.id));
  }

  Future<void> _initPdf() async {
    if (widget.resource.url.isEmpty) return;
    setState(() => _pdfLoading = true);
    try {
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(
          InternetFile.get(widget.resource.url),
        ),
      );
      if (mounted) setState(() { _pdfController = controller; _pdfLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _pdfError = 'Could not load PDF'; _pdfLoading = false; });
    }
  }

  Future<void> _markViewed() async {
    if (_viewed || _markingViewed) return;
    setState(() => _markingViewed = true);
    final prefs = await SharedPreferences.getInstance();
    final key = 'training_viewed_${widget.user.uid}';
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(widget.resource.id)) {
      list.add(widget.resource.id);
      await prefs.setStringList(key, list);
    }
    if (mounted) setState(() { _viewed = true; _markingViewed = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Marked as viewed!'),
          backgroundColor: AppTheme.classesColor,
          duration: Duration(seconds: 2)));
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        title: Text(widget.resource.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          if (!_viewed)
            TextButton.icon(
              onPressed: _markViewed,
              icon: AnimatedSwitcher(
                duration: AppAnimations.navTransitionDuration,
                child: _markingViewed
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline,
                        key: ValueKey('icon'),
                        color: Colors.white70,
                        size: 18),
              ),
              label: const Text('Mark Viewed',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: const Icon(Icons.check_circle,
                      color: Colors.white, size: 22)
                  .animate()
                  .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut),
            ),
        ],
      ),
      body: widget.resource.isVideo
          ? _VideoView(resource: widget.resource, color: widget.color)
          : _PdfView(
              controller: _pdfController,
              loading: _pdfLoading,
              error: _pdfError,
              resource: widget.resource,
              color: widget.color,
            ),
    );
  }
}

// ── Video View ────────────────────────────────────────────────────────────────
class _VideoView extends StatelessWidget {
  final TrainingResourceModel resource;
  final Color color;
  const _VideoView({required this.resource, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_filled, size: 64, color: color),
                const SizedBox(height: 8),
                if (resource.durationLabel.isNotEmpty)
                  Text(resource.durationLabel,
                      style: TextStyle(color: color, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(resource.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyDark)),
          const SizedBox(height: 8),
          Text(resource.description,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open Video'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final uri = Uri.tryParse(resource.url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── PDF View ──────────────────────────────────────────────────────────────────
class _PdfView extends StatelessWidget {
  final PdfControllerPinch? controller;
  final bool loading;
  final String? error;
  final TrainingResourceModel resource;
  final Color color;

  const _PdfView({
    required this.controller,
    required this.loading,
    required this.error,
    required this.resource,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null || controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: color.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(error ?? 'PDF unavailable',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open in Browser'),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              onPressed: () async {
                final uri = Uri.tryParse(resource.url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      );
    }
    return PdfViewPinch(controller: controller!);
  }
}

// Helper for loading PDF from URL
class InternetFile {
  static Future<Uint8List> get(String url) async {
    final uri = Uri.parse(url);
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }
}


