import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/ui/screens/calibration_screen.dart';
import '../../mocks.dart';

/// Helper class for CalibrationScreen widget tests
/// Provides shared setup code and utilities to reduce duplication
class CalibrationScreenTestHelper {
  late MockAudioService mockAudioService;
  late MockStorageService mockStorageService;

  /// Setup mocks with default behavior
  void setUp() {
    mockAudioService = MockAudioService();
    mockStorageService = MockStorageService();

    // Mock storage service init() by default
    when(() => mockStorageService.init()).thenAnswer((_) async {});

    // Mock finishCalibration() to prevent dispose errors
    when(() => mockAudioService.finishCalibration()).thenAnswer((_) async {});
  }

  /// Helper function to pump CalibrationScreen with mock dependencies
  Future<void> pumpCalibrationScreen(WidgetTester tester) async {
    // Set larger viewport to prevent overflow errors
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: CalibrationScreen.test(
          audioService: mockAudioService,
          storageService: mockStorageService,
        ),
      ),
    );

    addTearDown(() {
      // Reset to default after test
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
