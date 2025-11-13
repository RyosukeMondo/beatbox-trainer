import 'package:flutter/material.dart';
import '../../services/debug/i_debug_service.dart';

/// Debug overlay widget for displaying real-time audio metrics and onset events.
///
/// This widget provides a semi-transparent overlay positioned at the top of the screen
/// that displays:
/// - Real-time audio DSP metrics (RMS, spectral centroid, spectral flux, frame number)
/// - RMS level meter with visual bar indicator
/// - Scrollable log of the last 10 onset events with classification details
///
/// The overlay is designed for development and debugging purposes, allowing developers
/// to monitor audio engine behavior in real-time without interfering with the main UI.
///
/// Example usage:
/// ```dart
/// Stack(
///   children: [
///     // Main app content
///     MyMainContent(),
///
///     // Debug overlay (when enabled)
///     if (debugModeEnabled)
///       DebugOverlay(
///         debugService: debugService,
///         onClose: () => setState(() => debugModeEnabled = false),
///         child: Container(), // Pass-through widget
///       ),
///   ],
/// )
/// ```
class DebugOverlay extends StatefulWidget {
  /// Debug service providing streams of audio metrics and onset events
  final IDebugService debugService;

  /// Callback invoked when the user taps the close button
  final VoidCallback onClose;

  /// Child widget to render below the overlay (for pass-through)
  final Widget child;

  /// Creates a debug overlay widget.
  ///
  /// Parameters:
  /// - [debugService]: Service providing debug data streams (required)
  /// - [onClose]: Callback for closing the overlay (required)
  /// - [child]: Widget to render below overlay, allows touch pass-through (optional)
  const DebugOverlay({
    super.key,
    required this.debugService,
    required this.onClose,
    this.child = const SizedBox.shrink(),
  });

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  /// Buffer of recent onset events for display (last 10)
  final List<OnsetEvent> _recentOnsets = [];

  /// Maximum number of onset events to keep in log
  static const int _maxOnsetLogSize = 10;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content (pass through touches by rendering child)
        widget.child,

        // Debug overlay positioned at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const Divider(color: Colors.white54),
                  const SizedBox(height: 8),
                  _buildAudioMetrics(),
                  const SizedBox(height: 16),
                  _buildOnsetLog(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build header with title and close button
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Debug Metrics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onClose,
          tooltip: 'Close debug overlay',
        ),
      ],
    );
  }

  /// Build audio metrics section with real-time updates
  Widget _buildAudioMetrics() {
    return StreamBuilder<AudioMetrics>(
      stream: widget.debugService.getAudioMetricsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'Waiting for audio data...',
            style: TextStyle(color: Colors.white54),
          );
        }

        if (!snapshot.hasData) {
          return const Text(
            'No audio data available',
            style: TextStyle(color: Colors.white54),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.redAccent),
          );
        }

        final metrics = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio Metrics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildMetricRow('RMS Level', metrics.rms.toStringAsFixed(3)),
            _buildMetricRow(
              'Spectral Centroid',
              '${metrics.spectralCentroid.toStringAsFixed(1)} Hz',
            ),
            _buildMetricRow(
              'Spectral Flux',
              metrics.spectralFlux.toStringAsFixed(3),
            ),
            _buildMetricRow('Frame', '#${metrics.frameNumber}'),
            _buildMetricRow('Timestamp', '${metrics.timestamp} ms'),
            const SizedBox(height: 8),
            _buildRmsLevelMeter(metrics.rms),
          ],
        );
      },
    );
  }

  /// Build a single metric row with label and value
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build animated RMS level meter bar
  Widget _buildRmsLevelMeter(double rms) {
    // RMS typically ranges from 0.0 to ~0.1 for speech/beatboxing
    // Scale by 10x to make the meter more visible
    final scaledRms = (rms * 10).clamp(0.0, 1.0);

    // Color code based on level: green (normal), yellow (loud), red (clipping)
    Color meterColor;
    if (scaledRms > 0.9) {
      meterColor = Colors.red;
    } else if (scaledRms > 0.7) {
      meterColor = Colors.orange;
    } else {
      meterColor = Colors.greenAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RMS Level Meter',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: FractionallySizedBox(
              widthFactor: scaledRms,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: meterColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build scrollable log of onset events
  Widget _buildOnsetLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Onset Events (Last 10)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: StreamBuilder<OnsetEvent>(
            stream: widget.debugService.getOnsetEventsStream(),
            builder: (context, snapshot) {
              // Add new onset events to the buffer
              if (snapshot.hasData) {
                _addOnsetToLog(snapshot.data!);
              }

              if (_recentOnsets.isEmpty) {
                return const Center(
                  child: Text(
                    'No onset events yet...',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              // Display onset events in reverse chronological order (newest first)
              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: _recentOnsets.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white24, height: 1),
                itemBuilder: (context, index) {
                  final event = _recentOnsets[index];
                  return _buildOnsetEventItem(event);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build a single onset event list item
  Widget _buildOnsetEventItem(OnsetEvent event) {
    // Extract classification if available
    final classification = event.classification;
    final classificationText = classification != null
        ? 'Sound: $classification'
        : 'No classification';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp and energy
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${event.timestamp} ms',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Energy: ${event.energy.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Classification
          Text(
            classificationText,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 2),
          // Features (compact display)
          Text(
            'C: ${event.centroid.toStringAsFixed(0)} Hz | '
            'ZCR: ${event.zcr.toStringAsFixed(2)} | '
            'Flat: ${event.flatness.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Add onset event to circular buffer (keeping last 10)
  void _addOnsetToLog(OnsetEvent event) {
    setState(() {
      // Add to the beginning (newest first)
      _recentOnsets.insert(0, event);

      // Limit buffer size to last N events
      if (_recentOnsets.length > _maxOnsetLogSize) {
        _recentOnsets.removeLast();
      }
    });
  }

  @override
  void dispose() {
    _recentOnsets.clear();
    super.dispose();
  }
}
