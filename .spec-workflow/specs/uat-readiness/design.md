# Design: UAT Readiness for Beatbox Trainer

## Overview
Technical design for implementing all UAT readiness requirements, including calibration onboarding, real-time feedback enhancements, debug mode, classifier level selection, automated testing, and UAT documentation.

## Architecture Principles

### Existing Patterns (Maintain Consistency)
1. **Dependency Injection**: Constructor-based with optional parameters and default implementations
2. **State Management**: StatefulWidget with local state + StreamBuilder for Rust streams
3. **Error Handling**: Three-layer strategy (Rust typed errors → Service translation → UI-friendly messages)
4. **Service Layer**: Interface-implementation pattern with mockable dependencies
5. **FFI Communication**: flutter_rust_bridge with Tokio-backed stream forwarding

### New Patterns (For UAT Features)
1. **Navigation**: Add go_router for Settings/Debug/Calibration screens
2. **Persistence**: shared_preferences for calibration data and settings
3. **Debug Overlay**: Stack-based overlay with real-time metrics
4. **Test Infrastructure**: Mocktail-based unit/widget tests with 80%+ coverage

## System Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter UI Layer                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐  │
│  │ Training     │  │ Calibration  │  │ Settings            │  │
│  │ Screen       │  │ Screen       │  │ Screen              │  │
│  │              │  │              │  │                     │  │
│  │ - Real-time  │  │ - 3-step     │  │ - BPM prefs         │  │
│  │   feedback   │  │   workflow   │  │ - Debug toggle      │  │
│  │ - BPM ctrl   │  │ - Progress   │  │ - Recalibrate       │  │
│  │ - Debug      │  │   indicator  │  │ - Level selection   │  │
│  │   overlay    │  │              │  │                     │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬──────────┘  │
│         │                 │                     │              │
├─────────┴─────────────────┴─────────────────────┴──────────────┤
│                      Service Layer                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌────────────────────┐  ┌─────────────┐│
│  │ IAudioService    │  │ IStorageService    │  │ ISettings   ││
│  │                  │  │                    │  │ Service     ││
│  │ - startAudio()   │  │ - saveCalibration()│  │ - getBpm()  ││
│  │ - stopAudio()    │  │ - loadCalibration()│  │ - getDebug()││
│  │ - setBpm()       │  │ - saveSettings()   │  │ - setLevel()││
│  │ - classification │  │                    │  │             ││
│  │   Stream()       │  │                    │  │             ││
│  └────────┬─────────┘  └─────────┬──────────┘  └──────┬──────┘│
│           │                      │                    │        │
├───────────┴──────────────────────┴────────────────────┴────────┤
│                    FFI Bridge (flutter_rust_bridge)             │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 Rust API (api.rs)                        │  │
│  │  - start_audio()                                         │  │
│  │  - classification_stream()                               │  │
│  │  - start_calibration()                                   │  │
│  │  - finish_calibration()                                  │  │
│  └────────────────────────┬─────────────────────────────────┘  │
├────────────────────────────┴─────────────────────────────────────┤
│                    Rust Core (AppContext)                        │
├──────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ AudioEngine     │  │ Classifier   │  │ Calibration      │  │
│  │ (Oboe)          │  │              │  │ Procedure        │  │
│  │ - INPUT stream  │  │ - Level 1/2  │  │ - Sample         │  │
│  │ - OUTPUT stream │  │ - Thresholds │  │   collection     │  │
│  │ - Metronome     │  │              │  │ - Threshold      │  │
│  │                 │  │              │  │   computation    │  │
│  └─────────────────┘  └──────────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Detailed Component Designs

### 1. Calibration Onboarding System

#### 1.1 Calibration Storage Service

**Interface**: `lib/services/storage/i_storage_service.dart`
```dart
abstract class IStorageService {
  /// Initialize storage (must be called before use)
  Future<void> init();

  /// Check if calibration data exists
  Future<bool> hasCalibration();

  /// Save calibration data with level
  Future<void> saveCalibration(CalibrationData data);

  /// Load calibration data
  Future<CalibrationData?> loadCalibration();

  /// Clear calibration (for recalibration)
  Future<void> clearCalibration();
}

class CalibrationData {
  final int level;              // 1 or 2
  final DateTime timestamp;     // When calibrated
  final Map<String, double> thresholds;  // Sound type → threshold
}
```

