import 'package:flutter/material.dart';

/// Visual progress indicator showing sample collection as animated dots.
///
/// Displays a row of dots where:
/// - Filled dots with checkmarks = collected samples
/// - Empty bordered dot = next sample to collect
/// - Faint bordered dots = remaining samples
///
/// Each dot animates when transitioning between states.
class SampleProgressDots extends StatelessWidget {
  /// Number of samples collected
  final int collected;

  /// Total samples needed
  final int needed;

  /// Color for the progress dots
  final Color color;

  const SampleProgressDots({
    super.key,
    required this.collected,
    required this.needed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sample dots - use Wrap to handle small screens
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: List.generate(needed, (index) {
            final isCollected = index < collected;
            final isNext = index == collected;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isNext ? 24 : 20,
              height: isNext ? 24 : 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCollected ? color : Colors.transparent,
                border: Border.all(
                  color: isCollected
                      ? color
                      : (isNext ? color : Colors.white30),
                  width: isNext ? 3 : 2,
                ),
                boxShadow: isCollected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: isCollected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          '$collected / $needed samples',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
