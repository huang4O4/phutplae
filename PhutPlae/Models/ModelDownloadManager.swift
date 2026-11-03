import Foundation

struct ModelDownloadState: Equatable, Sendable {
    var fraction: Double
    var message: String
    var isComplete: Bool
    var errorMessage: String?

    static let idle = ModelDownloadState(
        fraction: 0,
        message: "ยังไม่ได้โหลดโมเดล",
        isComplete: false,
        errorMessage: nil
    )
}

@MainActor
final class ModelDownloadManager: ObservableObject {
    @Published var state = ModelDownloadState.idle
    @Published var isWorking = false

    /// Loads Whisper and the translator in parallel so a short session can start sooner.
    func ensureModels(
        whisper: SpeechTranscribing,
        translator: TranslationServicing,
        whisperVariant: String
    ) async throws {
        isWorking = true
        state = ModelDownloadState(
            fraction: 0.01,
            message: "BOOT · โหลดโมเดลคู่ขนานบนเครื่อง…",
            isComplete: false,
            errorMessage: nil
        )
        defer { isWorking = false }

        var whisperFrac = 0.0
        var translateFrac = 0.0

        func publish(note: String) {
            state = ModelDownloadState(
                fraction: min(0.99, whisperFrac * 0.4 + translateFrac * 0.6),
                message: note,
                isComplete: false,
                errorMessage: nil
            )
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await whisper.prepare(variant: whisperVariant) { fraction, message in
                        Task { @MainActor in
                            whisperFrac = fraction
                            publish(note: message)
                        }
                    }
                }
                group.addTask {
                    try await translator.prepare { fraction, message in
                        Task { @MainActor in
                            translateFrac = fraction
                            publish(note: message)
                        }
                    }
                }
                try await group.waitForAll()
            }

            state = ModelDownloadState(
                fraction: 1,
                message: "READY · โมเดลพร้อม ทำงานบนเครื่องทั้งหมด",
                isComplete: true,
                errorMessage: nil
            )
        } catch {
            state = ModelDownloadState(
                fraction: state.fraction,
                message: "BOOT FAILED",
                isComplete: false,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }
}