**Implementation**: `lib/services/storage/storage_service_impl.dart`
- Uses `shared_preferences` for key-value storage
- Serializes CalibrationData to JSON
- Keys: `calibration_data`, `calibration_level`, `calibration_timestamp`

**Rust Integration**:
```rust
// Add to rust/src/api.rs
#[flutter_rust_bridge::frb]
pub fn load_calibration_state(json: String) -> Result<(), CalibrationError> {
    let data: CalibrationData = serde_json::from_str(&json)?;
    APP_CONTEXT.load_calibration(data)?;
    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn get_calibration_state() -> Result<String, CalibrationError> {
    let data = APP_CONTEXT.get_calibration_state()?;
    Ok(serde_json::to_string(&data)?)
}
```

#### 1.2 Onboarding Flow

**Router Configuration**: `lib/main.dart`
```dart
import 'package:go_router/go_router.dart';

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => SplashScreen(),  // Check calibration
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(),
    ),
    GoRoute(
      path: '/calibration',
      builder: (context, state) => CalibrationScreen(),
    ),
    GoRoute(
      path: '/training',
      builder: (context, state) => TrainingScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => SettingsScreen(),
    ),
  ],
);

class BeatboxTrainerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
    );
  }
}
```

**Splash Screen Logic**: `lib/ui/screens/splash_screen.dart`
```dart
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkCalibrationAndNavigate();
  }

  Future<void> _checkCalibrationAndNavigate() async {
    final storageService = StorageServiceImpl();
    await storageService.init();

    final hasCalibration = await storageService.hasCalibration();

    if (hasCalibration) {
      // Load calibration into Rust
      final data = await storageService.loadCalibration();
      await api.loadCalibrationState(jsonEncode(data));

      // Navigate to training
      if (mounted) context.go('/training');
    } else {
      // First-time user - show onboarding
      if (mounted) context.go('/onboarding');
    }
  }
}
```

**Onboarding Screen**: `lib/ui/screens/onboarding_screen.dart`
```dart
class OnboardingScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, size: 100, color: Colors.deepPurple),
            SizedBox(height: 32),
            Text(
              'Welcome to Beatbox Trainer!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Before you start training, we need to calibrate '
              'the app to recognize your beatbox sounds.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            _buildCalibrationSteps(context),
            SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.go('/calibration'),
              child: Text('Start Calibration'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationSteps(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(context, '1', 'Make 10 KICK sounds'),
        _buildStep(context, '2', 'Make 10 SNARE sounds'),
        _buildStep(context, '3', 'Make 10 HI-HAT sounds'),
      ],
    );
  }
}
```

#### 1.3 Enhanced Calibration Screen

**Modifications to**: `lib/ui/screens/calibration_screen.dart`

**Add Progress Persistence**:
```dart
class _CalibrationScreenState extends State<CalibrationScreen> {
  final IStorageService _storageService;

  // ... existing state ...

  Future<void> _finishCalibration() async {
    try {
      await api.finishCalibration();

      // Save to persistent storage
      final calibrationJson = await api.getCalibrationState();
      final data = CalibrationData.fromJson(jsonDecode(calibrationJson));
      await _storageService.saveCalibration(data);

      if (mounted) {
        // Show success and navigate to training
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Calibration Complete!'),
            content: Text('You\'re ready to start training.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/training');
                },
                child: Text('Start Training'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Handle error
    }
  }
}
```

### 2. Real-Time Classification Feedback Enhancements

#### 2.1 Enhanced Feedback Display

**Modifications to**: `lib/ui/screens/training_screen.dart`

**Add Animation Controller**:
```dart
class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _feedbackAnimationController;
  late Animation<double> _feedbackOpacity;

  @override
  void initState() {
    super.initState();
    _feedbackAnimationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _feedbackOpacity = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(
        parent: _feedbackAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _feedbackAnimationController.dispose();
    super.dispose();
  }
}
```

