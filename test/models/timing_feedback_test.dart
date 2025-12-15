import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';

void main() {
  group('TimingFeedback', () {
    test('fromJson parses valid JSON correctly', () {
      final json = {
        'classification': 'late',
        'error_ms': 25.5,
      };

      final result = TimingFeedback.fromJson(json);

      expect(result.classification, TimingClassification.late);
      expect(result.errorMs, 25.5);
    });

    test('fromJson handles partial/missing JSON gracefully', () {
      final json = <String, dynamic>{};

      final result = TimingFeedback.fromJson(json);

      expect(result.classification, TimingClassification.onTime); // Default
      expect(result.errorMs, 0.0); // Default
    });

    test('toJson serializes correctly', () {
      const result = TimingFeedback(
        classification: TimingClassification.early,
        errorMs: -15.0,
      );

      final json = result.toJson();

      expect(json['classification'], 'early');
      expect(json['error_ms'], -15.0);
    });

    test('formattedError returns correct strings', () {
      expect(
        const TimingFeedback(
          classification: TimingClassification.onTime,
          errorMs: 0.0,
        ).formattedError,
        '0.0ms',
      );
      expect(
        const TimingFeedback(
          classification: TimingClassification.late,
          errorMs: 12.34,
        ).formattedError,
        '+12.3ms',
      );
      expect(
        const TimingFeedback(
          classification: TimingClassification.early,
          errorMs: -5.67,
        ).formattedError,
        '-5.7ms',
      );
    });

    test('toString returns expected format', () {
      const result = TimingFeedback(
        classification: TimingClassification.onTime,
        errorMs: 0.0,
      );

      expect(
        result.toString(),
        'TimingFeedback(classification: TimingClassification.onTime, errorMs: 0.0)',
      );
    });
  });

  group('TimingClassification', () {
    test('displayName returns correct strings', () {
      expect(TimingClassification.onTime.displayName, 'ON-TIME');
      expect(TimingClassification.early.displayName, 'EARLY');
      expect(TimingClassification.late.displayName, 'LATE');
    });
  });

  group('TimingClassificationParser', () {
    test('fromLabel parses case-insensitive labels', () {
      expect(TimingClassificationParser.fromLabel('on_time'), TimingClassification.onTime);
      expect(TimingClassificationParser.fromLabel('ontime'), TimingClassification.onTime);
      expect(TimingClassificationParser.fromLabel('early'), TimingClassification.early);
      expect(TimingClassificationParser.fromLabel('late'), TimingClassification.late);
      expect(TimingClassificationParser.fromLabel('unknown'), TimingClassification.onTime);
    });
  });
}
