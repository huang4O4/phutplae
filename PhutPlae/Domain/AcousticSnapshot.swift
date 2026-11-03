import Foundation

struct AcousticSnapshot: Equatable, Sendable {
    /// Mean RMS of the utterance, typically 0...0.3 for close speech.
    var rms: Double
    /// Peak RMS in the utterance.
    var peakRMS: Double
    /// Estimated F0 in Hz, or nil if unvoiced / too short.
    var pitchHz: Double?
    /// Coefficient of variation of frame RMS (0...~2).
    var energyVariance: Double
    /// Approximate syllables / words per second from energy bursts.
    var speakingRate: Double
    var durationSeconds: Double
}

struct EmotionEstimate: Equatable, Sendable {
    var emotion: Emotion
    var intensity: Double
    var scores: [Emotion: Double]

    init(emotion: Emotion, intensity: Double, scores: [Emotion: Double] = [:]) {
        self.emotion = emotion
        self.intensity = TranslationPayload.clampIntensity(intensity)
        self.scores = scores
    }
}
