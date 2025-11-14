// Managers Module
//
// Focused manager classes extracted from AppContext to apply Single Responsibility Principle.
//
// Each manager handles one specific concern:
// - AudioEngineManager: Audio engine lifecycle and BPM management
// - CalibrationManager: Calibration workflow and state persistence
// - BroadcastChannelManager: Tokio broadcast channel management

pub mod audio_engine_manager;
pub mod broadcast_manager;
pub mod calibration_manager;

pub use audio_engine_manager::AudioEngineManager;
pub use broadcast_manager::BroadcastChannelManager;
pub use calibration_manager::CalibrationManager;
