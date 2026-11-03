import Foundation

enum TranslationJSONParserError: Error, Equatable, LocalizedError {
    case emptyResponse
    case missingObject
    case missingSpokenText
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .emptyResponse: return "โมเดลไม่ตอบกลับ"
        case .missingObject: return "หา JSON ในคำตอบไม่เจอ"
        case .missingSpokenText: return "JSON ไม่มีข้อความแปล"
        case .invalidJSON: return "JSON พัง"
        }
    }
}

enum TranslationJSONParser {
    static func parse(_ raw: String) throws -> TranslationPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationJSONParserError.emptyResponse }

        let candidates = jsonCandidates(in: trimmed)
        var lastError: Error = TranslationJSONParserError.missingObject

        for candidate in candidates {
            do {
                return try decodeObject(candidate)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    static func jsonCandidates(in raw: String) -> [String] {
        var results: [String] = []
        if let fenced = firstMatch(in: raw, pattern: "```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```") {
            results.append(fenced)
        }
        if let braced = firstBalancedObject(in: raw) {
            results.append(braced)
        }
        results.append(raw)
        var seen = Set<String>()
        return results.filter { seen.insert($0).inserted }
    }

    private static func decodeObject(_ json: String) throws -> TranslationPayload {
        guard let data = json.data(using: .utf8) else {
            throw TranslationJSONParserError.invalidJSON
        }
        let object: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw TranslationJSONParserError.missingObject
            }
            object = parsed
        } catch {
            throw TranslationJSONParserError.invalidJSON
        }

        let spoken = firstString(in: object, keys: [
            "thai", "english", "chinese", "mandarin", "zh", "text", "translation", "spoken", "utterance"
        ])
        guard let spoken, !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationJSONParserError.missingSpokenText
        }

        let emotionRaw = firstString(in: object, keys: ["emotion", "mood", "affect"]) ?? "neutral"
        let intensity = firstNumber(in: object, keys: ["intensity", "strength", "score"]) ?? 0.5

        return TranslationPayload(
            spokenText: spoken.trimmingCharacters(in: .whitespacesAndNewlines),
            emotion: Emotion.parse(emotionRaw),
            intensity: intensity
        )
    }

    private static func firstString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String {
                return value
            }
        }
        return nil
    }

    private static func firstNumber(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object[key] as? Double { return value }
            if let value = object[key] as? Int { return Double(value) }
            if let value = object[key] as? NSNumber { return value.doubleValue }
            if let value = object[key] as? String, let parsed = Double(value) { return parsed }
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[swiftRange])
    }

    private static func firstBalancedObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        for index in text[start...].indices {
            let ch = text[index]
            if inString {
                if escape {
                    escape = false
                } else if ch == "\\" {
                    escape = true
                } else if ch == "\"" {
                    inString = false
                }
                continue
            }
            if ch == "\"" {
                inString = true
            } else if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            }
        }
        return nil
    }
}
