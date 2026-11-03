import AVFoundation
import Foundation

enum SpeechVoicePicker {
    /// Prefers iOS Enhanced / Premium Thai (or English) voices over the compact default.
    static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let wanted = language.lowercased()
        let prefix = String(wanted.prefix(2))
        let matches = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix(prefix)
        }
        let ranked = matches.sorted { lhs, rhs in
            let leftExact = lhs.language.lowercased() == wanted ? 50 : 0
            let rightExact = rhs.language.lowercased() == wanted ? 50 : 0
            return qualityScore(lhs) + leftExact > qualityScore(rhs) + rightExact
        }
        return ranked.first
            ?? AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: fallback(for: language))
    }

    static func fallback(for language: String) -> String {
        if language.hasPrefix("th") { return "th-TH" }
        if language.hasPrefix("zh") { return "zh-CN" }
        if language.hasPrefix("en") { return "en-GB" }
        return language
    }

    static func hasEnhancedOrBetter(_ language: String) -> Bool {
        guard let voice = bestVoice(for: language) else { return false }
        return qualityScore(voice) >= 20
    }

    static func qualityScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        var score = 0
        switch voice.quality {
        case .premium: score += 30
        case .enhanced: score += 20
        default: score += 5
        }
        let id = voice.identifier.lowercased()
        if id.contains("premium") { score += 4 }
        if id.contains("enhanced") { score += 3 }
        if id.contains("compact") { score -= 8 }
        return score
    }

    static func installedEnhancedThaiVoice() -> AVSpeechSynthesisVoice? {
        bestVoice(for: "th-TH").flatMap { voice in
            qualityScore(voice) >= 20 ? voice : nil
        }
    }
}
