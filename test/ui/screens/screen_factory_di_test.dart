import 'package:beatbox_trainer/di/service_locator.dart';
import 'package:beatbox_trainer/models/calibration_progress.dart';
import 'package:beatbox_trainer/models/classification_result.dart';
import 'package:beatbox_trainer/services/audio/i_audio_service.dart';
import 'package:beatbox_trainer/services/debug/i_debug_service.dart';
import 'package:beatbox_trainer/services/permission/i_permission_service.dart';
import 'package:beatbox_trainer/services/settings/i_settings_service.dart';
import 'package:beatbox_trainer/services/storage/i_storage_service.dart';
import 'package:beatbox_trainer/ui/screens/calibration_screen.dart';
import 'package:beatbox_trainer/ui/screens/settings_screen.dart';
import 'package:beatbox_trainer/ui/screens/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetServiceLocator();
  });

  tearDown(() async {
    await resetServiceLocator();
  });

  group('Screen factories resolve mocks from service locator', () {
    testWidgets('TrainingScreen.create pulls services from GetIt', (
      WidgetTester tester,
    ) async {
      final mockAudioService = MockAudioService();
      final mockPermissionService = MockPermissionService();
      final mockSettingsService = MockSettingsService();
      final mockDebugService = MockDebugService();

      when(
        () => mockSettingsService.getDebugMode(),
      ).thenAnswer((_) async => false);
      when(
        () => mockAudioService.getClassificationStream(),
      ).thenAnswer((_) => Stream<ClassificationResult>.empty());

      getIt.registerSingleton<IAudioService>(mockAudioService);
      getIt.registerSingleton<IPermissionService>(mockPermissionService);
      getIt.registerSingleton<ISettingsService>(mockSettingsService);
      getIt.registerSingleton<IDebugService>(mockDebugService);

      await tester.pumpWidget(MaterialApp(home: TrainingScreen.create()));
      await tester.pumpAndSettle();

      expect(find.text('Beatbox Trainer'), findsOneWidget);
      verify(() => mockSettingsService.getDebugMode()).called(1);
    });

    testWidgets('CalibrationScreen.create resolves storage and audio mocks', (
      WidgetTester tester,
    ) async {
      final mockAudioService = MockAudioService();
      final mockStorageService = MockStorageService();

      when(() => mockStorageService.init()).thenAnswer((_) async {});
      when(() => mockAudioService.startCalibration()).thenAnswer((_) async {});
      when(() => mockAudioService.finishCalibration()).thenAnswer((_) async {});
      when(
        () => mockAudioService.getCalibrationStream(),
      ).thenAnswer((_) => Stream<CalibrationProgress>.empty());

      getIt.registerSingleton<IAudioService>(mockAudioService);
      getIt.registerSingleton<IStorageService>(mockStorageService);

      await tester.pumpWidget(MaterialApp(home: CalibrationScreen.create()));
      await tester.pump();

      expect(find.text('Calibration'), findsOneWidget);
      verify(() => mockStorageService.init()).called(1);
      verify(() => mockAudioService.startCalibration()).called(1);
    });

    testWidgets('SettingsScreen.create loads settings from locator mocks', (
      WidgetTester tester,
    ) async {
      final mockSettingsService = MockSettingsService();
      final mockStorageService = MockStorageService();

      when(() => mockSettingsService.init()).thenAnswer((_) async {});
      when(() => mockStorageService.init()).thenAnswer((_) async {});
      when(() => mockSettingsService.getBpm()).thenAnswer((_) async => 120);
      when(
        () => mockSettingsService.getDebugMode(),
      ).thenAnswer((_) async => false);
      when(
        () => mockSettingsService.getClassifierLevel(),
      ).thenAnswer((_) async => 1);

      getIt.registerSingleton<ISettingsService>(mockSettingsService);
      getIt.registerSingleton<IStorageService>(mockStorageService);

      await tester.pumpWidget(MaterialApp(home: SettingsScreen.create()));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      verify(() => mockSettingsService.getBpm()).called(1);
      verify(() => mockSettingsService.getDebugMode()).called(1);
      verify(() => mockSettingsService.getClassifierLevel()).called(1);
    });
  });
}
