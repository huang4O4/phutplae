import Foundation

#if canImport(WhisperKit)
import WhisperKit
#endif

final class WhisperKitTranscriber: SpeechTranscribing, @unchecked Sendable {
#if canImport(WhisperKit)
    private var pipe: WhisperKit?
#endif
    private var ready = false
    private let lock = NSLock()

    var isReady: Bool {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return ready
        }
    }

    func prepare(
        variant: String,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
#if canImport(WhisperKit)
        progress(0.05, "BOOT · WhisperKit \(variant)")
        let kit = try await WhisperKit(WhisperKitConfig(model: variant))
        lock.lock()
        pipe = kit
        ready = true
        lock.unlock()
        progress(1.0, "โหลดโมเดลฟังเสียงแล้ว")
#else
        throw SpeechTranscriptionError.failed("โปรเจกต์นี้ยังลิงก์ WhisperKit ไม่ได้")
#endif
    }

    func transcribe(samples: [Float], detectLanguage: Bool) async throws -> TranscriptResult {
        guard !samples.isEmpty else { throw SpeechTranscriptionError.emptyAudio }
#if canImport(WhisperKit)
        lock.lock()
        let kit = pipe
        lock.unlock()
        guard let kit else { throw SpeechTranscriptionError.notReady }

        var options = DecodingOptions()
        options.temperature = 0
        options.detectLanguage = detectLanguage
        options.skipSpecialTokens = true
        options.withoutTimestamps = true

        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detected = SpokenLanguage.guess(from: text)
        return TranscriptResult(text: text, language: detected)
#else
        throw SpeechTranscriptionError.notReady
#endif
    }

    func releaseMemory() async {
        lock.lock()
        ready = false
#if canImport(WhisperKit)
        pipe = nil
#endif
        lock.unlock()
    }
}
