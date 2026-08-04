import 'dart:ui';

import 'package:flutter/material.dart';

/// 液态玻璃容器：半透明磨砂 + 细描边 + 圆角，与首页卡片风格一致。
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final double blur;
  final Color tint;
  final Border? border;
  final BoxConstraints? constraints;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 20,
    this.blur = 12,
    this.tint = Colors.white,
    this.border,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      constraints: constraints,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(radius),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