**Enhanced Classification Display**:
```dart
Widget _buildClassificationDisplay(ClassificationResult result) {
  // Restart fade animation on new result
  _feedbackAnimationController.forward(from: 0.0);

  return AnimatedBuilder(
    animation: _feedbackOpacity,
    builder: (context, child) {
      return Opacity(
        opacity: _feedbackOpacity.value,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSoundTypeDisplay(result),
              SizedBox(height: 32),
              _buildTimingFeedbackDisplay(result),
              SizedBox(height: 16),
              _buildConfidenceIndicator(result),  // NEW
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildConfidenceIndicator(ClassificationResult result) {
  final confidence = result.confidence ?? 0.0;  // Add to Rust struct
  final color = confidence > 0.8 ? Colors.green :
                confidence > 0.5 ? Colors.orange : Colors.red;

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('Confidence: ', style: TextStyle(fontSize: 16)),
      Container(
        width: 100,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          widthFactor: confidence,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      SizedBox(width: 8),
      Text('${(confidence * 100).toInt()}%'),
    ],
  );
}
```

#### 2.2 Rust Confidence Score Addition

**Modify**: `rust/src/analysis/mod.rs`
```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ClassificationResult {
    pub sound: BeatboxHit,
    pub timing: TimingFeedback,
    pub confidence: f32,  // NEW: 0.0 to 1.0
}
```

**Modify**: `rust/src/analysis/classifier.rs`
```rust
impl Classifier {
    fn classify_level1(&self, features: &AudioFeatures) -> ClassificationResult {
        let kick_score = /* ... existing logic ... */;
        let snare_score = /* ... */;
        let hihat_score = /* ... */;

        let (sound, max_score) = /* ... determine winner ... */;

        // Normalize score to 0.0-1.0 confidence
        let confidence = (max_score / (kick_score + snare_score + hihat_score))
            .clamp(0.0, 1.0);

        ClassificationResult {
            sound,
            timing: self.compute_timing(),
            confidence,
        }
    }
}
```

### 3. Debug Mode System

#### 3.1 Debug Service

**Interface**: `lib/services/debug/i_debug_service.dart`
```dart
abstract class IDebugService {
  /// Get real-time audio metrics
  Stream<AudioMetrics> getAudioMetricsStream();

  /// Get onset detection events
  Stream<OnsetEvent> getOnsetEventsStream();

  /// Export debug logs to file
  Future<String> exportLogs();
}

class AudioMetrics {
  final double rms;              // Current audio level
  final double spectralCentroid; // Brightness
  final double spectralFlux;     // Change rate
  final int frameNumber;         // Sample count
  final DateTime timestamp;
}

class OnsetEvent {
  final DateTime timestamp;
  final double energy;
  final AudioFeatures features;
  final ClassificationResult? classification;
}
```

**Rust API Addition**: `rust/src/api.rs`
```rust
#[flutter_rust_bridge::frb]
pub fn audio_metrics_stream(sink: StreamSink<AudioMetrics>) {
    TOKIO_RUNTIME.spawn(async move {
        let stream = APP_CONTEXT.audio_metrics_stream().await;
        tokio::pin!(stream);
        while let Some(metrics) = stream.next().await {
            sink.add(metrics);
        }
    });
}

#[flutter_rust_bridge::frb]
pub fn onset_events_stream(sink: StreamSink<OnsetEvent>) {
    TOKIO_RUNTIME.spawn(async move {
        let stream = APP_CONTEXT.onset_events_stream().await;
        tokio::pin!(stream);
        while let Some(event) = stream.next().await {
            sink.add(event);
        }
    });
}
```

#### 3.2 Debug Overlay Widget

