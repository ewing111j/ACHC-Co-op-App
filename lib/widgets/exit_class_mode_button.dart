// lib/widgets/exit_class_mode_button.dart
// Floating "Exit Class Mode" button — positioned top-right overlay.
// Taps call classMode.exitClassMode() and pops to MemoryWorkHomeScreen.
// Used in P1-6: Class Mode screens.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/class_mode_provider.dart';
import '../utils/app_theme.dart';

class ExitClassModeButton extends StatelessWidget {
  const ExitClassModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.read<ClassModeProvider>().exitClassMode();
                // Pop back to root of memory work stack
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.navy.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.exit_to_app_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Exit Class Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
              ),
        ),
      ),
    );
  }
}

/// Convenience wrapper — use this as a Stack child on class mode screens.
/// Example:
///   Stack(children: [
///     YourScreen(),
///     if (isClassMode) const ClassModeOverlay(),
///   ])
class ClassModeOverlay extends StatelessWidget {
  const ClassModeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      ignoring: false,
      child: ExitClassModeButton(),
    );
  }
}
