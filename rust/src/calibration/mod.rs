// Calibration module - user calibration workflow and threshold storage
//
// This module provides two main components:
// 1. CalibrationState: Stores threshold values for sound classification
// 2. CalibrationProcedure: Manages the sample collection workflow
//
// The calibration workflow:
// 1. Create CalibrationProcedure
// 2. Collect 10 samples each for kick, snare, and hi-hat
// 3. Finalize to create CalibrationState with computed thresholds

pub mod state;
pub mod procedure;

pub use state::CalibrationState;
pub use procedure::{CalibrationProcedure, CalibrationSound, CalibrationProgress};
