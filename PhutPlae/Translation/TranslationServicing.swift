import Foundation

protocol TranslationServicing: Sendable {
    var isReady: Bool { get async }
    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws
    func translate(
        sourceText: String,
        sourceLanguage: SpokenLanguage,
        acousticHint: EmotionEstimate
    ) async throws -> TranslationPayload
    func releaseMemory() async
}

enum TranslationServiceError: Error, LocalizedError {
    case notReady
    case emptySource
    case unsupportedSource
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notReady: return "โมเดลแปลยังไม่พร้อม"
        case .emptySource: return "ไม่มีข้อความให้แปล"
        case .unsupportedSource: return "ฟังได้เฉพาะอังกฤษหรือจีนกลาง"
        case .generationFailed(let message): return message
        }
    }
}
