import 'package:flutter/material.dart';
import '../../bridge/api.dart/api.dart' as api;
import '../../bridge/api.dart/api/types.dart';

/// Debug panel for displaying and adjusting calibration parameters.
///
/// Shows current threshold values with sliders for manual adjustment.
/// Designed for debugging detection issues.
class CalibrationDebugPanel extends StatefulWidget {
  const CalibrationDebugPanel({super.key});

  @override
  State<CalibrationDebugPanel> createState() => _CalibrationDebugPanelState();
}

class _CalibrationDebugPanelState extends State<CalibrationDebugPanel> {
  // Current calibration values
  double _kickCentroid = 1500;
  double _kickZcr = 0.1;
  double _snareCentroid = 4000;
  double _hihatZcr = 0.3;
  double _noiseFloorRms = 0.01;
  bool _isCalibrated = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalibrationState();
  }

  Future<void> _loadCalibrationState() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final state = await api.getCalibrationState();
      debugPrint('[CalibrationDebugPanel] State: $state');

      if (mounted) {
        setState(() {
          _kickCentroid = state.tKickCentroid;
          _kickZcr = state.tKickZcr;
          _snareCentroid = state.tSnareCentroid;
          _hihatZcr = state.tHihatZcr;
          _noiseFloorRms = state.noiseFloorRms;
          _isCalibrated = state.isCalibrated;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CalibrationDebugPanel] Error loading state: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateThreshold(CalibrationThresholdKey key, double value) async {
    try {
      await api.updateCalibrationThreshold(key: key, value: value);
      debugPrint('[CalibrationDebugPanel] Updated $key to $value');
    } catch (e) {
      debugPrint('[CalibrationDebugPanel] Error updating $key: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating $key: $e')));
      }
    }
  }

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
                'Calibration Parameters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _isCalibrated ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isCalibrated ? 'CALIBRATED' : 'DEFAULT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    iconSize: 20,
                    onPressed: _loadCalibrationState,
                    tooltip: 'Reload',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Text('Error: $_error', style: const TextStyle(color: Colors.red))
          else ...[
            _buildThresholdSlider(
              'Noise Floor RMS',
              CalibrationThresholdKey.noiseFloorRms,
              _noiseFloorRms,
              0.001,
              0.1,
              (v) => setState(() => _noiseFloorRms = v),
              info: 'Gate: ${(_noiseFloorRms * 2).toStringAsFixed(4)}',
            ),
            _buildThresholdSlider(
              'Kick Centroid',
              CalibrationThresholdKey.kickCentroid,
              _kickCentroid,
              500,
              5000,
              (v) => setState(() => _kickCentroid = v),
              unit: 'Hz',
            ),
            _buildThresholdSlider(
              'Kick ZCR',
              CalibrationThresholdKey.kickZcr,
              _kickZcr,
              0.01,
              0.5,
              (v) => setState(() => _kickZcr = v),
            ),
            _buildThresholdSlider(
              'Snare Centroid',
              CalibrationThresholdKey.snareCentroid,
              _snareCentroid,
              2000,
              10000,
              (v) => setState(() => _snareCentroid = v),
              unit: 'Hz',
            ),
            _buildThresholdSlider(
              'Hi-Hat ZCR',
              CalibrationThresholdKey.hihatZcr,
              _hihatZcr,
              0.1,
              0.8,
              (v) => setState(() => _hihatZcr = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThresholdSlider(
    String label,
    CalibrationThresholdKey key,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String unit = '',
    String? info,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${value.toStringAsFixed(key.contains('zcr') || key.contains('noise') ? 4 : 1)}$unit',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (info != null)
            Text(
              info,
              style: const TextStyle(color: Colors.yellow, fontSize: 10),
            ),
          Material(
            color: Colors.transparent,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.grey[700],
                thumbColor: Colors.blue,
                overlayColor: Colors.blue.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: (v) => _updateThreshold(key, v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
