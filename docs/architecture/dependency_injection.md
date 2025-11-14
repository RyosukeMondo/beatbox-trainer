# Dependency Injection Pattern

## Overview

The Beatbox Trainer application uses **GetIt** as a service locator to implement dependency injection throughout the codebase. This pattern eliminates hardcoded dependencies, enables comprehensive testing with mocks, and enforces clear separation of concerns.

## Motivation

Prior to implementing the DI pattern, widgets instantiated services directly in their constructors using default parameter values:

```dart
// ❌ OLD: Hardcoded default instantiation (not testable)
class TrainingScreen extends StatefulWidget {
  final IAudioService audioService;

  const TrainingScreen({
    IAudioService? audioService,
  }) : audioService = audioService ?? AudioServiceImpl(); // ⚠️ Cannot mock in tests
}
```

This approach created **testability blockers**:
- Widget tests could not inject mock services
- Integration tests had side effects from real service instances
- No way to control service lifecycle for test isolation

## Core Concepts

### Service Locator Pattern

The service locator pattern centralizes service instantiation and resolution in a single registry (`GetIt`). Instead of creating dependencies directly, components request them from the locator:

```dart
// Production code
final audioService = getIt<IAudioService>();

// Test code
getIt.registerSingleton<IAudioService>(MockAudioService());
final audioService = getIt<IAudioService>(); // Returns mock
```

### Lazy Singleton Registration

Services are registered as **lazy singletons**, meaning:
1. **Lazy**: The service is only instantiated when first requested
2. **Singleton**: The same instance is reused for all subsequent requests

This ensures:
- Minimal startup overhead (services created on-demand)
- Consistent state across the application
- Proper resource management (single lifecycle)

## Implementation

### Service Locator Setup

The `setupServiceLocator()` function initializes the DI container during app startup:

**File**: `lib/di/service_locator.dart`

```dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator(GoRouter router) async {
  // Fail fast if already initialized
  if (getIt.isRegistered<IAudioService>()) {
    throw StateError('Service locator already initialized');
  }

  // Register services as lazy singletons
  getIt.registerLazySingleton<IAudioService>(
    () => AudioServiceImpl(errorHandler: getIt<ErrorHandler>()),
  );

  getIt.registerLazySingleton<IPermissionService>(
    () => PermissionServiceImpl(),
  );

  getIt.registerLazySingleton<ISettingsService>(
    () => SettingsServiceImpl(),
  );

  // ... other services

  getIt.registerLazySingleton<INavigationService>(
    () => GoRouterNavigationService(router),
  );
}
```

**Key Design Decisions**:

1. **Fail Fast on Double Initialization**: If `setupServiceLocator()` is called twice, it throws immediately rather than silently overwriting services
2. **Router Injection**: The GoRouter instance must be provided to register NavigationService
3. **Lazy Registration**: Services like `SettingsServiceImpl` with async initialization are registered but not initialized until first use

### Factory Constructor Pattern

Widgets use **factory constructors** to abstract service resolution:

**Production Factory** (`.create()`):
```dart
class TrainingScreen extends StatefulWidget {
  final IAudioService audioService;
  final IPermissionService permissionService;

  // Private constructor (cannot be called directly)
  const TrainingScreen._({
    required this.audioService,
    required this.permissionService,
  });

  // Production factory: resolves services from GetIt
  factory TrainingScreen.create() {
    return TrainingScreen._(
      audioService: getIt<IAudioService>(),
      permissionService: getIt<IPermissionService>(),
    );
  }

  // Test factory: accepts mock services directly
  factory TrainingScreen.test({
    required IAudioService audioService,
    required IPermissionService permissionService,
  }) {
    return TrainingScreen._(
      audioService: audioService,
      permissionService: permissionService,
    );
  }
}
```

**Benefits**:
- **Production**: Single source of truth for service resolution
- **Testing**: Full control over dependencies without affecting global state
- **Type Safety**: Constructor requires all dependencies (no nulls, no defaults)

### Application Initialization

The main entry point initializes the DI container before running the app:

**File**: `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create router configuration
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/training',
        builder: (context, state) => TrainingScreen.create(), // ✅ Uses factory
      ),
      // ... other routes
    ],
  );

  // Initialize DI container with router
  await setupServiceLocator(router);

  // Run the app
  runApp(MyApp(router: router));
}
```

**Initialization Order**:
1. Ensure Flutter bindings are initialized
2. Create GoRouter with route configuration
3. Register all services in GetIt (including router-dependent NavigationService)
4. Launch the app

## Testing Patterns

### Unit Test Setup

Unit tests register mock services in `setUp()` and clean up in `tearDown()`:

