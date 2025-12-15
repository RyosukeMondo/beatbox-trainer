import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';

void main() {
  group('ClassificationResult', () {
    test('fromJson parses valid JSON correctly', () {
      final json = {
        'sound': 'KICK',
        'timing': {
          'classification': 'onTime',
          'error_ms': 5.5,
        },
        'timestamp_ms': 12345,
        'confidence': 0.95,
      };

      final result = ClassificationResult.fromJson(json);

      expect(result.sound, BeatboxHit.kick);
      expect(result.timing.classification, TimingClassification.onTime);
      expect(result.timing.errorMs, 5.5);
      expect(result.timestampMs, 12345);
      expect(result.confidence, 0.95);
    });

    test('fromJson handles partial/missing JSON gracefully', () {
      final json = {
        'timing': {}, // Empty timing map
      };

      final result = ClassificationResult.fromJson(json);

      expect(result.sound, BeatboxHit.unknown); // Default
      expect(result.timing.classification, TimingClassification.onTime); // Default
      expect(result.timing.errorMs, 0.0); // Default
      expect(result.timestampMs, 0); // Default
      expect(result.confidence, 0.0); // Default
    });

    test('toJson serializes correctly', () {
      const result = ClassificationResult(
        sound: BeatboxHit.snare,
        timing: TimingFeedback(
          classification: TimingClassification.early,
          errorMs: -10.0,
        ),
        timestampMs: 67890,
        confidence: 0.8,
      );

      final json = result.toJson();

      expect(json['sound'], 'SNARE');
      expect(json['timing'], {'classification': 'early', 'error_ms': -10.0});
      expect(json['timestamp_ms'], 67890);
      expect(json['confidence'], 0.8);
    });

    test('toString returns expected format', () {
      const result = ClassificationResult(
        sound: BeatboxHit.hiHat,
        timing: TimingFeedback(
          classification: TimingClassification.late,
          errorMs: 20.0,
        ),
        timestampMs: 100,
        confidence: 1.0,
      );

      expect(
        result.toString(),
        contains('ClassificationResult(sound: BeatboxHit.hiHat'),
      );
      expect(result.toString(), contains('confidence: 1.0'));
    });
  });

  group('BeatboxHit', () {
    test('displayName returns correct strings', () {
      expect(BeatboxHit.kick.displayName, 'KICK');
      expect(BeatboxHit.snare.displayName, 'SNARE');
      expect(BeatboxHit.hiHat.displayName, 'HI-HAT');
      expect(BeatboxHit.closedHiHat.displayName, 'CLOSED HI-HAT');
      expect(BeatboxHit.openHiHat.displayName, 'OPEN HI-HAT');
      expect(BeatboxHit.kSnare.displayName, 'K-SNARE');
      expect(BeatboxHit.unknown.displayName, 'UNKNOWN');
    });
  });

  group('BeatboxHitParser', () {
    test('fromLabel parses case-insensitive labels', () {
      expect(BeatboxHitParser.fromLabel('kick'), BeatboxHit.kick);
      expect(BeatboxHitParser.fromLabel('KICK'), BeatboxHit.kick);
      expect(BeatboxHitParser.fromLabel('snare'), BeatboxHit.snare);
      expect(BeatboxHitParser.fromLabel('hi-hat'), BeatboxHit.hiHat);
      expect(BeatboxHitParser.fromLabel('hihat'), BeatboxHit.hiHat);
      expect(BeatboxHitParser.fromLabel('closed hi-hat'), BeatboxHit.closedHiHat);
      expect(BeatboxHitParser.fromLabel('open hi-hat'), BeatboxHit.openHiHat);
      expect(BeatboxHitParser.fromLabel('k-snare'), BeatboxHit.kSnare);
      expect(BeatboxHitParser.fromLabel('unknown_value'), BeatboxHit.unknown);
    });
  });
}
