import 'package:flutter/material.dart';

/// Visual audio level meter with optimal range indicator.
///
/// Displays real-time audio level with gradient coloring:
/// - Green: Quiet levels (0-60%)
/// - Yellow: Good levels (60-85%)
/// - Red: Loud levels (85-100%)
///
/// Features an "optimal range" overlay to guide users.
class AudioLevelMeter extends StatelessWidget {
  /// Current audio level (0.0 to 1.0)
  final double level;

  /// Height of the meter bar
  final double height;

  const AudioLevelMeter({super.key, required this.level, this.height = 24});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'AUDIO LEVEL',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.white10,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Level bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: constraints.maxWidth * level,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: LinearGradient(colors: _getGradientColors()),
                    ),
                  ),
                  // Optimal range indicator
                  Positioned(
                    left: constraints.maxWidth * 0.4,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: constraints.maxWidth * 0.35,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30, width: 1),
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quiet',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OPTIMAL',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Text(
              'Loud',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  List<Color> _getGradientColors() {
    return [
      Colors.green,
      level > 0.6 ? Colors.yellow : Colors.green,
      level > 0.85 ? Colors.red : (level > 0.6 ? Colors.yellow : Colors.green),
    ];
  }
}
