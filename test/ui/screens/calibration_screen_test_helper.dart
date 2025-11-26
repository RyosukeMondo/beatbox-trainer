import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beatbox_trainer/controllers/calibration/calibration_controller.dart';
import 'package:beatbox_trainer/models/calibration_progress.dart';
import 'package:beatbox_trainer/ui/screens/calibration_screen.dart';
import '../../mocks.dart';

/// Helper class for CalibrationScreen widget tests
/// Provides shared setup code and utilities to reduce duplication
class CalibrationScreenTestHelper {
  late MockAudioService mockAudioService;
  late MockStorageService mockStorageService;
  late StreamController<CalibrationProgress> calibrationStreamController;

  /// Setup mocks with default behavior
  void setUp() {
    mockAudioService = MockAudioService();
    mockStorageService = MockStorageService();
    calibrationStreamController = StreamController<CalibrationProgress>();

    // Mock storage service init() by default
    when(() => mockStorageService.init()).thenAnswer((_) async {});

    // Mock finishCalibration() to prevent dispose errors
    when(() => mockAudioService.finishCalibration()).thenAnswer((_) async {});

    // Mock storage save to prevent errors
    when(
      () => mockStorageService.saveCalibration(any()),
    ).thenAnswer((_) async {});

    // Default manual accept fallback
    when(() => mockAudioService.manualAcceptLastCandidate()).thenAnswer(
      (_) async => const CalibrationProgress(
        currentSound: CalibrationSound.kick,
        samplesCollected: 1,
        samplesNeeded: 10,
      ),
    );
  }

  /// Clean up resources
  void tearDown() {
    calibrationStreamController.close();
  }

  /// Helper function to pump CalibrationScreen with mock dependencies
  Future<void> pumpCalibrationScreen(WidgetTester tester) async {
    // Set larger viewport to prevent overflow errors
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    // Create controller with mock services
    final controller = CalibrationController(
      audioService: mockAudioService,
      storageService: mockStorageService,
    );

    await tester.pumpWidget(
      MaterialApp(home: CalibrationScreen.test(controller: controller)),
    );

    addTearDown(() {
      // Reset to default after test
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