**File**: `lib/ui/widgets/debug_overlay.dart`
```dart
class DebugOverlay extends StatelessWidget {
  final IDebugService debugService;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content (pass through touches)

        // Debug overlay positioned at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black.withOpacity(0.85),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Debug Metrics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: onClose,
                    ),
                  ],
                ),
                Divider(color: Colors.white54),
                _buildAudioMetrics(),
                SizedBox(height: 16),
                _buildOnsetLog(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioMetrics() {
    return StreamBuilder<AudioMetrics>(
      stream: debugService.getAudioMetricsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text('No audio data', style: TextStyle(color: Colors.white54));
        }

        final metrics = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricRow('RMS Level', metrics.rms.toStringAsFixed(3)),
            _buildMetricRow('Centroid', metrics.spectralCentroid.toStringAsFixed(1)),
            _buildMetricRow('Flux', metrics.spectralFlux.toStringAsFixed(3)),
            _buildMetricRow('Frame', metrics.frameNumber.toString()),
            SizedBox(height: 8),
            _buildRmsLevelMeter(metrics.rms),
          ],
        );
      },
    );
  }

  Widget _buildRmsLevelMeter(double rms) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        widthFactor: (rms * 10).clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildOnsetLog() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: StreamBuilder<OnsetEvent>(
        stream: debugService.getOnsetEventsStream(),
        builder: (context, snapshot) {
          // Display scrollable log of onset events
          return ListView(/* ... */);
        },
      ),
    );
  }
}
```

#### 3.3 Settings Integration

**Modifications to**: `lib/services/settings/i_settings_service.dart`
```dart
abstract class ISettingsService {
  Future<bool> getDebugMode();
  Future<void> setDebugMode(bool enabled);
  // ... other settings ...
}
```

**In TrainingScreen**:
```dart
class _TrainingScreenState extends State<TrainingScreen> {
  bool _debugMode = false;

  @override
  void initState() {
    super.initState();
    _loadDebugMode();
  }

  Future<void> _loadDebugMode() async {
    final settings = SettingsServiceImpl();
    await settings.init();
    final enabled = await settings.getDebugMode();
    setState(() => _debugMode = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _debugMode
          ? DebugOverlay(
              debugService: DebugServiceImpl(),
              onClose: () => setState(() => _debugMode = false),
              child: _buildTrainingContent(),
            )
          : _buildTrainingContent(),
    );
  }
}
```

### 4. Settings Screen

**File**: `lib/ui/screens/settings_screen.dart`
```dart
class SettingsScreen extends StatefulWidget {
  final ISettingsService settingsService;
  final IStorageService storageService;

  SettingsScreen({
    super.key,
    ISettingsService? settingsService,
    IStorageService? storageService,
  }) : settingsService = settingsService ?? SettingsServiceImpl(),
       storageService = storageService ?? StorageServiceImpl();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _defaultBpm = 120;
  bool _debugMode = false;
  int _classifierLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await widget.settingsService.init();
    final bpm = await widget.settingsService.getBpm();
    final debug = await widget.settingsService.getDebugMode();
    final level = await widget.settingsService.getClassifierLevel();

    setState(() {
      _defaultBpm = bpm;
      _debugMode = debug;
      _classifierLevel = level;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildBpmSetting(),
          Divider(),
          _buildDebugModeSetting(),
          Divider(),
          _buildClassifierLevelSetting(),
          Divider(),
          _buildRecalibrateSetting(),
        ],
      ),
    );
  }

  Widget _buildClassifierLevelSetting() {
    return SwitchListTile(
      title: Text('Advanced Mode'),
      subtitle: Text(
        _classifierLevel == 1
            ? 'Beginner (3 categories: KICK, SNARE, HIHAT)'
            : 'Advanced (6 categories with subcategories)',
      ),
      value: _classifierLevel == 2,
      onChanged: (value) async {
        final newLevel = value ? 2 : 1;

        // Show recalibration warning
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Recalibration Required'),
            content: Text(
              'Switching classifier levels requires recalibration. '
              'Your current calibration will be cleared.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Recalibrate'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await widget.settingsService.setClassifierLevel(newLevel);
          await widget.storageService.clearCalibration();

          setState(() => _classifierLevel = newLevel);

          if (mounted) {
            context.go('/calibration');
          }
        }
      },
    );
  }

  Widget _buildRecalibrateSetting() {
    return ListTile(
      leading: Icon(Icons.refresh),
      title: Text('Recalibrate'),
      subtitle: Text('Clear calibration and start over'),
      trailing: Icon(Icons.arrow_forward),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Recalibration'),
            content: Text('This will clear your current calibration.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Recalibrate'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await widget.storageService.clearCalibration();
          if (mounted) {
            context.go('/calibration');
          }
        }
      },
    );
  }
}
```

