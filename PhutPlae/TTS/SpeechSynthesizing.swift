import Foundation

/// Swap point for a later neural emotional Thai TTS (TTSKit / custom Core ML).
protocol SpeechSynthesizing: AnyObject, Sendable {
    func speak(_ utterance: SpokenUtterance) async throws
    func stop()
}

enum SpeechSynthesizerError: Error, LocalizedError {
    case emptyText
    case voiceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .emptyText: return "ไม่มีข้อความให้อ่าน"
        case .voiceUnavailable(let language): return "ไม่พบเสียง \(language) บนเครื่อง"
        }
    }
}
