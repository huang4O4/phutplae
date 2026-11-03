import XCTest
@testable import PhutPlae

final class EmotionFusionTests: XCTestCase {
    func testSERIsPrimaryWhenOthersDisagree() {
        let ser = EmotionDistribution(
            probabilities: [.angry: 0.72, .neutral: 0.08, .happy: 0.05, .sad: 0.05, .fearful: 0.05, .surprised: 0.05],
            confidence: 0.64
        )
        let acoustic = EmotionEstimate(emotion: .happy, intensity: 0.8, scores: [.happy: 0.8, .angry: 0.1])
        let textual = EmotionEstimate(emotion: .neutral, intensity: 0.4, scores: [.neutral: 0.7, .angry: 0.1])
        let fused = EmotionFusion.fuse(ser: ser, acoustic: acoustic, textual: textual, serAvailable: true)
        XCTAssertEqual(fused.emotion, .angry)
        XCTAssertGreaterThan(fused.confidence, 0.35)
        XCTAssertGreaterThan(fused.scores[.angry] ?? 0, fused.scores[.happy] ?? 0)
        XCTAssertGreaterThan(fused.scores[.angry] ?? 0, fused.scores[.neutral] ?? 0)
    }

    func testMissingSERFallsBackToTextAndAcoustics() {
        let ser = EmotionDistribution.uniform()
        let acoustic = EmotionEstimate(emotion: .sad, intensity: 0.3, scores: [.sad: 0.4, .neutral: 0.3])
        let textual = EmotionEstimate(emotion: .angry, intensity: 0.95, scores: [.angry: 0.95, .sad: 0.02])
        let fused = EmotionFusion.fuse(ser: ser, acoustic: acoustic, textual: textual, serAvailable: false)
        XCTAssertEqual(fused.emotion, .angry)
    }

    func testTwoArgumentFuseMatchesUnavailableSER() {
        let acoustic = EmotionEstimate(emotion: .sad, intensity: 2.0)
        let textual = EmotionEstimate(emotion: .sad, intensity: 1.0)
        let fused = EmotionFusion.fuse(acoustic: acoustic, textual: textual)
        XCTAssertEqual(fused.emotion, .sad)
        XCTAssertEqual(fused.intensity, 1.0, accuracy: 0.0001)
    }

    func testAgreementRaisesConfidence() {
        let ser = EmotionDistribution(
            probabilities: [.sad: 0.6, .neutral: 0.15, .angry: 0.1, .happy: 0.05, .fearful: 0.05, .surprised: 0.05],
            confidence: 0.45
        )
        let aligned = EmotionEstimate(emotion: .sad, intensity: 0.7, scores: [.sad: 0.7])
        let opposed = EmotionEstimate(emotion: .happy, intensity: 0.7, scores: [.happy: 0.7])
        let agree = EmotionFusion.fuse(ser: ser, acoustic: aligned, textual: aligned, serAvailable: true)
        let clash = EmotionFusion.fuse(ser: ser, acoustic: opposed, textual: opposed, serAvailable: true)
        XCTAssertGreaterThan(agree.confidence, clash.confidence)
    }

    func testWeightsSumToOne() {
        XCTAssertEqual(
            EmotionFusion.serWeight + EmotionFusion.acousticWeight + EmotionFusion.textWeight,
            1.0,
            accuracy: 0.0001
        )
        XCTAssertGreaterThan(EmotionFusion.serWeight, EmotionFusion.textWeight)
        XCTAssertGreaterThan(EmotionFusion.serWeight, EmotionFusion.acousticWeight)
    }
}

final class Emotion2VecMappingTests: XCTestCase {
    func testNineClassSoftmaxMapsToSixTravelEmotions() {
        var logits = Array(repeating: 0.0, count: 9)
        logits[0] = 4.0
        let dist = EmotionDistribution.fromEmotion2VecPlus(logits: logits)
        XCTAssertEqual(dist.winner, .angry)
        XCTAssertGreaterThan(dist.probability(of: .angry), 0.5)
        XCTAssertEqual(Emotion.allCases.count, 6)
        let sum = Emotion.allCases.reduce(0) { $0 + dist.probability(of: $1) }
        XCTAssertEqual(sum, 1.0, accuracy: 0.0001)
    }