### 5. Classifier Level Selection (Rust)

**Modify**: `rust/src/calibration/state.rs`
```rust
#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub struct CalibrationState {
    pub level: u8,  // NEW: 1 or 2
    pub kick_threshold: f32,
    pub snare_threshold: f32,
    // ... existing thresholds ...
}
```

**Modify**: `rust/src/analysis/classifier.rs`
```rust
impl Classifier {
    pub fn classify(&self, features: &AudioFeatures) -> ClassificationResult {
        let calibration = self.calibration.read().unwrap();

        match calibration.level {
            1 => self.classify_level1(features),
            2 => self.classify_level2(features),
            _ => unreachable!("Invalid calibration level"),
        }
    }

    // Existing Level 1 implementation
    fn classify_level1(&self, features: &AudioFeatures) -> ClassificationResult {
        // ... existing 3-category logic ...
    }

    // NEW: Level 2 implementation
    fn classify_level2(&self, features: &AudioFeatures) -> ClassificationResult {
        // 6-category classification with subcategories
        // Kick, Snare, ClosedHiHat, OpenHiHat, KSnare, Silence
        // ... implement advanced classification logic ...
    }
}
```

### 6. Test Infrastructure

#### 6.1 Test File Organization

```
test/
├── services/
│   ├── audio_service_test.dart
│   ├── storage_service_test.dart         # NEW
│   ├── settings_service_test.dart        # NEW
│   ├── debug_service_test.dart           # NEW
│   └── permission_service_test.dart
├── ui/
│   ├── screens/
│   │   ├── training_screen_test.dart
│   │   ├── calibration_screen_test.dart
│   │   ├── settings_screen_test.dart     # NEW
│   │   ├── onboarding_screen_test.dart   # NEW
│   │   └── splash_screen_test.dart       # NEW
│   └── widgets/
│       ├── debug_overlay_test.dart       # NEW
│       └── ...
└── integration/
    └── calibration_flow_test.dart        # NEW
```

#### 6.2 Mock Definitions

**File**: `test/mocks.dart`
```dart
import 'package:mocktail/mocktail.dart';

// Service mocks
class MockAudioService extends Mock implements IAudioService {}
class MockStorageService extends Mock implements IStorageService {}
class MockSettingsService extends Mock implements ISettingsService {}
class MockDebugService extends Mock implements IDebugService {}
class MockPermissionService extends Mock implements IPermissionService {}
```

#### 6.3 Example Test: Storage Service

**File**: `test/services/storage_service_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageServiceImpl', () {
    late StorageServiceImpl storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageServiceImpl();
      await storageService.init();
    });

    test('hasCalibration returns false when no data saved', () async {
      final result = await storageService.hasCalibration();
      expect(result, isFalse);
    });

    test('saveCalibration and loadCalibration round-trip', () async {
      final data = CalibrationData(
        level: 1,
        timestamp: DateTime.now(),
        thresholds: {'kick': 0.5, 'snare': 0.6},
      );

      await storageService.saveCalibration(data);

      final loaded = await storageService.loadCalibration();
      expect(loaded, isNotNull);
      expect(loaded!.level, equals(1));
      expect(loaded.thresholds['kick'], equals(0.5));
    });

    test('clearCalibration removes saved data', () async {
      final data = CalibrationData(level: 1, /* ... */);
      await storageService.saveCalibration(data);

      await storageService.clearCalibration();

      final hasData = await storageService.hasCalibration();
      expect(hasData, isFalse);
    });
  });
}
```

#### 6.4 Coverage Configuration

