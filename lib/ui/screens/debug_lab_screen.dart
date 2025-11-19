import 'package:flutter/material.dart';
import '../../controllers/debug/debug_lab_controller.dart';
import '../../di/service_locator.dart';
import '../../models/debug/fixture_anomaly_notice.dart';
import '../../models/debug_log_entry.dart';
import '../../services/audio/i_audio_service.dart';
import '../../services/debug/debug_sse_client.dart';
import '../../services/debug/fixture_metadata_service.dart';
import '../../services/debug/i_debug_service.dart';
import '../../services/debug/i_log_exporter.dart';
import '../widgets/debug/anomaly_banner.dart';
import '../widgets/debug/debug_log_list.dart';
import '../widgets/debug/debug_server_panel.dart';
import '../widgets/debug/param_slider_card.dart';
import '../widgets/debug/telemetry_chart.dart';

/// Debug Lab screen showing live telemetry, SSE hooks, and parameter sliders.
class DebugLabScreen extends StatefulWidget {
  const DebugLabScreen._({
    super.key,
    required this.controller,
    required this.logExporter,
  });

  final DebugLabController controller;
  final ILogExporter logExporter;

  factory DebugLabScreen.create({Key? key}) {
    return DebugLabScreen._(
      key: key,
      controller: DebugLabController(
        audioService: getIt<IAudioService>(),
        debugService: getIt<IDebugService>(),
        fixtureMetadataService: getIt<IFixtureMetadataService>(),
        sseClient: DebugSseClient(),
      ),
      logExporter: getIt<ILogExporter>(),
    );
  }

  @visibleForTesting
  factory DebugLabScreen.test({
    Key? key,
    required DebugLabController controller,
    required ILogExporter logExporter,
  }) {
    return DebugLabScreen._(
      key: key,
      controller: controller,
      logExporter: logExporter,
    );
  }

  @override
  State<DebugLabScreen> createState() => _DebugLabScreenState();
}

class _DebugLabScreenState extends State<DebugLabScreen> {
  final TextEditingController _fixtureIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    _fixtureIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note),
            tooltip: 'Export logs',
            onPressed: _exportLogs,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DebugServerPanel(
            remoteConnected: widget.controller.remoteConnected,
            errorText: widget.controller.remoteError,
            onConnect: (uri, token) =>
                widget.controller.connectRemote(baseUri: uri, token: token),
            onDisconnect: widget.controller.disconnectRemote,
          ),
          const SizedBox(height: 12),
          _buildSyntheticToggle(),
          const SizedBox(height: 12),
          _buildFixtureControls(),
          const SizedBox(height: 16),
          _buildMetricsCard(),
          const SizedBox(height: 16),
          TelemetryChart(stream: widget.controller.telemetryStream),
          const SizedBox(height: 16),
          _buildParamCards(),
          const SizedBox(height: 16),
          Text('Event Log', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<List<DebugLogEntry>>(
            valueListenable: widget.controller.logEntries,
            builder: (context, entries, _) => DebugLogList(entries: entries),
          ),
        ],
      ),
    );
  }

  Widget _buildSyntheticToggle() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.syntheticEnabled,
      builder: (context, enabled, _) => SwitchListTile.adaptive(
        value: enabled,
        onChanged: widget.controller.setSyntheticInput,
        title: const Text('Synthetic fixtures'),
        subtitle: const Text('Inject predictable events for demos'),
      ),
    );
  }

  Widget _buildFixtureControls() {
    return Column(
      children: [
        _buildFixtureSelector(),
        const SizedBox(height: 12),
        _buildAnomalyBanner(),
      ],
    );
  }

  Widget _buildFixtureSelector() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _fixtureIdController,
            decoration: const InputDecoration(
              labelText: 'Fixture ID (optional)',
              hintText: 'basic_hits',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            widget.controller.setFixtureUnderTest(_fixtureIdController.text);
          },
          child: const Text('Load metadata'),
        ),
        TextButton(
          onPressed: () {
            _fixtureIdController.clear();
            widget.controller.setFixtureUnderTest(null);
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildAnomalyBanner() {
    return ValueListenableBuilder<FixtureAnomalyNotice?>(
      valueListenable: widget.controller.fixtureAnomaly,
      builder: (context, notice, _) {
        if (notice == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DebugAnomalyBanner(
            notice: notice,
            onDismiss: widget.controller.dismissAnomalyNotice,
          ),
        );
      },
    );
  }

  Widget _buildMetricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<AudioMetrics>(
          stream: widget.controller.metricsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('Waiting for audio metrics…');
            }
            final metrics = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Metrics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildMetricRow('RMS', metrics.rms.toStringAsFixed(3)),
                _buildMetricRow(
                  'Spectral Centroid',
                  '${metrics.spectralCentroid.toStringAsFixed(1)} Hz',
                ),
                _buildMetricRow(
                  'Spectral Flux',
                  metrics.spectralFlux.toStringAsFixed(3),
                ),
                _buildMetricRow('Frame', metrics.frameNumber.toString()),
                _buildMetricRow('Timestamp', '${metrics.timestamp} ms'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildParamCards() {
    return Column(
      children: [
        ParamSliderCard(
          title: 'Live BPM',
          description: 'Send ParamPatch to update tempo immediately.',
          min: 40,
          max: 240,
          initialValue: 120,
          unit: ' BPM',
          onSubmit: (value) =>
              widget.controller.applyParamPatch(bpm: value.round()),
        ),
        ParamSliderCard(
          title: 'Spectral Centroid Threshold',
          description: 'Hi-hat detection threshold (0.05 - 1.0).',
          min: 0.05,
          max: 1.0,
          initialValue: 0.35,
          step: 0.01,
          onSubmit: (value) => widget.controller.applyParamPatch(
            centroidThreshold: double.parse(value.toStringAsFixed(2)),
          ),
        ),
        ParamSliderCard(
          title: 'ZCR Threshold',
          description: 'Controls hi-hat vs kick separation.',
          min: 0.05,
          max: 1.0,
          initialValue: 0.25,
          step: 0.01,
          onSubmit: (value) => widget.controller.applyParamPatch(
            zcrThreshold: double.parse(value.toStringAsFixed(2)),
          ),
        ),
      ],
    );
  }

  Future<void> _exportLogs() async {
    final exported = await widget.logExporter.exportLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Logs exported:\n$exported')));
  }
}
