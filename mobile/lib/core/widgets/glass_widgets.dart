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

  const FrostedGlass({
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blur = 24,
    this.backgroundColor = AppColors.glass,
    this.border,
    this.boxShadow,
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
                color: AppColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              border: border ??
                  Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
            ),
            child: child,
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
      blur: 18,
      backgroundColor: AppColors.glassStrong,
      borderRadius: BorderRadius.circular(size / 2),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 18,
          offset: Offset(0, 8),
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