```dart
import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAudioService extends Mock implements IAudioService {}
class MockPermissionService extends Mock implements IPermissionService {}

void main() {
  late MockAudioService mockAudioService;
  late MockPermissionService mockPermissionService;

  setUp(() async {
    // Clean slate for each test
    await resetServiceLocator();

    // Register mocks
    mockAudioService = MockAudioService();
    mockPermissionService = MockPermissionService();

    getIt.registerSingleton<IAudioService>(mockAudioService);
    getIt.registerSingleton<IPermissionService>(mockPermissionService);
  });

  tearDown(() async {
    // Clean up after test
    await resetServiceLocator();
  });

  test('TrainingScreen starts audio on play button press', () async {
    // Arrange
    when(mockAudioService.startAudio(bpm: 120))
        .thenAnswer((_) async => {});

    final screen = TrainingScreen.create(); // Resolves mocks from GetIt

    // Act
    // ... trigger play button

    // Assert
    verify(mockAudioService.startAudio(bpm: 120)).called(1);
  });
}
```

### Widget Test Isolation

Widget tests bypass the service locator entirely using the `.test()` factory:

```dart
testWidgets('TrainingScreen displays BPM correctly', (tester) async {
  // Arrange
  final mockAudioService = MockAudioService();
  final mockPermissionService = MockPermissionService();

  // NO GetIt registration needed - inject directly
  await tester.pumpWidget(
    MaterialApp(
      home: TrainingScreen.test(
        audioService: mockAudioService,
        permissionService: mockPermissionService,
      ),
    ),
  );

  // Act & Assert
  expect(find.text('120 BPM'), findsOneWidget);
});
```

**Benefits**:
- No global state mutation (GetIt untouched)
- Tests run in complete isolation
- Faster test execution (no async setup/teardown)

### Service Locator Reset

The `resetServiceLocator()` function ensures test isolation:

```dart
Future<void> resetServiceLocator() async {
  // Dispose services that need cleanup
  if (getIt.isRegistered<IDebugService>()) {
    final debugService = getIt<IDebugService>() as DebugServiceImpl;
    debugService.dispose();
  }

  // Unregister all services
  await getIt.reset();
}
```

**When to Call**:
- In `tearDown()` of every test suite that registers services
- Before re-initializing services in integration tests
- When switching between test scenarios requiring different configurations

## Interface Segregation Example

The `DebugServiceImpl` demonstrates how a single implementation can satisfy multiple focused interfaces:

```dart
// Single implementation
final debugServiceInstance = DebugServiceImpl();

// Registered as four interfaces (Interface Segregation Principle)
getIt.registerSingleton<IDebugService>(debugServiceInstance);
getIt.registerSingleton<IAudioMetricsProvider>(debugServiceInstance);
getIt.registerSingleton<IOnsetEventProvider>(debugServiceInstance);
getIt.registerSingleton<ILogExporter>(debugServiceInstance);

// Components depend only on what they need
class MetricsScreen {
  final IAudioMetricsProvider metricsProvider;
  MetricsScreen({required this.metricsProvider});
}
```

**Benefits**:
- Components depend on minimal interface surface
- Same instance reused (memory efficient)
- Clear separation of concerns via focused interfaces

## Best Practices

### ✅ DO

- **Register interfaces, not implementations**: `getIt.registerLazySingleton<IAudioService>(...)`
- **Use factory constructors**: `.create()` for production, `.test()` for testing
- **Fail fast**: Validate services are registered before use
- **Clean up resources**: Call `dispose()` in `resetServiceLocator()`
- **Document dependencies**: Use dartdoc to explain what each service does

### ❌ DON'T

- **Don't use default parameters**: `IAudioService? audioService = AudioServiceImpl()` ❌
- **Don't access GetIt in widgets directly**: Use factory constructors instead
- **Don't register implementations as themselves**: `getIt.register<AudioServiceImpl>(...)` ❌
- **Don't skip teardown**: Always call `resetServiceLocator()` in tests
- **Don't initialize expensive services in `setupServiceLocator()`**: Use lazy registration

## Migration Guide

When refactoring a widget to use DI:

### Before (Hardcoded Default)
```dart
class MyScreen extends StatefulWidget {
  final IAudioService audioService;

  const MyScreen({
    IAudioService? audioService,
  }) : audioService = audioService ?? AudioServiceImpl();
}
```

### After (DI with Factories)
```dart
class MyScreen extends StatefulWidget {
  final IAudioService audioService;

  // Private constructor
  const MyScreen._({
    required this.audioService,
  });

  // Production factory
  factory MyScreen.create() => MyScreen._(
    audioService: getIt<IAudioService>(),
  );

  // Test factory
  factory MyScreen.test({
    required IAudioService audioService,
  }) => MyScreen._(
    audioService: audioService,
  );
}
```

### Update Router
```dart
// Before
GoRoute(path: '/my-screen', builder: (context, state) => const MyScreen()),

// After
GoRoute(path: '/my-screen', builder: (context, state) => MyScreen.create()),
```

## Related Documentation

- [Controller Pattern](./controllers.md) - Business logic extraction using DI
- [Manager Pattern](./managers.md) - Rust-side dependency composition
- [Testing Guide](../TESTING.md) - Comprehensive testing patterns
