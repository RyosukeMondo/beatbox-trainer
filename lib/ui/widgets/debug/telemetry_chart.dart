import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/telemetry_event.dart';

/// Mini line chart for telemetry BPM events.
class TelemetryChart extends StatefulWidget {
  const TelemetryChart({super.key, required this.stream});

  final Stream<TelemetryEvent> stream;

  @override
  State<TelemetryChart> createState() => _TelemetryChartState();
}

class _TelemetryChartState extends State<TelemetryChart> {
  static const int _maxPoints = 20;
  final List<_ChartPoint> _points = [];
  StreamSubscription<TelemetryEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen((event) {
      if (event.bpm == null) return;
      setState(() {
        _points.insert(
          0,
          _ChartPoint(bpm: event.bpm!, timestamp: DateTime.now()),
        );
        if (_points.length > _maxPoints) {
          _points.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _TelemetryPainter(points: _points),
        child: Center(
          child: _points.isEmpty
              ? const Text('Waiting for telemetry…')
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ChartPoint {
  _ChartPoint({required this.bpm, required this.timestamp});
  final int bpm;
  final DateTime timestamp;
}

class _TelemetryPainter extends CustomPainter {
  _TelemetryPainter({required this.points});

  final List<_ChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (points.isEmpty) {
      return;
    }

    final path = Path();
    final maxBpm = points.map((p) => p.bpm).reduce(math.max).toDouble();
    final minBpm = points.map((p) => p.bpm).reduce(math.min).toDouble();
    final span = math.max(1, maxBpm - minBpm);
    final dx = size.width / math.max(1, points.length - 1);

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = size.width - (index * dx);
      final normalized = (point.bpm - minBpm) / span;
      final y = size.height - (normalized * size.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TelemetryPainter oldDelegate) =>
      oldDelegate.points != points;
}
