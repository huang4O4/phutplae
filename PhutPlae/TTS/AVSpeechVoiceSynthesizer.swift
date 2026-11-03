import AVFoundation
import Foundation

/// System `th-TH` / `en-US` voice with emotion mapped onto rate, pitch, volume and pauses.
final class AVSpeechVoiceSynthesizer: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ utterance: SpokenUtterance) async throws {
        let text = utterance.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SpeechSynthesizerError.emptyText }

        let prosody = ProsodyMapper.map(
            emotion: utterance.emotion,
            intensity: utterance.intensity,
            speedScale: utterance.speedScale
        )

        let speech = AVSpeechUtterance(string: text)
        speech.voice = SpeechVoicePicker.bestVoice(for: utterance.language)
        guard speech.voice != nil else {
            throw SpeechSynthesizerError.voiceUnavailable(utterance.language)
        }
        speech.rate = prosody.rate
        speech.pitchMultiplier = prosody.pitchMultiplier
        speech.volume = prosody.volume
        speech.preUtteranceDelay = prosody.preUtteranceDelay
        speech.postUtteranceDelay = prosody.postUtteranceDelay

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            lock.lock()
            if let existing = continuation {
                continuation = nil
                lock.unlock()
                existing.resume(throwing: CancellationError())
                lock.lock()
            }
            continuation = cont
            lock.unlock()
            synthesizer.speak(speech)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finish(.success(()))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish(.success(()))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(.success(()))
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(with: result)
    }
}
