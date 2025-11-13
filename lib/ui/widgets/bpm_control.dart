import 'package:flutter/material.dart';

/// BPMControl provides intuitive BPM selection with slider and preset buttons
///
/// Features:
/// - Slider for fine-grained control (40-240 BPM with 1 BPM increments)
/// - Preset buttons for quick selection of common tempos
/// - Prominent display of current BPM value
/// - Clean, Material Design interface
///
/// The widget is stateless and calls the onChanged callback whenever
/// the BPM value changes (via slider or preset button).
///
/// Preset tempos provided:
/// - 60 BPM: Slow practice tempo
/// - 80 BPM: Moderate practice tempo
/// - 100 BPM: Medium tempo
/// - 120 BPM: Common default tempo
/// - 140 BPM: Up-tempo
/// - 160 BPM: Fast tempo
class BPMControl extends StatelessWidget {
  /// Current BPM value to display
  final int currentBpm;

  /// Callback invoked when BPM value changes
  final ValueChanged<int> onChanged;

  /// Available BPM presets for quick selection
  static const List<int> presets = [60, 80, 100, 120, 140, 160];

  const BPMControl({
    super.key,
    required this.currentBpm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current BPM Display
        Text(
          '$currentBpm BPM',
          style: Theme.of(
            context,
          ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // BPM Slider
        Slider(
          value: currentBpm.toDouble(),
          min: 40,
          max: 240,
          divisions: 200, // 1 BPM increments: (240 - 40) = 200
          label: '$currentBpm BPM',
          onChanged: (value) => onChanged(value.round()),
        ),
        const SizedBox(height: 16),

        // Preset Buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: presets.map((preset) {
            final isSelected = currentBpm == preset;
            return ElevatedButton(
              onPressed: () => onChanged(preset),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
                foregroundColor: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Text(
                '$preset',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
