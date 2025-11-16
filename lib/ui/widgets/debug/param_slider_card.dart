import 'package:flutter/material.dart';

typedef ParamSubmit = Future<void> Function(double value);

/// Card widget for parameter tuning with slider + apply button.
class ParamSliderCard extends StatefulWidget {
  const ParamSliderCard({
    super.key,
    required this.title,
    required this.description,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onSubmit,
    this.step = 1,
    this.unit = '',
  });

  final String title;
  final String description;
  final double min;
  final double max;
  final double initialValue;
  final ParamSubmit onSubmit;
  final double step;
  final String unit;

  @override
  State<ParamSliderCard> createState() => _ParamSliderCardState();
}

class _ParamSliderCardState extends State<ParamSliderCard> {
  late double _value = widget.initialValue;
  bool _pending = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(widget.description, style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: _value,
              min: widget.min,
              max: widget.max,
              divisions: ((widget.max - widget.min) / widget.step).round(),
              label: '${_value.toStringAsFixed(1)}${widget.unit}',
              onChanged: (value) => setState(() => _value = value),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _pending ? null : _submit,
                icon: _pending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _pending ? 'Applying…' : 'Apply ${widget.unit.trim()}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _pending = true);
    try {
      await widget.onSubmit(_value);
    } finally {
      if (mounted) {
        setState(() => _pending = false);
      }
    }
  }
}
