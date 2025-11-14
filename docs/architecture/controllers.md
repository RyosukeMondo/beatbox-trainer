# Controller Pattern in Flutter

## Overview

The Controller Pattern separates business logic from UI rendering by extracting stateful logic into dedicated controller classes. This architectural pattern improves testability, reduces widget complexity, and enforces single responsibility.

## Motivation

Prior to implementing the Controller Pattern, business logic was embedded directly in widget `State` classes:

```dart
// ❌ BEFORE: Mixed concerns (UI + business logic)
class _TrainingScreenState extends State<TrainingScreen> {
  final IAudioService _audioService = AudioServiceImpl();
  final IPermissionService _permissionService = PermissionServiceImpl();
  bool _isTraining = false;
  int _currentBpm = 120;

  // Business logic mixed with UI state
  Future<void> _startTraining() async {
    // Permission handling
    final hasPermission = await _requestPermission();
    if (!hasPermission) return;

    // BPM loading
    _currentBpm = await _settingsService.getBpm();

    // Audio lifecycle
    await _audioService.startAudio(bpm: _currentBpm);
    setState(() => _isTraining = true);
  }

  // More business logic...
  Future<void> _updateBpm(int newBpm) async { /* ... */ }

  @override
  Widget build(BuildContext context) {
    // UI rendering mixed with business logic
    return /* ... */;
  }
}
```

**Problems**:
- **Hard to test**: Widget tests require full widget tree to test business logic
- **Mixed concerns**: Business logic and UI rendering in the same class
- **Violates SRP**: State class responsible for both UI and business logic
- **High complexity**: Widget files often > 500 lines with embedded logic

## Core Concepts

### Model-View-Controller (MVC) Architecture

The controller acts as the intermediary between the view (UI) and the model (services):

```
┌─────────────────────────────────────────────────────────┐
│ View (TrainingScreen)                                   │
│ - Displays UI                                           │
│ - Handles user input events                             │
│ - Subscribes to controller streams                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Controller (TrainingController)                         │
│ - Business logic (permissions, BPM validation)          │
│ - State management (isTraining, currentBpm)             │
│ - Service orchestration (audio, settings, permissions)  │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Model (Services)                                        │
│ - IAudioService: Audio engine control                   │
│ - IPermissionService: Permission requests               │
│ - ISettingsService: Settings persistence                │
└─────────────────────────────────────────────────────────┘
```

### Single Responsibility Principle (SRP)

Each component has exactly one responsibility:

| Component | Responsibility |
|-----------|---------------|
| **View** (TrainingScreen) | Render UI, handle user interactions |
| **Controller** (TrainingController) | Business logic, state management |
| **Model** (Services) | Data access, platform APIs |

## Implementation

### Controller Class

**File**: `lib/controllers/training/training_controller.dart`

```dart
/// Training screen business logic controller.
///
/// Handles audio lifecycle, BPM updates, permission requests, and state management.
/// Decoupled from UI for independent testing.
class TrainingController {
  final IAudioService _audioService;
  final IPermissionService _permissionService;
  final ISettingsService _settingsService;

  bool _isTraining = false;
  int _currentBpm = 120;

  /// Creates a new TrainingController with required service dependencies.
  TrainingController({
    required IAudioService audioService,
    required IPermissionService permissionService,
    required ISettingsService settingsService,
  }) : _audioService = audioService,
       _permissionService = permissionService,
       _settingsService = settingsService;

  /// Current training state (read-only)
  bool get isTraining => _isTraining;

  /// Current BPM value (read-only)
  int get currentBpm => _currentBpm;

  /// Classification result stream (read-only)
  Stream<ClassificationResult> get classificationStream =>
      _audioService.getClassificationStream();

  /// Start training session.
  ///
  /// Orchestrates:
  /// 1. Microphone permission request
  /// 2. BPM loading from settings
  /// 3. Audio engine startup
  ///
  /// Throws [PermissionException] if microphone permission denied.
  /// Throws [AudioServiceException] if audio engine fails to start.
  Future<void> startTraining() async {
    if (_isTraining) {
      throw StateError('Training already in progress');
    }

    // Request permission
    final hasPermission = await _requestMicrophonePermission();
    if (!hasPermission) {
      throw PermissionException('Microphone permission denied');
    }

    // Load BPM
    _currentBpm = await _settingsService.getBpm();

    // Start audio
    await _audioService.startAudio(bpm: _currentBpm);
    _isTraining = true;
  }

  /// Stop training session.
  Future<void> stopTraining() async {
    if (!_isTraining) return;

    await _audioService.stopAudio();
    _isTraining = false;
  }

  /// Update BPM during training.
  ///
  /// Validates range (40-240), updates audio engine if running,
  /// and persists to settings.
  ///
  /// Throws [ArgumentError] if BPM outside valid range.
  Future<void> updateBpm(int newBpm) async {
    if (newBpm < 40 || newBpm > 240) {
      throw ArgumentError('BPM must be between 40 and 240');
    }

    if (_isTraining) {
      await _audioService.setBpm(bpm: newBpm);
    }

    _currentBpm = newBpm;
    await _settingsService.setBpm(newBpm);
  }

  /// Private helper: request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    final status = await _permissionService.checkMicrophonePermission();

    if (status == PermissionStatus.granted) return true;

    if (status == PermissionStatus.denied) {
      final newStatus = await _permissionService.requestMicrophonePermission();
      return newStatus == PermissionStatus.granted;
    }

    if (status == PermissionStatus.permanentlyDenied) {
      await _permissionService.openAppSettings();
      return false;
    }

    return false;
  }

  /// Dispose resources (stop training if active)
  Future<void> dispose() async {
    if (_isTraining) await stopTraining();
  }
}
```

