import Foundation

struct TranslationPayload: Equatable, Sendable {
    var spokenText: String
    var emotion: Emotion
    var intensity: Double

    init(spokenText: String, emotion: Emotion, intensity: Double) {
        self.spokenText = spokenText
        self.emotion = emotion
        self.intensity = Self.clampIntensity(intensity)
    }

    static func clampIntensity(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

struct SpokenUtterance: Equatable, Sendable {
    var text: String
    var language: String
    var emotion: Emotion
    var intensity: Double
    var speedScale: Double
}
