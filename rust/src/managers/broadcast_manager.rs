// BroadcastChannelManager: Centralized tokio broadcast channel management
// Single Responsibility: Broadcast channel lifecycle and subscription

use std::sync::{Arc, Mutex};
use tokio::sync::broadcast;

use crate::analysis::ClassificationResult;
use crate::api::{AudioMetrics, OnsetEvent};
use crate::calibration::CalibrationProgress;

/// Manages all tokio broadcast channels
///
/// Single Responsibility: Broadcast channel lifecycle and subscription
///
/// This manager centralizes all broadcast channel creation, storage, and
/// subscription handling. It provides a clean interface for:
/// - Initializing broadcast channels with appropriate buffer sizes
/// - Subscribing to broadcast channels for multiple consumers
/// - Managing channel lifecycle (creation, cleanup)
///
/// # Channel Types
/// - Classification: Real-time classification results from audio engine
/// - Calibration: Progress updates during calibration workflow
/// - Audio Metrics: Debug metrics for audio analysis (RMS, spectral centroid, etc.)
/// - Onset Events: Debug onset detection events with timing and energy
pub struct BroadcastChannelManager {
    classification: Arc<Mutex<Option<broadcast::Sender<ClassificationResult>>>>,
    calibration: Arc<Mutex<Option<broadcast::Sender<CalibrationProgress>>>>,
    audio_metrics: Arc<Mutex<Option<broadcast::Sender<AudioMetrics>>>>,
    onset_events: Arc<Mutex<Option<broadcast::Sender<OnsetEvent>>>>,
}

impl BroadcastChannelManager {
    /// Create a new BroadcastChannelManager with all channels uninitialized
    ///
    /// Channels must be explicitly initialized via init_* methods before use.
    pub fn new() -> Self {
        Self {
            classification: Arc::new(Mutex::new(None)),
            calibration: Arc::new(Mutex::new(None)),
            audio_metrics: Arc::new(Mutex::new(None)),
            onset_events: Arc::new(Mutex::new(None)),
        }
    }

    // ========================================================================
    // CLASSIFICATION CHANNEL
    // ========================================================================

    /// Initialize classification broadcast channel
    ///
    /// Returns sender for audio engine to publish classification results.
    /// Creates a broadcast channel with 100-message buffer to handle burst traffic.
    ///
    /// # Returns
    /// `broadcast::Sender<ClassificationResult>` - Sender for publishing results
    ///
    /// # Notes
    /// - Buffer size: 100 messages (sufficient for ~3 seconds at 30 BPM)
    /// - Multiple subscribers supported via broadcast pattern
    /// - Old messages dropped if buffer fills (lagged subscribers)
    pub fn init_classification(&self) -> broadcast::Sender<ClassificationResult> {
        let (tx, _) = broadcast::channel(100);
        *self.classification.lock().unwrap() = Some(tx.clone());
        tx
    }

    /// Subscribe to classification results
    ///
    /// Returns a receiver for consuming classification results. Each subscriber
    /// receives independent copies of all messages via the broadcast channel.
    ///
    /// # Returns
    /// `Option<broadcast::Receiver<ClassificationResult>>` - Receiver or None if not initialized
    ///
    /// # Notes
    /// - Returns None if init_classification() not called yet
    /// - Each subscriber gets independent receiver
    /// - Subscribers must keep up with message rate or will lag
    pub fn subscribe_classification(&self) -> Option<broadcast::Receiver<ClassificationResult>> {
        self.classification
            .lock()
            .unwrap()
            .as_ref()
            .map(|tx| tx.subscribe())
    }

    // ========================================================================
    // CALIBRATION CHANNEL
    // ========================================================================

    /// Initialize calibration broadcast channel
    ///
    /// Returns sender for calibration procedure to publish progress updates.
    /// Creates a broadcast channel with 50-message buffer (sufficient for
    /// progress updates during 30-sample collection).
    ///
    /// # Returns
    /// `broadcast::Sender<CalibrationProgress>` - Sender for publishing progress
    ///
    /// # Notes
    /// - Buffer size: 50 messages (sufficient for 30 samples with margin)
    /// - Progress includes: sound type, sample count, total samples
    pub fn init_calibration(&self) -> broadcast::Sender<CalibrationProgress> {
        let (tx, _) = broadcast::channel(50);
        *self.calibration.lock().unwrap() = Some(tx.clone());
        tx
    }

    /// Subscribe to calibration progress
    ///
    /// Returns a receiver for consuming calibration progress updates.
    ///
    /// # Returns
    /// `Option<broadcast::Receiver<CalibrationProgress>>` - Receiver or None if not initialized
    ///
    /// # Notes
    /// - Returns None if init_calibration() not called yet
    /// - Progress updates sent for each collected sample
    pub fn subscribe_calibration(&self) -> Option<broadcast::Receiver<CalibrationProgress>> {
        self.calibration
            .lock()
            .unwrap()
            .as_ref()
            .map(|tx| tx.subscribe())
    }

    // ========================================================================
    // AUDIO METRICS CHANNEL (DEBUG)
    // ========================================================================

