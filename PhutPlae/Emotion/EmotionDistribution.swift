import Darwin
import Foundation

/// Six-class posterior used by SER, fusion and the HUD confidence readout.
struct EmotionDistribution: Equatable, Sendable {
    var probabilities: [Emotion: Double]
    var confidence: Double

    init(probabilities: [Emotion: Double], confidence: Double) {
        var normalized: [Emotion: Double] = [:]
        let total = Emotion.allCases.reduce(0) { $0 + max(0, probabilities[$1] ?? 0) }
        if total > 0 {
            for emotion in Emotion.allCases {
                normalized[emotion] = max(0, probabilities[emotion] ?? 0) / total
            }
        } else {
            let even = 1.0 / Double(Emotion.allCases.count)
            for emotion in Emotion.allCases {
                normalized[emotion] = even
            }
        }
        self.probabilities = normalized
        self.confidence = TranslationPayload.clampIntensity(confidence)
    }

    func probability(of emotion: Emotion) -> Double {
        probabilities[emotion] ?? 0
    }

    var winner: Emotion {
        probabilities.max { $0.value < $1.value }?.key ?? .neutral
    }

    var runnerUp: Emotion {
        probabilities
            .filter { $0.key != winner }
            .max { $0.value < $1.value }?
            .key ?? .neutral
    }

    var margin: Double {
        probability(of: winner) - probability(of: runnerUp)
    }

    static func uniform(confidence: Double = 0) -> EmotionDistribution {
        let even = 1.0 / Double(Emotion.allCases.count)
        return EmotionDistribution(
            probabilities: Dictionary(uniqueKeysWithValues: Emotion.allCases.map { ($0, even) }),
            confidence: confidence
        )
    }

    static func softmax(_ logits: [Emotion: Double]) -> EmotionDistribution {
        let maxLogit = logits.values.max() ?? 0
        var exp: [Emotion: Double] = [:]
        var sum = 0.0
        for emotion in Emotion.allCases {
            let value = Darwin.exp((logits[emotion] ?? 0) - maxLogit)
            exp[emotion] = value
            sum += value
        }
        var probs: [Emotion: Double] = [:]
        for emotion in Emotion.allCases {
            probs[emotion] = (exp[emotion] ?? 0) / max(sum, 1e-9)
        }
        let dist = EmotionDistribution(probabilities: probs, confidence: 0)
        return EmotionDistribution(probabilities: probs, confidence: dist.margin)
    }

    static func fromEstimate(_ estimate: EmotionEstimate) -> EmotionDistribution {
        if estimate.scores.isEmpty {
            var probs = Dictionary(uniqueKeysWithValues: Emotion.allCases.map { ($0, 0.04) })
            probs[estimate.emotion] = max(0.35, estimate.intensity)
            return EmotionDistribution(probabilities: probs, confidence: estimate.intensity)
        }
        return softmax(estimate.scores)
    }

    /// emotion2vec+ seed/base/large logits, official order:
    /// angry, disgusted, fearful, happy, neutral, other, sad, surprised, unknown
    static func fromEmotion2VecPlus(logits: [Double]) -> EmotionDistribution {
        var padded = logits
        if padded.count < 9 {
            padded.append(contentsOf: Array(repeating: 0, count: 9 - padded.count))
        }
        let maxLogit = padded.max() ?? 0
        let exp = padded.map { Darwin.exp($0 - maxLogit) }
        let sum = exp.reduce(0, +)
        let p = exp.map { $0 / max(sum, 1e-9) }

        var six: [Emotion: Double] = [
            .angry: p[0] + 0.55 * p[1],
            .fearful: p[2] + 0.25 * p[1],
            .happy: p[3],
            .neutral: p[4],
            .sad: p[6],
            .surprised: p[7]
        ]
        // other + unknown are discarded then we renormalize the six travel classes
        _ = p[5] + p[8]
        let dist = EmotionDistribution(probabilities: six, confidence: 0)
        return EmotionDistribution(probabilities: dist.probabilities, confidence: dist.margin)
    }
}
