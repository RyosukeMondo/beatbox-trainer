import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beatbox_trainer/ui/utils/display_formatters.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/models/timing_feedback.dart';

void main() {
  group('DisplayFormatters', () {
    group('formatBpm', () {
      test('formats minimum BPM correctly', () {
        expect(DisplayFormatters.formatBpm(40), equals('40 BPM'));
      });

      test('formats maximum BPM correctly', () {
        expect(DisplayFormatters.formatBpm(240), equals('240 BPM'));
      });

      test('formats typical BPM correctly', () {
        expect(DisplayFormatters.formatBpm(120), equals('120 BPM'));
      });

      test('formats low BPM correctly', () {
        expect(DisplayFormatters.formatBpm(60), equals('60 BPM'));
      });

      test('formats high BPM correctly', () {
        expect(DisplayFormatters.formatBpm(180), equals('180 BPM'));
      });
    });

    group('formatTimingError', () {
      test('formats zero error correctly', () {
        expect(DisplayFormatters.formatTimingError(0.0), equals('0.0ms'));
      });

      test('formats positive error (late) with plus sign', () {
        expect(DisplayFormatters.formatTimingError(12.5), equals('+12.5ms'));
      });

      test('formats negative error (early) with minus sign', () {
        expect(DisplayFormatters.formatTimingError(-5.0), equals('-5.0ms'));
      });

      test('formats small positive error correctly', () {
        expect(DisplayFormatters.formatTimingError(0.1), equals('+0.1ms'));
      });

      test('formats small negative error correctly', () {
        expect(DisplayFormatters.formatTimingError(-0.1), equals('-0.1ms'));
      });

      test('formats large positive error correctly', () {
        expect(DisplayFormatters.formatTimingError(99.9), equals('+99.9ms'));
      });

      test('formats large negative error correctly', () {
        expect(DisplayFormatters.formatTimingError(-99.9), equals('-99.9ms'));
      });

      test('rounds to one decimal place', () {
        expect(DisplayFormatters.formatTimingError(12.56), equals('+12.6ms'));
        expect(DisplayFormatters.formatTimingError(-7.34), equals('-7.3ms'));
      });
    });

    group('getSoundColor', () {
      test('returns red for kick', () {
        expect(
          DisplayFormatters.getSoundColor(BeatboxHit.kick),
          equals(Colors.red),
        );
      });

      test('returns blue for snare', () {
        expect(
          DisplayFormatters.getSoundColor(BeatboxHit.snare),
          equals(Colors.blue),
        );
      });

      test('returns green for generic hi-hat', () {
        expect(
          DisplayFormatters.getSoundColor(BeatboxHit.hiHat),
          equals(Colors.green),
        );
      });

      test('returns green for closed hi-hat', () {
        expect(
          DisplayFormatters.getSoundColor(BeatboxHit.closedHiHat),
          equals(Colors.green),
        );
      });

      test('returns green for open hi-hat', () {
        expect(
          DisplayFormatters.getSoundColor(BeatboxHit.openHiHat),
          equals(Colors.green),
        );
      });

      test('returns purple for k-snare', () {
        expect(
          DisplayFormatters.getSoundColor(BeatboxHit.kSnare),
          equals(Colors.purple),
        );
      });

      test('returns grey for unknown', () {
        expect(
          DisplayFormatters.getSoundColor(BeatboxHit.unknown),
          equals(Colors.grey),
        );
      });

      test('all BeatboxHit enum values have color mapping', () {
        // Ensure all enum values are covered
        for (final sound in BeatboxHit.values) {
          expect(
            () => DisplayFormatters.getSoundColor(sound),
            returnsNormally,
            reason: 'Missing color mapping for $sound',
          );
        }
      });
    });

    group('getTimingColor', () {
      test('returns green for on-time', () {
        expect(
          DisplayFormatters.getTimingColor(TimingClassification.onTime),
          equals(Colors.green),
        );
      });

      test('returns amber for early', () {
        expect(
          DisplayFormatters.getTimingColor(TimingClassification.early),
          equals(Colors.amber),
        );
      });

      test('returns amber for late', () {
        expect(
          DisplayFormatters.getTimingColor(TimingClassification.late),
          equals(Colors.amber),
        );
      });

      test('all TimingClassification enum values have color mapping', () {
        // Ensure all enum values are covered
        for (final classification in TimingClassification.values) {
          expect(
            () => DisplayFormatters.getTimingColor(classification),
            returnsNormally,
            reason: 'Missing color mapping for $classification',
          );
        }
      });
    });

    group('DisplayFormatters class', () {
      test('cannot be instantiated (private constructor)', () {
        // This test verifies that DisplayFormatters has a private constructor
        // by attempting to use reflection, but Dart doesn't allow instantiation
        // of classes with private constructors at compile time.
        // This test just documents the expected behavior.
        expect(DisplayFormatters, isNotNull);
      });

      test('all methods are static', () {
        // Verify we can call methods without instantiation
        expect(() => DisplayFormatters.formatBpm(120), returnsNormally);
        expect(() => DisplayFormatters.formatTimingError(0.0), returnsNormally);
        expect(
          () => DisplayFormatters.getSoundColor(BeatboxHit.kick),
          returnsNormally,
        );
        expect(
          () => DisplayFormatters.getTimingColor(TimingClassification.onTime),
          returnsNormally,
        );
      });
    });
  });
}