**File**: `coverage.sh` (update existing script)
```bash
#!/bin/bash
flutter test --coverage
lcov --remove coverage/lcov.info \
  '*/frb_generated.dart' \
  '*/bridge_generated.rs' \
  '**/*.g.dart' \
  -o coverage/lcov_filtered.info

genhtml coverage/lcov_filtered.info -o coverage/html

# Check coverage threshold
COVERAGE=$(lcov --summary coverage/lcov_filtered.info | grep lines | awk '{print $2}' | sed 's/%//')
THRESHOLD=80

if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
  echo "ERROR: Coverage $COVERAGE% is below threshold $THRESHOLD%"
  exit 1
else
  echo "SUCCESS: Coverage $COVERAGE% meets threshold $THRESHOLD%"
fi
```

### 7. UAT Test Documentation

**File**: `.spec-workflow/specs/uat-readiness/UAT_TEST_SCENARIOS.md` (to be created in tasks phase)

**Structure**:
```markdown
# UAT Test Scenarios for Beatbox Trainer

## Test Environment
- Devices: Pixel 9a, Samsung Galaxy S21, OnePlus 9
- Android versions: 11, 12, 13
- Build: Debug APK from `flutter build apk --debug`

## Scenario 1: First-Time User Onboarding
**Prerequisite**: Fresh app install, no calibration data
**Steps**:
1. Launch app
2. Verify splash screen appears
3. Verify onboarding screen displays with 3 calibration steps
4. Tap "Start Calibration"
5. Complete KICK calibration (10 samples)
6. Complete SNARE calibration (10 samples)
7. Complete HIHAT calibration (10 samples)
8. Verify success message
9. Verify navigation to training screen

**Expected**: User guided through calibration, data persisted
**Pass/Fail**: ___

## Scenario 2: Real-Time Classification Feedback
**Prerequisite**: Calibration complete
**Steps**:
1. Tap "Start" button
2. Make KICK sound
3. Verify sound type displayed with color
4. Verify timing feedback (ms)
5. Verify confidence meter
6. Make SNARE sound
7. Verify classification updates immediately
8. Tap "Stop"

**Expected**: <100ms latency, accurate classification, smooth animations
**Pass/Fail**: ___

## [... 13 more scenarios ...]

## Performance Benchmarks
| Metric | Target | Actual | Pass/Fail |
|--------|--------|--------|-----------|
| Audio callback latency (P99) | <10ms | ___ | ___ |
| UI update latency | <100ms | ___ | ___ |
| App launch time | <3s | ___ | ___ |
| Memory usage (training) | <150MB | ___ | ___ |
| CPU usage (sustained) | <40% | ___ | ___ |

## Sign-Off
- [ ] All scenarios passed on Pixel 9a
- [ ] All scenarios passed on Samsung Galaxy S21
- [ ] All scenarios passed on OnePlus 9
- [ ] Performance benchmarks met
- [ ] No critical bugs identified

**QA Engineer**: ___________  **Date**: ___________
```

## Technology Stack

### New Dependencies

**pubspec.yaml additions**:
```yaml
dependencies:
  go_router: ^14.6.2           # Navigation
  shared_preferences: ^2.3.4   # Key-value storage
  fl_chart: ^0.70.4            # Debug charts (optional)

dev_dependencies:
  mocktail: ^1.0.4             # Mocking (already present)
  integration_test:             # Integration tests
    sdk: flutter
```

**Cargo.toml additions** (if needed):
```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

## Data Models

### CalibrationData (Dart)
```dart
class CalibrationData {
  final int level;
  final DateTime timestamp;
  final Map<String, double> thresholds;

  CalibrationData({
    required this.level,
    required this.timestamp,
    required this.thresholds,
  });

