import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/debug/fixture_anomaly_notice.dart';

class DebugAnomalyBanner extends StatelessWidget {
  const DebugAnomalyBanner({
    super.key,
    required this.notice,
    required this.onDismiss,
  });

  final FixtureAnomalyNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildLogSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fixture ${notice.fixtureId} reported anomalies',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...notice.messages.map(
                (msg) => Text('• $msg', style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Dismiss',
          onPressed: onDismiss,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildLogSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          'Log: ${notice.logPath}',
          style: theme.textTheme.bodySmall,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: notice.logPath));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Log path copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy log path'),
          ),
        ),
      ],
    );
  }
}