    /// Initialize audio metrics broadcast channel
    ///
    /// Returns sender for audio engine to publish debug metrics.
    /// Creates a broadcast channel with 100-message buffer for metrics streaming.
    ///
    /// # Returns
    /// `broadcast::Sender<AudioMetrics>` - Sender for publishing metrics
    ///
    /// # Notes
    /// - Buffer size: 100 messages
    /// - Used for debug UI visualization only
    /// - Not part of critical audio path
    pub fn init_audio_metrics(&self) -> broadcast::Sender<AudioMetrics> {
        let (tx, _) = broadcast::channel(100);
        *self.audio_metrics.lock().unwrap() = Some(tx.clone());
        tx
    }

    /// Subscribe to audio metrics
    ///
    /// Returns a receiver for consuming audio metrics for debug visualization.
    ///
    /// # Returns
    /// `Option<broadcast::Receiver<AudioMetrics>>` - Receiver or None if not initialized
    pub fn subscribe_audio_metrics(&self) -> Option<broadcast::Receiver<AudioMetrics>> {
        self.audio_metrics
            .lock()
            .unwrap()
            .as_ref()
            .map(|tx| tx.subscribe())
    }

    // ========================================================================
    // ONSET EVENTS CHANNEL (DEBUG)
    // ========================================================================

    /// Initialize onset events broadcast channel
    ///
    /// Returns sender for audio engine to publish onset detection events.
    /// Creates a broadcast channel with 100-message buffer.
    ///
    /// # Returns
    /// `broadcast::Sender<OnsetEvent>` - Sender for publishing onset events
    ///
    /// # Notes
    /// - Buffer size: 100 messages
    /// - Used for debug UI visualization only
    /// - Not part of critical audio path
    pub fn init_onset_events(&self) -> broadcast::Sender<OnsetEvent> {
        let (tx, _) = broadcast::channel(100);
        *self.onset_events.lock().unwrap() = Some(tx.clone());
        tx
    }

    /// Subscribe to onset events
    ///
    /// Returns a receiver for consuming onset events for debug visualization.
    ///
    /// # Returns
    /// `Option<broadcast::Receiver<OnsetEvent>>` - Receiver or None if not initialized
    pub fn subscribe_onset_events(&self) -> Option<broadcast::Receiver<OnsetEvent>> {
        self.onset_events
            .lock()
            .unwrap()
            .as_ref()
            .map(|tx| tx.subscribe())
    }
}

impl Default for BroadcastChannelManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classification_channel_lifecycle() {
        let manager = BroadcastChannelManager::new();

        // Initially no subscription possible
        assert!(manager.subscribe_classification().is_none());

        // Initialize channel
        let _tx = manager.init_classification();

        // Now subscription works
        let rx = manager.subscribe_classification();
        assert!(rx.is_some());
    }

    #[test]
    fn test_classification_multiple_subscribers() {
        use crate::analysis::classifier::BeatboxHit;
        use crate::analysis::quantizer::{TimingClassification, TimingFeedback};

        let manager = BroadcastChannelManager::new();
        let tx = manager.init_classification();

        // Create two subscribers
        let mut rx1 = manager.subscribe_classification().unwrap();
        let mut rx2 = manager.subscribe_classification().unwrap();

        // Send message
        let result = ClassificationResult {
            sound: BeatboxHit::Kick,
            timing: TimingFeedback {
                classification: TimingClassification::OnTime,
                error_ms: 0.0,
            },
            timestamp_ms: 0,
            confidence: 0.95,
        };
        tx.send(result.clone()).unwrap();

        // Both subscribers receive the message
        assert_eq!(rx1.try_recv().unwrap().sound, result.sound);
        assert_eq!(rx2.try_recv().unwrap().sound, result.sound);
    }

    #[test]
    fn test_calibration_channel_lifecycle() {
        let manager = BroadcastChannelManager::new();

        // Initially no subscription possible
        assert!(manager.subscribe_calibration().is_none());

        // Initialize channel
        let _tx = manager.init_calibration();

        // Now subscription works
        let rx = manager.subscribe_calibration();
        assert!(rx.is_some());
    }

    #[test]
    fn test_audio_metrics_channel_lifecycle() {
        let manager = BroadcastChannelManager::new();

        // Initially no subscription possible
        assert!(manager.subscribe_audio_metrics().is_none());

        // Initialize channel
        let _tx = manager.init_audio_metrics();

        // Now subscription works
        let rx = manager.subscribe_audio_metrics();
        assert!(rx.is_some());
    }

    #[test]
    fn test_onset_events_channel_lifecycle() {
        let manager = BroadcastChannelManager::new();

        // Initially no subscription possible
        assert!(manager.subscribe_onset_events().is_none());

        // Initialize channel
        let _tx = manager.init_onset_events();

        // Now subscription works
        let rx = manager.subscribe_onset_events();
        assert!(rx.is_some());
    }

    #[test]
    fn test_default_implementation() {
        let manager = BroadcastChannelManager::default();

        // All channels should be uninitialized
        assert!(manager.subscribe_classification().is_none());
        assert!(manager.subscribe_calibration().is_none());
        assert!(manager.subscribe_audio_metrics().is_none());
        assert!(manager.subscribe_onset_events().is_none());
    }
}
