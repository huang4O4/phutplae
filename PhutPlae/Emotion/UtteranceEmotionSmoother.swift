import Foundation

/// Exponential moving average over windowed SER posteriors for one utterance.
struct UtteranceEmotionSmoother: Equatable, Sendable {
    var alpha: Double
    private var state: [Emotion: Double]?
    private var frames = 0
    private var confidenceEMA = 0.0

    init(alpha: Double = 0.40) {
        self.alpha = min(1, max(0.05, alpha))
    }

    mutating func reset() {
        state = nil
        frames = 0
        confidenceEMA = 0
    }

    @discardableResult
    mutating func add(_ frame: EmotionDistribution) -> EmotionDistribution {
        var next: [Emotion: Double] = [:]
        if let previous = state {
            for emotion in Emotion.allCases {
                next[emotion] = alpha * frame.probability(of: emotion)
                    + (1 - alpha) * (previous[emotion] ?? 0)
            }
            confidenceEMA = alpha * frame.confidence + (1 - alpha) * confidenceEMA
        } else {
            for emotion in Emotion.allCases {
                next[emotion] = frame.probability(of: emotion)
            }
            confidenceEMA = frame.confidence
        }
        state = next
        frames += 1
        return EmotionDistribution(probabilities: next, confidence: confidenceEMA)
    }

    func finalized() -> EmotionDistribution {
        guard let state else { return .uniform() }
        return EmotionDistribution(probabilities: state, confidence: confidenceEMA)
    }

    var frameCount: Int { frames }
}
