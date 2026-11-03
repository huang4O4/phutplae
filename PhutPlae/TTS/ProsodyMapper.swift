import Foundation

/// Maps fused emotion + intensity onto AVSpeech-style prosody.
/// Values are kept in AVSpeechUtterance ranges so a neural TTS can reuse them later.
struct SpeechProsody: Equatable, Sendable {
    var rate: Float
    var pitchMultiplier: Float
    var volume: Float
    var preUtteranceDelay: TimeInterval
    var postUtteranceDelay: TimeInterval

    static let rateRange: ClosedRange<Float> = 0.35...0.72
    static let pitchRange: ClosedRange<Float> = 0.70...1.55
    static let volumeRange: ClosedRange<Float> = 0.45...1.0
}

enum ProsodyMapper {
    static func map(
        emotion: Emotion,
        intensity: Double,
        speedScale: Double = 1.0
    ) -> SpeechProsody {
        let i = Float(TranslationPayload.clampIntensity(intensity))
        let scale = Float(min(1.4, max(0.7, speedScale)))

        let base: SpeechProsody
        switch emotion {
        case .neutral:
            base = SpeechProsody(
                rate: 0.48,
                pitchMultiplier: 1.00,
                volume: 0.78,
                preUtteranceDelay: 0.06,
                postUtteranceDelay: 0.10
            )
        case .angry:
            base = SpeechProsody(
                rate: 0.54 + 0.14 * i,
                pitchMultiplier: 1.12 + 0.28 * i,
                volume: 0.88 + 0.12 * i,
                preUtteranceDelay: 0.02,
                postUtteranceDelay: 0.04
            )
        case .happy:
            base = SpeechProsody(
                rate: 0.52 + 0.10 * i,
                pitchMultiplier: 1.10 + 0.22 * i,
                volume: 0.82 + 0.10 * i,
                preUtteranceDelay: 0.04,
                postUtteranceDelay: 0.08
            )
        case .sad:
            base = SpeechProsody(
                rate: 0.42 - 0.08 * i,
                pitchMultiplier: 0.90 - 0.12 * i,
                volume: 0.64 - 0.12 * i,
                preUtteranceDelay: 0.16,
                postUtteranceDelay: 0.22
            )
        case .fearful:
            base = SpeechProsody(
                rate: 0.56 + 0.08 * i,
                pitchMultiplier: 1.18 + 0.16 * i,
                volume: 0.70 + 0.08 * i,
                preUtteranceDelay: 0.03,
                postUtteranceDelay: 0.12
            )
        case .surprised:
            base = SpeechProsody(
                rate: 0.55 + 0.12 * i,
                pitchMultiplier: 1.22 + 0.20 * i,
                volume: 0.84 + 0.10 * i,
                preUtteranceDelay: 0.00,
                postUtteranceDelay: 0.14
            )
        }

        return SpeechProsody(
            rate: clamp(base.rate * scale, SpeechProsody.rateRange),
            pitchMultiplier: clamp(base.pitchMultiplier, SpeechProsody.pitchRange),
            volume: clamp(base.volume, SpeechProsody.volumeRange),
            preUtteranceDelay: max(0, base.preUtteranceDelay),
            postUtteranceDelay: max(0, base.postUtteranceDelay)
        )
    }

    static func clamp(_ value: Float, _ range: ClosedRange<Float>) -> Float {
        min(range.upperBound, max(range.lowerBound, value))
    }
}
