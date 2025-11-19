import 'package:beatbox_trainer/services/audio/test_harness/harness_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HarnessAudioSource', () {
    test('converts fixture file sources to request payload', () {
      const source = FixtureFileHarnessAudioSource(
        path: 'rust/fixtures/basic.wav',
        id: 'kick_fixture',
        loopCount: 2,
      );

      final request = source.toRequest();

      expect(request.id, 'kick_fixture');
      expect(request.loopCount, 2);
      expect(request.source.toJson()['path'], 'rust/fixtures/basic.wav');
    });

    test('serializes synthetic sources', () {
      const source = SyntheticPatternHarnessAudioSource(
        pattern: SyntheticFixturePattern.impulseTrain,
        frequencyHz: 100.0,
        amplitude: 0.5,
      );

      final payload = source.toRequest().source.toJson();

      expect(payload['pattern'], 'impulseTrain');
      expect(payload['frequency_hz'], 100.0);
      expect(payload['amplitude'], 0.5);
    });

    test('marks microphone proxy as non-fixture', () {
      const source = MicrophoneProxyHarnessAudioSource();

      expect(source.requiresFixtureSession, isFalse);
      expect(
        source.toRequest().source.toJson()['kind'],
        'microphone_passthrough',
      );
    });
  });
}
