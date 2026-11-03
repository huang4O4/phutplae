import Foundation

struct FusedEmotion: Equatable, Sendable {
    var emotion: Emotion
    var intensity: Double
    var confidence: Double
    var scores: [Emotion: Double]
}

/// Weighted fusion. SER on raw audio is the primary signal.
enum EmotionFusion {
    static let serWeight = 0.62
    static let acousticWeight = 0.18
    static let textWeight = 0.20

    static func fuse(
        ser: EmotionDistribution,
        acoustic: EmotionEstimate,
        textual: EmotionEstimate,
        serAvailable: Bool = true
    ) -> FusedEmotion {
        let acousticDist = EmotionDistribution.fromEstimate(acoustic)
        let textDist = EmotionDistribution.fromEstimate(textual)

        let weights: (ser: Double, acoustic: Double, text: Double) = {
            if serAvailable {
                return (serWeight, acousticWeight, textWeight)
            }
            let denom = acousticWeight + textWeight
            return (0, acousticWeight / denom, textWeight / denom)
        }()

        var scores: [Emotion: Double] = [:]
        for emotion in Emotion.allCases {
            scores[emotion] =
                weights.ser * ser.probability(of: emotion)
                + weights.acoustic * acousticDist.probability(of: emotion)
                + weights.text * textDist.probability(of: emotion)
        }

        let fused = EmotionDistribution(probabilities: scores, confidence: 0)
        let winner = fused.winner
        let intensity = TranslationPayload.clampIntensity(
            0.55 * ser.probability(of: winner)
                + 0.20 * acoustic.intensity
                + 0.25 * textual.intensity
        )
        return FusedEmotion(
            emotion: winner,
            intensity: intensity,
            confidence: confidence(
                ser: ser,
                fused: fused,
                acoustic: acoustic,
                textual: textual,
                serAvailable: serAvailable
            ),
            scores: fused.probabilities
        )
    }

    /// Back-compat for older call sites: treat missing SER as unavailable.
    static func fuse(acoustic: EmotionEstimate, textual: EmotionEstimate) -> FusedEmotion {
        fuse(ser: .uniform(), acoustic: acoustic, textual: textual, serAvailable: false)
    }

    static func confidence(
        ser: EmotionDistribution,
        fused: EmotionDistribution,
        acoustic: EmotionEstimate,
        textual: EmotionEstimate,
        serAvailable: Bool
    ) -> Double {
        let margin = fused.margin
        var agreement = 0.0
        if serAvailable, fused.winner == ser.winner { agreement += 0.16 }
        if fused.winner == acoustic.emotion { agreement += 0.07 }
        if fused.winner == textual.emotion { agreement += 0.07 }
        let serConf = serAvailable ? ser.confidence : 0.2
        return TranslationPayload.clampIntensity(0.50 * serConf + 0.35 * margin + agreement)
    }
}
