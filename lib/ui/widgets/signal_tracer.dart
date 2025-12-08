import 'package:flutter/material.dart';

/// Represents a pipeline stage in the audio analysis flow.
enum PipelineStage {
  input('Input', 'Audio samples received'),
  gate('Gate', 'Noise gate check'),
  onset('Onset', 'Onset detection'),
  features('Features', 'Feature extraction'),
  classify('Classify', 'Sound classification'),
  output('Output', 'Result to UI');

  final String label;
  final String description;
  const PipelineStage(this.label, this.description);
}

/// State of a pipeline stage for visualization.
class StageState {
  final PipelineStage stage;
  final bool active;
  final bool triggered;
  final String? value;
  final DateTime timestamp;

  StageState({
    required this.stage,
    this.active = false,
    this.triggered = false,
    this.value,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Signal tracer widget that visualizes the audio pipeline flow.
///
/// Shows each stage of the pipeline with real-time status:
/// - Gray: Inactive (no signal)
/// - Blue: Active (signal present)
/// - Green: Triggered (event detected)
///
/// Use this to understand where signals are flowing and where
/// they might be getting blocked or lost.
class SignalTracer extends StatelessWidget {
  /// Current state of each pipeline stage.
  final Map<PipelineStage, StageState> stages;

  /// Current RMS level (0.0 - 1.0).
  final double rmsLevel;

  /// Noise gate threshold (0.0 - 1.0).
  final double gateThreshold;

  /// Whether the gate is open (signal passing through).
  final bool gateOpen;

  /// Callback to enable/disable pipeline tracing.
  final ValueChanged<bool>? onTracingChanged;

  /// Whether tracing is currently enabled.
  final bool tracingEnabled;

  const SignalTracer({
    super.key,
    this.stages = const {},
    this.rmsLevel = 0.0,
    this.gateThreshold = 0.02,
    this.gateOpen = false,
    this.onTracingChanged,
    this.tracingEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Signal Tracer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onTracingChanged != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Trace',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: tracingEnabled,
                      onChanged: onTracingChanged,
                      activeTrackColor: Colors.green.withAlpha(180),
                      activeThumbColor: Colors.green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Pipeline visualization
          _buildPipelineFlow(),
          const SizedBox(height: 12),
          // Level indicator
          _buildLevelIndicator(),
        ],
      ),
    );
  }

  Widget _buildPipelineFlow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final stage in PipelineStage.values) ...[
          _buildStageIndicator(stage),
          if (stage != PipelineStage.output) _buildArrow(stage),
        ],
      ],
    );
  }

  Widget _buildStageIndicator(PipelineStage stage) {
    final state = stages[stage];
    final isActive =
        state?.active ?? (stage == PipelineStage.input && rmsLevel > 0.001);
    final isTriggered = state?.triggered ?? false;

    Color color;
    if (isTriggered) {
      color = Colors.green;
    } else if (isActive) {
      color = Colors.blue;
    } else {
      color = Colors.grey[700]!;
    }

    return Tooltip(
      message: '${stage.description}\n${state?.value ?? ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isTriggered ? Colors.greenAccent : Colors.white30,
                width: isTriggered ? 2 : 1,
              ),
              boxShadow: isTriggered
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                stage.label[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stage.label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow(PipelineStage stage) {
    final isGateStage = stage == PipelineStage.gate;
    final isBlocked = isGateStage && !gateOpen && rmsLevel > 0.001;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Icon(
        isBlocked ? Icons.close : Icons.arrow_forward,
        color: isBlocked ? Colors.red : Colors.white30,
        size: 16,
      ),
    );
  }

  Widget _buildLevelIndicator() {
    final normalizedLevel = (rmsLevel * 10).clamp(0.0, 1.0);
    final gateNormalized = (gateThreshold * 10).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Level: ',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              '${(rmsLevel * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: gateOpen ? Colors.green : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Gate: ${(gateThreshold * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: gateOpen ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                gateOpen ? 'OPEN' : 'CLOSED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Background
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Level bar
                FractionallySizedBox(
                  widthFactor: normalizedLevel,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: gateOpen ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Gate threshold marker
                Positioned(
                  left: gateNormalized * constraints.maxWidth,
                  child: Container(width: 2, height: 8, color: Colors.orange),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
