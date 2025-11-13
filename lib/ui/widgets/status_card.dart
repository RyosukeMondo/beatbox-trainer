import 'package:flutter/material.dart';

/// A reusable status card widget that displays information with a
/// colored border, icon, title, and optional subtitle.
///
/// This widget is designed to display status messages, completion states,
/// and informational content across the application with consistent styling.
///
/// Example usage:
/// ```dart
/// StatusCard(
///   color: Colors.green,
///   icon: Icons.check_circle,
///   title: 'Success!',
///   subtitle: 'Operation completed',
/// )
/// ```
class StatusCard extends StatelessWidget {
  /// Creates a status card with the specified styling and content.
  ///
  /// The [color] parameter sets both the border color and icon color.
  /// The [icon] parameter specifies which icon to display.
  /// The [title] parameter sets the main text content.
  /// The [subtitle] parameter is optional and displays below the title.
  const StatusCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 32.0,
  });

  /// The color used for the border, background tint, and icon.
  final Color color;

  /// The icon to display at the top of the card.
  final IconData icon;

  /// The main title text displayed prominently.
  final String title;

  /// Optional subtitle text displayed below the title.
  final String? subtitle;

  /// Size of the icon. Defaults to 32.0.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