**Design Highlights**:

1. **Constructor Injection**: All dependencies injected via constructor (no defaults)
2. **Read-only State**: Public getters expose state; only controller mutates it
3. **Stream Delegation**: Exposes service streams without coupling UI to services
4. **Validation**: Business rules enforced in controller (BPM range 40-240)
5. **Error Handling**: Throws typed exceptions (`PermissionException`, `ArgumentError`)

### View Integration

**File**: `lib/ui/screens/training_screen.dart`

```dart
class TrainingScreen extends StatefulWidget {
  final TrainingController controller;
  final IDebugService debugService;

  // Private constructor (enforce factory usage)
  const TrainingScreen._({
    required this.controller,
    required this.debugService,
  });

  /// Production factory: creates controller from GetIt services
  factory TrainingScreen.create({Key? key}) {
    return TrainingScreen._(
      key: key,
      controller: TrainingController(
        audioService: getIt<IAudioService>(),
        permissionService: getIt<IPermissionService>(),
        settingsService: getIt<ISettingsService>(),
      ),
      debugService: getIt<IDebugService>(),
    );
  }

  /// Test factory: accepts mock controller for widget tests
  @visibleForTesting
  factory TrainingScreen.test({
    required TrainingController controller,
    required IDebugService debugService,
  }) {
    return TrainingScreen._(
      controller: controller,
      debugService: debugService,
    );
  }

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  ClassificationResult? _currentResult;
  bool _debugModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadDebugSettings();
    _subscribeToClassifications();
  }

  /// Subscribe to controller's classification stream
  void _subscribeToClassifications() {
    widget.controller.classificationStream.listen(
      (result) {
        if (mounted) {
          setState(() => _currentResult = result);
        }
      },
      onError: (error) {
        _showErrorDialog('Classification error: $error');
      },
    );
  }

  /// Handle play button press (delegate to controller)
  Future<void> _handlePlayPress() async {
    try {
      await widget.controller.startTraining();
      if (mounted) setState(() {});
    } on PermissionException catch (e) {
      _showErrorDialog(e.message);
    } on AudioServiceException catch (e) {
      _showErrorDialog('Audio error: ${e.message}');
    }
  }

  /// Handle stop button press (delegate to controller)
  Future<void> _handleStopPress() async {
    await widget.controller.stopTraining();
    if (mounted) setState(() {});
  }

  /// Handle BPM slider change (delegate to controller)
  Future<void> _handleBpmChange(int newBpm) async {
    try {
      await widget.controller.updateBpm(newBpm);
      if (mounted) setState(() {});
    } on ArgumentError catch (e) {
      _showErrorDialog(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI rendering ONLY - no business logic
    return Scaffold(
      appBar: AppBar(title: const Text('Training')),
      body: Column(
        children: [
          // BPM slider
          Slider(
            value: widget.controller.currentBpm.toDouble(),
            min: 40,
            max: 240,
            onChanged: (value) => _handleBpmChange(value.toInt()),
          ),

          // Play/Stop button
          ElevatedButton(
            onPressed: widget.controller.isTraining
                ? _handleStopPress
                : _handlePlayPress,
            child: Text(widget.controller.isTraining ? 'Stop' : 'Play'),
          ),

          // Classification result display
          if (_currentResult != null)
            Text('Result: ${_currentResult!.soundType}'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }
}
```

**Key Patterns**:

1. **No Business Logic**: Widget only renders UI and delegates to controller
2. **Stream Subscription**: UI subscribes to controller streams for state updates
3. **Event Delegation**: Button presses call controller methods
4. **Error Handling**: UI catches typed exceptions from controller and displays dialogs

### Router Configuration

