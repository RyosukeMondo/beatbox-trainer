import 'package:flutter/material.dart';
import '../../services/debug/i_debug_service.dart';

/// Real-time audio level indicator for training screen.
///
/// Shows current RMS level with a threshold marker indicating
/// the minimum level needed for sound detection.
class TrainingLevelIndicator extends StatelessWidget {
  /// Current audio metrics from the engine
  final AudioMetrics? metrics;

  /// Noise floor threshold (sounds below this × 2 won't be detected)
  final double noiseFloorRms;

  const TrainingLevelIndicator({
    super.key,
    required this.metrics,
    required this.noiseFloorRms,
  });

  @override
  Widget build(BuildContext context) {
    final rms = metrics?.rms ?? 0.0;
    // Detection gate is 2x noise floor (matches Rust logic)
    final detectionGate = noiseFloorRms * 2.0;

    // Scale for display: map 0-0.15 RMS to 0-1 visual range
    const maxDisplayRms = 0.15;
    final normalizedLevel = (rms / maxDisplayRms).clamp(0.0, 1.0);
    final normalizedGate = (detectionGate / maxDisplayRms).clamp(0.0, 0.8);

    final isAboveGate = rms >= detectionGate;
    final isStrong = rms >= detectionGate * 1.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isStrong
              ? Colors.green.withAlpha(180)
              : isAboveGate
              ? Colors.amber.withAlpha(128)
              : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isAboveGate ? Icons.mic : Icons.mic_none,
                color: isStrong
                    ? Colors.green
                    : isAboveGate
                    ? Colors.amber
                    : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'INPUT LEVEL',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              _buildStatusBadge(isAboveGate, isStrong),
            ],
          ),
          const SizedBox(height: 8),

          // Level bar with gate marker
          SizedBox(
            height: 32,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gateX = constraints.maxWidth * normalizedGate;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background track
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    // "Detection zone" (above gate) - subtle highlight
                    Positioned(
                      left: gateX,
                      right: 0,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withAlpha(25),
                              Colors.green.withAlpha(50),
                            ],
                          ),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // Current level bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 50),
                      width: constraints.maxWidth * normalizedLevel,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: isStrong
                              ? [Colors.green.shade600, Colors.green]
                              : isAboveGate
                              ? [Colors.amber.shade600, Colors.amber]
                              : [Colors.grey.shade600, Colors.grey.shade500],
                        ),
                        boxShadow: isAboveGate
                            ? [
                                BoxShadow(
                                  color:
                                      (isStrong ? Colors.green : Colors.amber)
                                          .withAlpha(100),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),

                    // Gate marker
                    Positioned(
                      left: gateX - 1,
                      top: 0,
                      child: Container(
                        width: 2,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),

                    // "MIN" label below gate marker
                    Positioned(
                      left: gateX - 12,
                      top: 26,
                      child: const Text(
                        'MIN',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // RMS values for debugging
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RMS: ${(rms * 1000).toStringAsFixed(1)}',
                style: TextStyle(
                  color: isAboveGate ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Gate: ${(detectionGate * 1000).toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isAboveGate, bool isStrong) {
    if (isStrong) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withAlpha(128)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text(
              'DETECTED',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (isAboveGate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hearing, color: Colors.amber, size: 14),
            SizedBox(width: 4),
            Text(
              'HEARD',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_off, color: Colors.white38, size: 14),
            SizedBox(width: 4),
            Text(
              'WAITING',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }
}
