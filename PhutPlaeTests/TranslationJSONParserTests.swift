import XCTest
@testable import PhutPlae

final class TranslationJSONParserTests: XCTestCase {
    func testParsesCanonicalEnglishToThaiObject() throws {
        let raw = """
        {"thai":"แกเว่อะไรวะ","emotion":"angry","intensity":0.86}
        """
        let payload = try TranslationJSONParser.parse(raw)
        XCTAssertEqual(payload.spokenText, "แกเว่อะไรวะ")
        XCTAssertEqual(payload.emotion, .angry)
        XCTAssertEqual(payload.intensity, 0.86, accuracy: 0.0001)
    }

    func testParsesReverseDirectionEnglishKey() throws {
        let payload = try TranslationJSONParser.parse(
            #"{"english":"What the hell is your problem?","emotion":"angry","intensity":0.9}"#
        )
        XCTAssertEqual(payload.spokenText, "What the hell is your problem?")
        XCTAssertEqual(payload.emotion, .angry)
    }

    func testExtractsJSONFromMarkdownFenceAndProse() throws {
        let raw = """
        Sure, here you go:
        ```json
        {
          "thai": "อย่ามายุ่งกับฉัน",
          "emotion": "anger",
          "intensity": "0.7"
        }
        ```
        """
        let payload = try TranslationJSONParser.parse(raw)
        XCTAssertEqual(payload.spokenText, "อย่ามายุ่งกับฉัน")
        XCTAssertEqual(payload.emotion, .angry)
        XCTAssertEqual(payload.intensity, 0.7, accuracy: 0.0001)
    }

    func testAcceptsEmotionAliasesAndClampsIntensity() throws {
        let payload = try TranslationJSONParser.parse(
            #"{"translation":"โอ้โห","mood":"shock","score":1.8}"#
        )
        XCTAssertEqual(payload.spokenText, "โอ้โห")
        XCTAssertEqual(payload.emotion, .surprised)
        XCTAssertEqual(payload.intensity, 1.0, accuracy: 0.0001)
    }

    func testIgnoresBracesInsideStringsWhenFindingObject() throws {
        let raw = #"prefix {"thai":"เขาพูดว่า \"{ไม่} หรอก\"","emotion":"neutral","intensity":0.2} trail"#
        let payload = try TranslationJSONParser.parse(raw)
        XCTAssertEqual(payload.spokenText, #"เขาพูดว่า "{ไม่} หรอก""#)
        XCTAssertEqual(payload.emotion, .neutral)
    }

    func testEmptyAndNonJSONFail() {
        XCTAssertThrowsError(try TranslationJSONParser.parse("   ")) { error in
            XCTAssertEqual(error as? TranslationJSONParserError, .emptyResponse)
        }
        XCTAssertThrowsError(try TranslationJSONParser.parse("sorry I cannot swear")) { error in
            XCTAssertEqual(error as? TranslationJSONParserError, .missingObject)
        }
        XCTAssertThrowsError(try TranslationJSONParser.parse(#"{"emotion":"happy"}"#)) { error in
            XCTAssertEqual(error as? TranslationJSONParserError, .missingSpokenText)
        }
    }

    func testThaiEmotionWords() throws {
        let payload = try TranslationJSONParser.parse(
            #"{"thai":"ดีจังเลย","emotion":"ดีใจ","intensity":0.4}"#
        )
        XCTAssertEqual(payload.emotion, .happy)
    }
}
