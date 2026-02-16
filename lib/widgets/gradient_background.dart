import 'package:flutter/material.dart';
import 'package:attendance_system/core/theme/app_colors.dart';

/// A reusable gradient background scaffold wrapper.
///
/// Wraps [child] in a deep-blue gradient with optional decorative circles.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;
  final bool showDecorations;

  const GradientBackground({
    super.key,
    required this.child,
    this.gradient,
    this.showDecorations = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.primaryGradient,
      ),
      child: showDecorations
          ? Stack(
              children: [
                // Top-right decorative circle
                Positioned(
                  top: -80,
                  right: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                // Bottom-left decorative circle
                Positioned(
                  bottom: -100,
                  left: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                // Mid-left small circle
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.4,
                  left: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child,
              ],
            )
          : child,
    );
  }
}
