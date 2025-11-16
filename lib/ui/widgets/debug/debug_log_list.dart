import 'package:flutter/material.dart';
import '../../../models/debug_log_entry.dart';

/// Scrollable list rendering DebugLab log entries with severity badges.
class DebugLogList extends StatelessWidget {
  const DebugLogList({
    super.key,
    required this.entries,
  });

  final List<DebugLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No events yet. Start training or connect remote stream.',
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length.clamp(0, 30),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          leading: _buildSeverityBadge(entry),
          title: Text(entry.title),
          subtitle: Text(entry.detail ?? '—'),
          trailing: Text(
            TimeOfDay.fromDateTime(entry.timestamp).format(context),
            semanticsLabel: 'Timestamp ${entry.timestamp}',
          ),
        );
      },
    );
  }

  Widget _buildSeverityBadge(DebugLogEntry entry) {
    final color = switch (entry.severity) {
      DebugLogSeverity.info => Colors.blueGrey,
      DebugLogSeverity.warning => Colors.orange,
      DebugLogSeverity.error => Colors.redAccent,
    };
    final label = switch (entry.source) {
      DebugLogSource.device => 'DEV',
      DebugLogSource.remote => 'REM',
      DebugLogSource.synthetic => 'SYN',
      DebugLogSource.telemetry => 'TEL',
      DebugLogSource.system => 'SYS',
    };
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      foregroundColor: color,
      child: Text(label, semanticsLabel: 'Source $label'),
    );
  }
}
