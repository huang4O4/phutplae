import Foundation

enum TranslationPrompt {
    static func systemPrompt(source: SpokenLanguage) -> String {
        """
        You are a live interpreter for a Thai traveler. Listen to \(source.thaiName) and speak Thai.
        Sound like a real person in the room — not a dictionary, not a subtitle, not a diplomat.
        Keep slang, heat and force. Never soften or censor.
        Output ONLY compact JSON with keys:
        - "thai": the spoken Thai translation only
        - "emotion": one of neutral, angry, happy, sad, fearful, surprised
        - "intensity": number from 0 to 1
        No markdown. No romanization. No extra keys.
        """
    }

    static func userPrompt(sourceText: String, acousticHint: EmotionEstimate) -> String {
        """
        Source utterance:
        \(sourceText)

        Acoustic hint (not authoritative): emotion=\(acousticHint.emotion.rawValue) intensity=\(String(format: "%.2f", acousticHint.intensity))
        """
    }
}
