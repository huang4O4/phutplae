import Foundation

struct LatencySplit: Equatable, Sendable {
    var vadMs: Int
    var sttMs: Int
    var serMs: Int
    var translateMs: Int
    var ttsMs: Int

    var totalMs: Int { vadMs + sttMs + serMs + translateMs + ttsMs }

    var thaiSummary: String {
        "หน่วง \(totalMs) ms · ฟัง \(sttMs) · อารมณ์ \(serMs) · แปล \(translateMs) · พูด \(ttsMs)"
    }
}

enum PipelinePhase: String, Sendable {
    case idle
    case booting
    case listening
    case transcribing
    case translating
    case speaking
    case downloading
    case failed
}

struct TranscriptTurn: Identifiable, Equatable, Sendable {
    let id: UUID
    var sourceText: String
    var translatedText: String
    var sourceLanguage: SpokenLanguage
    var emotion: Emotion
    var intensity: Double
    var confidence: Double
    var latency: LatencySplit

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: SpokenLanguage,
        emotion: Emotion,
        intensity: Double,
        confidence: Double,
        latency: LatencySplit
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.emotion = emotion
        self.intensity = intensity
        self.confidence = TranslationPayload.clampIntensity(confidence)
        self.latency = latency
    }
}
