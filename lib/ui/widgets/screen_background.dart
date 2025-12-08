import 'package:flutter/material.dart';

/// Reusable wallpaper wrapper that paints a themed background image
/// and adds a subtle dark overlay to keep foreground content legible.
class ScreenBackground extends StatelessWidget {
  /// Asset path for the background image.
  final String asset;

  /// Main screen content to render above the background.
  final Widget child;

  /// Optional image alignment for fine-tuning focal point.
  final Alignment alignment;

  /// Base opacity for the dark overlay. Defaults to 0.35.
  final double overlayOpacity;

  const ScreenBackground({
    super.key,
    required this.asset,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.overlayOpacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    final overlay = overlayOpacity.clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(asset),
          fit: BoxFit.cover,
          alignment: alignment,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: overlay + 0.15),
              Colors.black.withValues(alpha: overlay),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
