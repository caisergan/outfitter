import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool showHighlight;

  const FrostedGlass({
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blur = 24,
    this.backgroundColor = AppColors.glass,
    this.border,
    this.boxShadow,
    this.showHighlight = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow ??
            [
              const BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
              const BoxShadow(
                color: AppColors.shadow,
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              border: border ??
                  Border.all(
                    color: AppColors.glassEdge.withValues(alpha: 0.88),
                    width: 1,
                  ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.12),
                          AppColors.glassGlow.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.22, 0.52, 1.0],
                      ),
                    ),
                  ),
                ),
                if (showHighlight)
                  Positioned(
                    left: 1,
                    right: 1,
                    top: 1,
                    child: IgnorePointer(
                      child: Container(
                        height: 1.4,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(999),
                            right: Radius.circular(999),
                          ),
                          color: AppColors.icyHighlight.withValues(alpha: 0.58),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: -18,
                  left: -10,
                  child: IgnorePointer(
                    child: Container(
                      width: 120,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.26),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconOrb extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? iconColor;

  const GlassIconOrb({
    required this.icon,
    this.size = 48,
    this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      blur: 22,
      backgroundColor: AppColors.glassUltra,
      borderRadius: BorderRadius.circular(size / 2),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadowSoft,
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: iconColor ?? AppColors.blush),
      ),
    );
  }
}
