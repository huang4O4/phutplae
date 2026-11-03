import XCTest
@testable import PhutPlae

final class ChatPromptFormatterTests: XCTestCase {
    func testLlama3TemplateForTyphoon() {
        let prompt = ChatPromptFormatter.render(system: "SYS", user: "USR", family: .llama3)
        XCTAssertTrue(prompt.contains("<|start_header_id|>system<|end_header_id|>"))
        XCTAssertTrue(prompt.contains("<|eot_id|>"))
        XCTAssertFalse(prompt.contains("<|im_start|>"))
    }

    func testQwenTemplateForChinesePair() {
        let prompt = ChatPromptFormatter.render(system: "SYS", user: "USR", family: .qwen)
        XCTAssertTrue(prompt.contains("<|im_start|>system"))
        XCTAssertTrue(prompt.contains("<|im_start|>assistant"))
    }
}

final class LanguageRoutingTests: XCTestCase {
    func testAutomaticPolicyPicksTyphoonForEnglishAndQwenForMandarin() {
        XCTAssertEqual(TranslatorPolicy.automatic.model(for: .english), .typhoon3b)
        XCTAssertEqual(TranslatorPolicy.automatic.model(for: .mandarin), .qwen3b)
    }

    func testScriptGuess() {
        XCTAssertEqual(SpokenLanguage.guess(from: "What the hell is going on?"), .english)
        XCTAssertEqual(SpokenLanguage.guess(from: "你在说什么？"), .mandarin)
        XCTAssertEqual(SpokenLanguage.guess(from: "แกเว่อะไรวะ"), .thai)
        XCTAssertNil(SpokenLanguage.guess(from: "!!"))
    }

    func testOnlyEnglishAndMandarinAreSources() {
        XCTAssertTrue(SpokenLanguage.english.isSourceLanguage)
        XCTAssertTrue(SpokenLanguage.mandarin.isSourceLanguage)
        XCTAssertFalse(SpokenLanguage.thai.isSourceLanguage)
    }

    func testWhisperCodes() {
        XCTAssertEqual(SpokenLanguage.fromWhisper("zh"), .mandarin)
        XCTAssertEqual(SpokenLanguage.fromWhisper("en-GB"), .english)
        XCTAssertEqual(SpokenLanguage.fromWhisper("th"), .thai)
    }
}

final class AudioMeteringTests: XCTestCase {
    func testSilentBufferIsFloorDB() {
        let db = AudioMetering.loudnessDBFS([Float](repeating: 0, count: 512))
        XCTAssertEqual(db, -80, accuracy: 0.01)
    }

    func testFullScaleToneIsNearZeroDB() {
        let samples = [Float](repeating: 1, count: 256)
        let db = AudioMetering.loudnessDBFS(samples)
        XCTAssertGreaterThan(db, -1)
        XCTAssertLessThanOrEqual(db, 0.01)
    }
}
