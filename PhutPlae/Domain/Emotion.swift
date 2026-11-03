import Foundation

/// Speaker affect used for both fusion and TTS prosody.
enum Emotion: String, Codable, CaseIterable, Sendable {
    case neutral
    case angry
    case happy
    case sad
    case fearful
    case surprised

    var thaiLabel: String {
        switch self {
        case .neutral: return "ปกติ"
        case .angry: return "โกรธ"
        case .happy: return "ดีใจ"
        case .sad: return "เศร้า"
        case .fearful: return "กลัว"
        case .surprised: return "ตกใจ"
        }
    }

    var emoji: String {
        switch self {
        case .neutral: return "😐"
        case .angry: return "😡"
        case .happy: return "😄"
        case .sad: return "😢"
        case .fearful: return "😨"
        case .surprised: return "😲"
        }
    }

    static func parse(_ raw: String) -> Emotion {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "neutral", "calm", "ปกติ":
            return .neutral
        case "angry", "anger", "mad", "furious", "โกรธ":
            return .angry
        case "happy", "happiness", "joy", "joyful", "ดีใจ":
            return .happy
        case "sad", "sadness", "unhappy", "เศร้า":
            return .sad
        case "fearful", "fear", "afraid", "scared", "กลัว":
            return .fearful
        case "surprised", "surprise", "shocked", "ตกใจ":
            return .surprised
        default:
            return .neutral
        }
    }
}