  factory CalibrationData.fromJson(Map<String, dynamic> json) { /* ... */ }
  Map<String, dynamic> toJson() { /* ... */ }
}
```

### CalibrationState (Rust)
```rust
#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub struct CalibrationState {
    pub level: u8,
    pub kick_threshold: f32,
    pub snare_threshold: f32,
    pub hihat_threshold: f32,
    // Level 2 additional thresholds
    pub closed_hihat_threshold: f32,
    pub open_hihat_threshold: f32,
    pub ksnare_threshold: f32,
}
```

## Performance Considerations

### Optimization Strategies

1. **Stream Buffering**: Prevent UI jank from rapid classification updates
   ```dart
   _classificationStream
       .transform(StreamTransformer.fromHandlers(
         handleData: (data, sink) {
           // Throttle updates to 60fps max
           if (_lastUpdateTime == null ||
               DateTime.now().difference(_lastUpdateTime!) >
                   Duration(milliseconds: 16)) {
             sink.add(data);
             _lastUpdateTime = DateTime.now();
           }
         },
       ))
   ```

2. **Debug Mode Performance**: Only subscribe to debug streams when enabled
   ```dart
   Stream<AudioMetrics>? _debugStream;

   void _toggleDebugMode(bool enabled) {
     if (enabled) {
       _debugStream = debugService.getAudioMetricsStream();
     } else {
       _debugStream = null;  // Unsubscribe
     }
   }
   ```

3. **Lazy Initialization**: Defer service initialization until needed
   ```dart
   late final IDebugService _debugService = DebugServiceImpl();  // Lazy
   ```

## Error Handling

### New Error Types

**CalibrationServiceException**:
```dart
class CalibrationServiceException implements Exception {
  final String message;
  final CalibrationError? rustError;

  CalibrationServiceException(this.message, [this.rustError]);
}
```

**StorageException**:
```dart
class StorageException implements Exception {
  final String message;
  final Exception? cause;

  StorageException(this.message, [this.cause]);
}
```

## Security Considerations

1. **Calibration Data Validation**: Verify thresholds are within valid ranges before loading
2. **Settings Sanitization**: Validate all settings values before saving
3. **Debug Mode Protection**: Ensure debug logs don't leak sensitive data
4. **Storage Encryption**: Consider encrypting calibration data if user privacy is concern (out of scope for UAT)

## Accessibility

1. **Screen Reader Support**: Add semantic labels to all interactive elements
2. **Large Text Support**: Ensure UI scales with system font size
3. **Color Blind Mode**: Use patterns in addition to colors for feedback
4. **Haptic Feedback**: Add vibration feedback for successful classifications (optional)

## Internationalization (Future)

Currently English-only, but design supports future i18n:
- All user-facing strings in separate constants file
- Date/time formatting locale-aware
- Numeric formatting locale-aware

## Migration Strategy

### Gradual Rollout Plan

1. **Phase 1**: Calibration onboarding (1 week)
   - Splash screen + onboarding + storage service
   - Prevents breaking existing users

2. **Phase 2**: Real-time feedback enhancements (3 days)
   - Confidence scores + animations
   - Backward compatible with existing calibration

3. **Phase 3**: Debug mode + Settings (1 week)
   - Optional features, no impact on core flow

4. **Phase 4**: Classifier Level 2 (1 week)
   - Advanced users opt-in via settings

5. **Phase 5**: Testing infrastructure (1 week)
   - Unit tests + integration tests + coverage

6. **Phase 6**: UAT documentation + execution (3 days)
   - Test scenario execution + sign-off

## Success Criteria

1. ✅ All 6 user stories implemented and tested
2. ✅ Zero critical bugs (no crashes, hangs, data loss)
3. ✅ 80%+ test coverage (90%+ on critical paths)
4. ✅ All UAT scenarios pass on 3 devices
5. ✅ Performance NFRs met on Pixel 9a
6. ✅ Documentation complete (README, UAT scenarios, API docs)

## Open Questions

1. **Calibration expiry**: Should calibration data expire after X days?
2. **Cloud backup**: Should calibration sync across devices? (Out of scope for UAT)
3. **Analytics**: Track calibration success rates? (Privacy considerations)
4. **Audio recording**: Allow users to record training sessions? (Storage implications)

## References

- [Flutter go_router documentation](https://pub.dev/packages/go_router)
- [shared_preferences best practices](https://pub.dev/packages/shared_preferences)
- [Mocktail testing patterns](https://pub.dev/packages/mocktail)
- [Flutter testing documentation](https://docs.flutter.dev/testing)
