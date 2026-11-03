import Foundation

protocol SpeechEmotionRecognizing: Sendable {
    var isReady: Bool { get async }
    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws
    func classify(samples: [Float]) async throws -> EmotionDistribution
    func releaseMemory() async
}

enum SpeechEmotionError: Error, LocalizedError {
    case notReady
    case emptyAudio
    case modelMissing
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notReady: return "โมเดลอ่านอารมณ์จากเสียงยังไม่พร้อม"
        case .emptyAudio: return "คลิปเสียงสั้นเกินไปสำหรับ SER"
        case .modelMissing: return "ยังไม่มีไฟล์ Core ML ของ emotion2vec+"
        case .inferenceFailed(let message): return message
        }
    }
}
