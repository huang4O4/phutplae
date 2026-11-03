import Foundation

struct TranscriptResult: Equatable, Sendable {
    var text: String
    var language: SpokenLanguage?
}

protocol SpeechTranscribing: Sendable {
    var isReady: Bool { get async }
    func prepare(
        variant: String,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws
    func transcribe(samples: [Float], detectLanguage: Bool) async throws -> TranscriptResult
    func releaseMemory() async
}

enum SpeechTranscriptionError: Error, LocalizedError {
    case notReady
    case emptyAudio
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notReady: return "โมเดลฟังเสียงยังไม่พร้อม"
        case .emptyAudio: return "คลิปเสียงสั้นเกินไป"
        case .failed(let message): return message
        }
    }
}
