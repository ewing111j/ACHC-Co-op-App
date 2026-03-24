// lib/utils/app_page_route.dart
// Navigation transition routes for ACHC Hub.
// Animation 14B: ClassModeZoomRoute — zoom in to enter class mode.
// Standard MemoryWorkRoute: slide up + fade (Animation 14).

import 'package:flutter/material.dart';
import 'app_animations.dart';

/// Standard Memory Work navigation — slide up + fade (Animation 14).
class MemoryWorkRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  MemoryWorkRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: AppAnimations.navTransitionDuration,
          reverseTransitionDuration: AppAnimations.navTransitionDuration,
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            // Outgoing screen: slight fade + slide left
            final secondaryCurved = CurvedAnimation(
              parent: secondary,
              curve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.07),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: FadeTransition(
                  opacity: Tween<double>(
                    begin: 1.0,
                    end: 0.92,
                  ).animate(secondaryCurved),
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Animation 14B: ClassModeZoomRoute — zoom in when entering class mode.
/// Exit reverses: scale 1.0 → 0.85 with fade.
class ClassModeZoomRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ClassModeZoomRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: AppAnimations.classModeZoomDuration,
          reverseTransitionDuration: AppAnimations.classModeZoomDuration,
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppAnimations.classModeZoomCurve,
            );

            final reverseCurved = CurvedAnimation(
              parent: secondary,
              curve: AppAnimations.classModeZoomCurve,
            );

            return ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: ScaleTransition(
                  // Outgoing screen shrinks slightly (1.0 → 0.95)
                  scale: Tween<double>(begin: 1.0, end: 0.95)
                      .animate(reverseCurved),
                  child: child,
                ),
              ),
            );
          },
        );
}
