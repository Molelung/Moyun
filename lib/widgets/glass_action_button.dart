import 'dart:ui';
import 'package:flutter/material.dart';

class GlassActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final double padding;

  const GlassActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconSize = 22.0,
    this.padding = 9.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 0.8),
          ),
          child: IconButton(
            iconSize: iconSize,
            padding: EdgeInsets.all(padding),
            icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}