**File**: `lib/main.dart`

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/training',
      builder: (context, state) => TrainingScreen.create(), // ✅ Uses factory
    ),
    // ... other routes
  ],
);
```

## Testing Patterns

### Unit Testing the Controller

Controllers can be tested in complete isolation without widgets:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockAudioService extends Mock implements IAudioService {}
class MockPermissionService extends Mock implements IPermissionService {}
class MockSettingsService extends Mock implements ISettingsService {}

void main() {
  late TrainingController controller;
  late MockAudioService mockAudio;
  late MockPermissionService mockPermission;
  late MockSettingsService mockSettings;

  setUp(() {
    mockAudio = MockAudioService();
    mockPermission = MockPermissionService();
    mockSettings = MockSettingsService();

    controller = TrainingController(
      audioService: mockAudio,
      permissionService: mockPermission,
      settingsService: mockSettings,
    );
  });

  group('startTraining', () {
    test('requests permission and starts audio', () async {
      // Arrange
      when(mockPermission.checkMicrophonePermission())
          .thenAnswer((_) async => PermissionStatus.granted);
      when(mockSettings.getBpm()).thenAnswer((_) async => 120);
      when(mockAudio.startAudio(bpm: 120)).thenAnswer((_) async {});

      // Act
      await controller.startTraining();

      // Assert
      expect(controller.isTraining, true);
      expect(controller.currentBpm, 120);
      verify(mockAudio.startAudio(bpm: 120)).called(1);
    });

    test('throws PermissionException when permission denied', () async {
      // Arrange
      when(mockPermission.checkMicrophonePermission())
          .thenAnswer((_) async => PermissionStatus.denied);
      when(mockPermission.requestMicrophonePermission())
          .thenAnswer((_) async => PermissionStatus.denied);

      // Act & Assert
      expect(
        () => controller.startTraining(),
        throwsA(isA<PermissionException>()),
      );
      expect(controller.isTraining, false);
    });
  });

  group('updateBpm', () {
    test('validates BPM range', () async {
      // Act & Assert
      expect(() => controller.updateBpm(30), throwsArgumentError);
      expect(() => controller.updateBpm(250), throwsArgumentError);
    });

    test('updates audio engine when training', () async {
      // Arrange
      when(mockPermission.checkMicrophonePermission())
          .thenAnswer((_) async => PermissionStatus.granted);
      when(mockSettings.getBpm()).thenAnswer((_) async => 120);
      when(mockAudio.startAudio(bpm: any)).thenAnswer((_) async {});
      when(mockAudio.setBpm(bpm: any)).thenAnswer((_) async {});
      when(mockSettings.setBpm(any)).thenAnswer((_) async {});

      await controller.startTraining();

      // Act
      await controller.updateBpm(140);

      // Assert
      expect(controller.currentBpm, 140);
      verify(mockAudio.setBpm(bpm: 140)).called(1);
      verify(mockSettings.setBpm(140)).called(1);
    });
  });
}
```

**Benefits**:
- **Fast**: No widget rendering overhead
- **Focused**: Test business logic independently
- **Isolated**: Full control over service behavior via mocks

### Widget Testing with Controller

Widget tests use the `.test()` factory to inject a real or mock controller:

```dart
testWidgets('displays current BPM from controller', (tester) async {
  // Arrange
  final mockAudio = MockAudioService();
  final mockPermission = MockPermissionService();
  final mockSettings = MockSettingsService();

  final controller = TrainingController(
    audioService: mockAudio,
    permissionService: mockPermission,
    settingsService: mockSettings,
  );

  final mockDebug = MockDebugService();

  // Act
  await tester.pumpWidget(
    MaterialApp(
      home: TrainingScreen.test(
        controller: controller,
        debugService: mockDebug,
      ),
    ),
  );

  // Assert
  expect(find.text('120 BPM'), findsOneWidget);
  expect(controller.currentBpm, 120);
});

testWidgets('calls controller.startTraining on play button press', (tester) async {
  // Arrange
  final mockController = MockTrainingController();
  final mockDebug = MockDebugService();

  when(mockController.isTraining).thenReturn(false);
  when(mockController.currentBpm).thenReturn(120);
  when(mockController.startTraining()).thenAnswer((_) async {});

  await tester.pumpWidget(
    MaterialApp(
      home: TrainingScreen.test(
        controller: mockController,
        debugService: mockDebug,
      ),
    ),
  );

  // Act
  await tester.tap(find.text('Play'));
  await tester.pump();

  // Assert
  verify(mockController.startTraining()).called(1);
});
```

**Benefits**:
- **UI-focused**: Test only widget rendering and event handling
- **Mock controller**: Full control over controller behavior
- **No service setup**: Controller mocked, no need to mock services

## Best Practices

### ✅ DO