    func testDisgustMassFoldsIntoAngryAndFearful() {
        var logits = Array(repeating: -5.0, count: 9)
        logits[1] = 3.0
        let dist = EmotionDistribution.fromEmotion2VecPlus(logits: logits)
        XCTAssertGreaterThan(dist.probability(of: .angry), dist.probability(of: .happy))
        XCTAssertGreaterThan(dist.probability(of: .fearful), dist.probability(of: .surprised))
    }

    func testOtherAndUnknownAreDropped() {
        var logits = Array(repeating: -8.0, count: 9)
        logits[5] = 6.0
        logits[8] = 6.0
        logits[4] = 0.5
        let dist = EmotionDistribution.fromEmotion2VecPlus(logits: logits)
        let sum = Emotion.allCases.reduce(0) { $0 + dist.probability(of: $1) }
        XCTAssertEqual(sum, 1.0, accuracy: 0.0001)
        XCTAssertEqual(dist.winner, .neutral)
    }
}

final class UtteranceEmotionSmootherTests: XCTestCase {
    func testEMASmoothsFlickerTowardPersistentClass() {
        var smoother = UtteranceEmotionSmoother(alpha: 0.4)
        let angry = EmotionDistribution(
            probabilities: [.angry: 0.8, .neutral: 0.05, .happy: 0.05, .sad: 0.04, .fearful: 0.03, .surprised: 0.03],
            confidence: 0.7
        )
        let happySpike = EmotionDistribution(
            probabilities: [.happy: 0.7, .angry: 0.1, .neutral: 0.05, .sad: 0.05, .fearful: 0.05, .surprised: 0.05],
            confidence: 0.4
        )
        smoother.add(angry)
        smoother.add(angry)
        smoother.add(happySpike)
        let out = smoother.finalized()
        XCTAssertEqual(out.winner, .angry)
        XCTAssertEqual(smoother.frameCount, 3)
    }

    func testWindowsPadShortUtterancesAndHopLongOnes() {
        let short = SERWindowing.windows(from: [Float](repeating: 0.1, count: 1000))
        XCTAssertEqual(short.count, 1)
        XCTAssertEqual(short[0].count, SERWindowing.windowSamples)

        let long = [Float](repeating: 0.1, count: SERWindowing.windowSamples * 3)
        let windows = SERWindowing.windows(from: long)
        XCTAssertGreaterThanOrEqual(windows.count, 5)
        XCTAssertTrue(windows.allSatisfy { $0.count == SERWindowing.windowSamples })
    }
}

final class AcousticEmotionAnalyzerTests: XCTestCase {
    func testSilentBufferLooksNeutralOrSadAndQuiet() {
        let samples = [Float](repeating: 0, count: 16_000)
        let snap = AcousticEmotionAnalyzer.snapshot(samples: samples)
        XCTAssertEqual(snap.rms, 0, accuracy: 0.0001)
        let estimate = AcousticEmotionAnalyzer.estimate(from: snap)
        XCTAssertTrue(estimate.emotion == .sad || estimate.emotion == .neutral)
    }
}

final class VoiceActivityDetectorTests: XCTestCase {
    func testEmitsSegmentAfterSpeechAndHangover() {
        var vad = VoiceActivityDetector(
            sampleRate: 16_000,
            frameMs: 20,
            startFrames: 2,
            hangoverFrames: 3,
            minUtteranceMs: 40,
            maxUtteranceMs: 5_000,
            rmsStart: 0.05,
            rmsHold: 0.03
        )
        let loud = [Float](repeating: 0.2, count: 320)
        let quiet = [Float](repeating: 0.0, count: 1600)
        XCTAssertTrue(vad.push(loud).isEmpty)
        XCTAssertEqual(vad.push(quiet).count, 1)
    }
}
