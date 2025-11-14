================================================================================
CODE METRICS COMPLIANCE REPORT
================================================================================

Standards:
  - Max file size: 500 lines (excluding comments/blanks)
  - Max function size: 50 lines (excluding comments/blanks)

Summary:
  - Total files analyzed: 100
  - Total code lines: 13,448
  - Files with violations: 28
  - Total violations: 29

--------------------------------------------------------------------------------
VIOLATIONS
--------------------------------------------------------------------------------

File: test/ui/screens/calibration_screen_test.dart
  Code lines: 585
  ❌ File exceeds 500 code lines: 585 lines
  ❌ Function 'main' at line 9 exceeds 50 code lines: 578 lines

File: lib/ui/widgets/debug_overlay.dart
  Code lines: 293
  ❌ Function '_buildAudioMetrics' at line 124 exceeds 50 code lines: 53 lines

File: lib/ui/widgets/bpm_control.dart
  Code lines: 66
  ❌ Function 'build' at line 38 exceeds 50 code lines: 54 lines

File: test/services/settings_service_test.dart
  Code lines: 389
  ❌ Function 'main' at line 5 exceeds 50 code lines: 386 lines

File: test/services/storage_service_test.dart
  Code lines: 391
  ❌ Function 'main' at line 6 exceeds 50 code lines: 387 lines

File: test/services/permission_service_test.dart
  Code lines: 97
  ❌ Function 'main' at line 10 exceeds 50 code lines: 94 lines

File: test/services/audio_service_test.dart
  Code lines: 281
  ❌ Function 'main' at line 10 exceeds 50 code lines: 275 lines

File: test/services/error_handler_test.dart
  Code lines: 249
  ❌ Function 'main' at line 5 exceeds 50 code lines: 246 lines

File: test/di/service_locator_test.dart
  Code lines: 188
  ❌ Function 'main' at line 16 exceeds 50 code lines: 174 lines

File: test/integration/refactored_workflows_test.dart
  Code lines: 244
  ❌ Function 'main' at line 29 exceeds 50 code lines: 228 lines

File: test/integration/stream_workflows_test.dart
  Code lines: 260
  ❌ Function 'main' at line 23 exceeds 50 code lines: 254 lines

File: test/integration/audio_integration_test.dart
  Code lines: 202
  ❌ Function 'main' at line 18 exceeds 50 code lines: 198 lines

File: test/integration/calibration_flow_test.dart
  Code lines: 117
  ❌ Function 'main' at line 21 exceeds 50 code lines: 112 lines

File: test/services/audio/audio_service_impl_test.dart
  Code lines: 123
  ❌ Function 'main' at line 21 exceeds 50 code lines: 117 lines

File: test/controllers/training/training_controller_test.dart
  Code lines: 343
  ❌ Function 'main' at line 9 exceeds 50 code lines: 336 lines

File: test/ui/utils/display_formatters_test.dart
  Code lines: 152
  ❌ Function 'main' at line 7 exceeds 50 code lines: 147 lines

File: test/ui/screens/training_screen_test.dart
  Code lines: 302
  ❌ Function 'main' at line 17 exceeds 50 code lines: 291 lines

File: test/ui/screens/settings_screen_test.dart
  Code lines: 252
  ❌ Function 'main' at line 8 exceeds 50 code lines: 246 lines

File: test/ui/screens/onboarding_screen_test.dart
  Code lines: 127
  ❌ Function 'main' at line 6 exceeds 50 code lines: 123 lines

File: test/ui/screens/splash_screen_test.dart
  Code lines: 79
  ❌ Function 'main' at line 8 exceeds 50 code lines: 73 lines

File: test/ui/widgets/classification_indicator_test.dart
  Code lines: 248
  ❌ Function 'main' at line 7 exceeds 50 code lines: 243 lines

File: test/ui/widgets/permission_dialogs_test.dart
  Code lines: 183
  ❌ Function 'main' at line 5 exceeds 50 code lines: 180 lines

File: test/ui/widgets/error_dialog_test.dart
  Code lines: 218
  ❌ Function 'main' at line 5 exceeds 50 code lines: 215 lines

File: test/ui/widgets/timing_feedback_test.dart
  Code lines: 236
  ❌ Function 'main' at line 7 exceeds 50 code lines: 231 lines

File: test/ui/widgets/status_card_test.dart
  Code lines: 183
  ❌ Function 'main' at line 5 exceeds 50 code lines: 180 lines

File: test/ui/widgets/loading_overlay_test.dart
  Code lines: 56
  ❌ Function 'main' at line 5 exceeds 50 code lines: 53 lines

File: test/ui/widgets/bpm_control_test.dart
  Code lines: 253
  ❌ Function 'main' at line 5 exceeds 50 code lines: 250 lines

File: rust/src/analysis/mod.rs
  Code lines: 74
  ❌ Function 'spawn_analysis_thread' at line 73 exceeds 50 code lines: 54 lines

--------------------------------------------------------------------------------
TOP 10 LARGEST FILES (by code lines)
--------------------------------------------------------------------------------

 1. ❌ test/ui/screens/calibration_screen_test.dart                  585 lines
 2. ✅ rust/src/error.rs                                             480 lines
 3. ✅ rust/src/analysis/classifier.rs                               438 lines
 4. ✅ lib/ui/screens/training_screen.dart                           421 lines
 5. ✅ lib/ui/screens/calibration_screen.dart                        410 lines
 6. ✅ test/services/storage_service_test.dart                       391 lines
 7. ✅ test/services/settings_service_test.dart                      389 lines
 8. ✅ test/controllers/training/training_controller_test.dart       343 lines
 9. ✅ rust/src/calibration/procedure.rs                             327 lines
10. ✅ test/ui/screens/training_screen_test.dart                     302 lines

--------------------------------------------------------------------------------
TOP 10 LARGEST FUNCTIONS (by code lines)
--------------------------------------------------------------------------------

 1. ❌ main                            578 lines (calibration_screen_test.dart:9)
 2. ❌ main                            387 lines (storage_service_test.dart:6)
 3. ❌ main                            386 lines (settings_service_test.dart:5)
 4. ❌ main                            336 lines (training_controller_test.dart:9)
 5. ❌ main                            291 lines (training_screen_test.dart:17)
 6. ❌ main                            275 lines (audio_service_test.dart:10)
 7. ❌ main                            254 lines (stream_workflows_test.dart:23)
 8. ❌ main                            250 lines (bpm_control_test.dart:5)
 9. ❌ main                            246 lines (error_handler_test.dart:5)
10. ❌ main                            246 lines (settings_screen_test.dart:8)

================================================================================