- **Extract business logic**: Move all non-UI logic to controllers
- **Inject dependencies**: Pass services via controller constructor
- **Return typed errors**: Throw specific exceptions (`PermissionException`, `ArgumentError`)
- **Expose read-only state**: Use getters for controller state
- **Delegate streams**: Controller exposes service streams to UI
- **Validate inputs**: Enforce business rules in controller methods
- **Test independently**: Write unit tests for controllers without widgets

### ❌ DON'T

- **Don't access services in widgets**: Widget should only know about controller
- **Don't mutate controller state from UI**: UI calls controller methods only
- **Don't put UI logic in controller**: No `BuildContext`, no widgets
- **Don't skip validation**: Always validate inputs (BPM range, null checks)
- **Don't use setState in controller**: Controllers are not widgets
- **Don't mix concerns**: Keep UI rendering and business logic separate

## Controller Lifecycle

### Creation (Production)

```dart
// Created in factory constructor
factory TrainingScreen.create() {
  return TrainingScreen._(
    controller: TrainingController(
      audioService: getIt<IAudioService>(),
      permissionService: getIt<IPermissionService>(),
      settingsService: getIt<ISettingsService>(),
    ),
    debugService: getIt<IDebugService>(),
  );
}
```

### Disposal

```dart
// Widget disposes controller
@override
void dispose() {
  widget.controller.dispose(); // Stops training if active
  super.dispose();
}

// Controller cleanup
Future<void> dispose() async {
  if (_isTraining) {
    await stopTraining();
  }
}
```

## State Management Patterns

### Reactive State (Streams)

Controller exposes streams for reactive UI updates:

```dart
// Controller
Stream<ClassificationResult> get classificationStream =>
    _audioService.getClassificationStream();

// UI subscribes
@override
void initState() {
  super.initState();
  widget.controller.classificationStream.listen(
    (result) {
      if (mounted) setState(() => _currentResult = result);
    },
  );
}
```

### Synchronous State (Getters)

Controller exposes simple state via getters:

```dart
// Controller
bool get isTraining => _isTraining;
int get currentBpm => _currentBpm;

// UI reads directly
Text(widget.controller.isTraining ? 'Training...' : 'Idle')
```

### State Mutation (Methods)

UI triggers state changes via controller methods:

```dart
// UI
await widget.controller.startTraining();
if (mounted) setState(() {}); // Rebuild with new controller state

// Controller
Future<void> startTraining() async {
  // ... business logic ...
  _isTraining = true; // Mutate internal state
}
```

## Migration Guide

When extracting a controller from an existing widget:

### Step 1: Identify Business Logic

Find methods that contain business logic (not UI rendering):
- Permission handling
- Service calls (audio, settings, storage)
- Validation (BPM range, data validation)
- State mutations (isTraining, currentBpm)

### Step 2: Create Controller Class

```dart
class TrainingController {
  final IAudioService _audioService;
  final IPermissionService _permissionService;

  TrainingController({
    required IAudioService audioService,
    required IPermissionService permissionService,
  }) : _audioService = audioService,
       _permissionService = permissionService;
}
```

### Step 3: Move Business Logic

Cut methods from `_WidgetState`, paste into controller:

```dart
// Before (in _TrainingScreenState)
Future<void> _startTraining() async { /* ... */ }

// After (in TrainingController)
Future<void> startTraining() async { /* ... */ }
```

### Step 4: Add Getters for State

Expose state via read-only getters:

```dart
class TrainingController {
  bool _isTraining = false;

  bool get isTraining => _isTraining; // Read-only
}
```

### Step 5: Update Widget

Inject controller and delegate to it:

```dart
class TrainingScreen extends StatefulWidget {
  final TrainingController controller;

  factory TrainingScreen.create() => TrainingScreen._(
    controller: TrainingController(
      audioService: getIt<IAudioService>(),
      permissionService: getIt<IPermissionService>(),
    ),
  );
}

class _TrainingScreenState extends State<TrainingScreen> {
  Future<void> _handlePlayPress() async {
    await widget.controller.startTraining(); // Delegate
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _handlePlayPress,
      child: Text(widget.controller.isTraining ? 'Stop' : 'Play'),
    );
  }
}
```

### Step 6: Write Tests

Test controller in isolation:

```dart
test('startTraining sets isTraining to true', () async {
  final controller = TrainingController(
    audioService: mockAudio,
    permissionService: mockPermission,
  );

  await controller.startTraining();

  expect(controller.isTraining, true);
});
```

## Related Documentation

- [Dependency Injection Pattern](./dependency_injection.md) - Service injection in controllers
- [Manager Pattern](./managers.md) - Rust-side business logic separation
- [Testing Guide](../TESTING.md) - Comprehensive testing patterns
