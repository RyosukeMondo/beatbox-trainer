// Calibration module - user calibration workflow and threshold storage
//
// This module provides components for the calibration workflow:
// 1. CalibrationState: Stores threshold values for sound classification
// 2. CalibrationProcedure: Manages the sample collection workflow
// 3. CalibrationProgress: Tracks progress through calibration steps
// 4. SampleValidator: Validates audio feature samples
//
// The calibration workflow:
// 1. Create CalibrationProcedure
// 2. Collect 10 samples each for kick, snare, and hi-hat
// 3. Finalize to create CalibrationState with computed thresholds

pub mod procedure;
pub mod progress;
pub mod state;
pub mod validation;

pub use procedure::CalibrationProcedure;
pub use progress::{CalibrationProgress, CalibrationSound};
pub use state::CalibrationState;
