import XCTest
@testable import PhutPlae

final class ProsodyMapperTests: XCTestCase {
    func testAngryIsFasterLouderHigherThanNeutral() {
        let neutral = ProsodyMapper.map(emotion: .neutral, intensity: 0.5)
        let angry = ProsodyMapper.map(emotion: .angry, intensity: 0.9)

        XCTAssertGreaterThan(angry.rate, neutral.rate)
        XCTAssertGreaterThan(angry.pitchMultiplier, neutral.pitchMultiplier)
        XCTAssertGreaterThan(angry.volume, neutral.volume)
        XCTAssertLessThan(angry.preUtteranceDelay, neutral.preUtteranceDelay)
        XCTAssertLessThan(angry.postUtteranceDelay, neutral.postUtteranceDelay)
    }

    func testSadIsSlowerLowerQuieterThanNeutral() {
        let neutral = ProsodyMapper.map(emotion: .neutral, intensity: 0.5)
        let sad = ProsodyMapper.map(emotion: .sad, intensity: 0.9)

        XCTAssertLessThan(sad.rate, neutral.rate)
        XCTAssertLessThan(sad.pitchMultiplier, neutral.pitchMultiplier)
        XCTAssertLessThan(sad.volume, neutral.volume)
        XCTAssertGreaterThan(sad.preUtteranceDelay, neutral.preUtteranceDelay)
    }

    func testIntensityPushesAngryTowardTheHotEnd() {
        let mild = ProsodyMapper.map(emotion: .angry, intensity: 0.1)
        let hot = ProsodyMapper.map(emotion: .angry, intensity: 1.0)
        XCTAssertGreaterThan(hot.rate, mild.rate)
        XCTAssertGreaterThan(hot.pitchMultiplier, mild.pitchMultiplier)
        XCTAssertGreaterThan(hot.volume, mild.volume)
    }

    func testSpeedScaleIsClampedAndAppliedToRate() {
        let base = ProsodyMapper.map(emotion: .neutral, intensity: 0.4, speedScale: 1.0)
        let faster = ProsodyMapper.map(emotion: .neutral, intensity: 0.4, speedScale: 1.3)
        let slower = ProsodyMapper.map(emotion: .neutral, intensity: 0.4, speedScale: 0.75)
        let runaway = ProsodyMapper.map(emotion: .neutral, intensity: 0.4, speedScale: 4.0)

        XCTAssertGreaterThan(faster.rate, base.rate)
        XCTAssertLessThan(slower.rate, base.rate)
        XCTAssertEqual(runaway.rate, ProsodyMapper.map(emotion: .neutral, intensity: 0.4, speedScale: 1.4).rate)
    }

    func testOutputsStayInsideAVSpeechRanges() {
        for emotion in Emotion.allCases {
            for intensity in [0.0, 0.5, 1.0, 3.0, -1.0] {
                let prosody = ProsodyMapper.map(emotion: emotion, intensity: intensity, speedScale: 1.4)
                XCTAssertTrue(SpeechProsody.rateRange.contains(prosody.rate), "\(emotion) rate \(prosody.rate)")
                XCTAssertTrue(SpeechProsody.pitchRange.contains(prosody.pitchMultiplier))
                XCTAssertTrue(SpeechProsody.volumeRange.contains(prosody.volume))
                XCTAssertGreaterThanOrEqual(prosody.preUtteranceDelay, 0)
                XCTAssertGreaterThanOrEqual(prosody.postUtteranceDelay, 0)
            }
        }
    }

    func testHappyAndSurprisedSitAboveNeutralPitch() {
        let neutral = ProsodyMapper.map(emotion: .neutral, intensity: 0.7)
        let happy = ProsodyMapper.map(emotion: .happy, intensity: 0.7)
        let surprised = ProsodyMapper.map(emotion: .surprised, intensity: 0.7)
        XCTAssertGreaterThan(happy.pitchMultiplier, neutral.pitchMultiplier)
        XCTAssertGreaterThan(surprised.pitchMultiplier, happy.pitchMultiplier)
        XCTAssertEqual(surprised.preUtteranceDelay, 0, accuracy: 0.0001)
    }
}
