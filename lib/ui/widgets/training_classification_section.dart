import 'package:flutter/material.dart';
import '../../models/classification_result.dart';
import '../utils/display_formatters.dart';

/// Classification viewer with fade animation and stream handling.
class TrainingClassificationSection extends StatefulWidget {
  const TrainingClassificationSection({
    super.key,
    required this.isTraining,
    required this.classificationStream,
  });

  final bool isTraining;
  final Stream<ClassificationResult> classificationStream;

  @override
  State<TrainingClassificationSection> createState() =>
      _TrainingClassificationSectionState();
}

class _TrainingClassificationSectionState
    extends State<TrainingClassificationSection>
    with SingleTickerProviderStateMixin {
  ClassificationResult? _currentResult;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTraining) {
      return _buildIdleState();
    }

    // When training is active, show the stream results
    // The isTraining flag guarantees the engine is started
    return StreamBuilder<ClassificationResult>(
      stream: widget.classificationStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.hasData) {
          _currentResult = snapshot.data;
          _fadeAnimationController.forward(from: 0.0);
          return _buildClassificationDisplay(_currentResult!);
        }

        // Engine is running (isTraining=true), waiting for sound detection
        // This covers both ConnectionState.waiting and ConnectionState.active with no data
        return _buildWaitingForSoundState();
      },
    );
  }

  Widget _buildIdleState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Press Start to begin training',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForSoundState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Make a beatbox sound!',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Stream error: $error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationDisplay(ClassificationResult result) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSoundTypeDisplay(result),
            const SizedBox(height: 32),
            _buildTimingFeedbackDisplay(result),
            const SizedBox(height: 24),
            _buildConfidenceMeter(result),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundTypeDisplay(ClassificationResult result) {
    final soundColor = DisplayFormatters.getSoundColor(result.sound);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: soundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        result.sound.displayName,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTimingFeedbackDisplay(ClassificationResult result) {
    final timingColor = DisplayFormatters.getTimingColor(
      result.timing.classification,
    );

    final errorMs = result.timing.errorMs;
    final timingText = _formatTimingText(errorMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: timingColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: timingColor, width: 2),
      ),
      child: Text(
        timingText,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: timingColor,
        ),
      ),
    );
  }

  String _formatTimingText(double errorMs) {
    if (errorMs > 0) {
      return '${DisplayFormatters.formatTimingError(errorMs)} LATE';
    } else if (errorMs < 0) {
      return '${DisplayFormatters.formatTimingError(errorMs)} EARLY';
    } else {
      return '${DisplayFormatters.formatTimingError(errorMs)} ON-TIME';
    }
  }

  Widget _buildConfidenceMeter(ClassificationResult result) {
    final confidencePercentage = (result.confidence * 100).round();
    final confidenceColor = _getConfidenceColor(result.confidence);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfidenceHeader(confidencePercentage, confidenceColor),
          const SizedBox(height: 8),
          _buildConfidenceBar(result.confidence, confidenceColor),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) {
      return Colors.green;
    } else if (confidence >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildConfidenceHeader(int percentage, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Confidence',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: confidence,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 20,
      ),
    );
  }
}
